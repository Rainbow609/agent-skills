# AI 订阅 / 套餐额度查询接口速查（含高峰时段规则与 GCMP 参考）

> 适用前提：要给「查自己账号额度」的客户端（鸿蒙 App、桌面卡片、CLI）喂接口时看这篇。
> **与 `coding-plan-quota-and-pricing.md` 的分工**：那篇回答「换哪张订阅更划算」（价格/额度/单价），
> 本篇回答「额度怎么查」（endpoint / 鉴权 / 字段 / 高峰规则 / 可否离线判定）。两篇不要互相复制数字。
> 复核日期 **2026-10-19**；配置型产物见上游仓库 `ai-quota-rules`（规则集，客户端直接拉取）。

## 核心结论

1. **四类数据来源要分清**：官方 API（DeepSeek 余额、MiniMax 套餐、OpenCode Go 用量）／半官方
   （Kimi：官方 CLI 源码里定义的接口，未列入公开文档）／社区逆向（CommandCode、GLM 额度、Claude OAuth 用量）／
   本地日志推算（Claude Code、部分 Codex 用量）。**逆向类都可能随时失效**，客户端必须允许"该项查不到"而不是整体失败。
2. **套餐制与余额制是两种模型**：余额制只有金额（DeepSeek）；套餐制是「窗口 + 剩余百分比 + 重置时刻」，
   且普遍是 **5 小时 + 周/月 双窗**（OpenCode Go 甚至是 5h/周/月三窗口）。UI 不能把两者塞进同一种卡片。
3. **「当前是否高峰」应当离线算，不要依赖接口**：高峰是固定时段规则（星期 + 时刻 + 时区），
   规则随规则集下发即可；DeepSeek 还带中国法定节假日例外（节假日全天平峰）。
4. **GCMP 既是实现参考，也是可消费的上游——但只到"模型/价格/峰谷"这一层**：它的模型清单、token 单价与
   峰谷 cron 通过 `https://gcmp.dev/configs/` 公开发布（`index.json` + 每 provider 一个 config，带 `gcmpVersion`
   与 `contentHash`，CORS `*`、`max-age=600`），可自动拉取；而**额度查询的 endpoint、鉴权与响应解析在 TS 源码里**
   （`buildRequest`/`parseAndValidate`），只能半自动抽取 + 人工复核。两类数据不要混为一谈。
5. **别把「套餐窗口额度」和「账户余额」混为一谈**，也别把「用量/账单接口」当余额用——后者按时间桶聚合、
   有延迟，推不出剩余额度。

## 一、接口速查表

| 服务 | 数据来源 | Endpoint | 鉴权 | 能拿到 | 置信度 |
| --- | --- | --- | --- | --- | --- |
| DeepSeek | 官方 | `GET https://api.deepseek.com/user/balance` | `Bearer` | `is_available` + `balance_infos[]{currency,total_balance,granted_balance,topped_up_balance}`（**金额是字符串**，可多币种） | 高 |
| OpenCode Go | 官方 | `GET https://opencode.ai/zen/go/v1/usage` | `Bearer` | `usage.{rolling,weekly,monthly}.{percent,resetsAt,status}`；5h = 月额度 20%、周 50%、月 100% | 高 |
| Kimi（Kimi Code） | 半官方 | `GET https://api.kimi.com/coding/v1/usages`（国际 `api.kimi.ai`） | `Bearer` | `limit_5h` / `limit_7d` / `limit_month_code`（`used_ratio` + `reset_time`）、`boosterWallet` 加油包、`parallel.limit` | 中高 |
| MiniMax（M Plan） | 官方 | `GET https://www.minimaxi.com/v1/token_plan/remains`（国际 `.minimax.io`） | `Bearer`（订阅 Key `sk-cp-`） | `model_remains[]`：`current_interval_remaining_percent`(5h)、`current_weekly_remaining_percent`、`end_time`/`weekly_end_time`；按量 Key `sk-api-` 走 `/account/query_balance` | 高 |
| GLM Coding Plan | 社区 | `GET https://bigmodel.cn/api/monitor/usage/quota/limit`（国际 `api.z.ai/...`） | **`Authorization` 直传 Key（不带 Bearer，待实测）** | `data.limits[]`：`unit` 3=5 小时 / 6=周，`percentage`、`nextResetTime`；另有 MCP 月度次数 `TIME_LIMIT` | 中 |
| CommandCode（Go/GOAT） | 社区 | `GET https://api.commandcode.ai/alpha/billing/credits`（+ `/alpha/billing/subscriptions` 取 planId） | `Bearer`（或会话 Cookie） | `windowLimits.fiveHour/weekly.{used,cap,resetAt}`、`credits.*`；GOAT 套餐 5h $14 / 周 $35 / 月 $70 | 中高 |
| Codex（ChatGPT 订阅） | 官方 CLI 源码 | `GET https://chatgpt.com/backend-api/wham/usage` | **OAuth**（Bearer + `chatgpt-account-id` 头） | `plan_type`、`rate_limit.primary_window/secondary_window`（`used_percent`、`limit_window_seconds`、`reset_after_seconds`） | 中高 |
| Claude Code（Pro/Max） | 社区 | `GET https://api.anthropic.com/api/oauth/usage` | **OAuth**（`user:profile` scope） | `five_hour`、`seven_day`、`limits[].weekly_scoped`（字段名需实测） | 中 |

**通用契约（中转站/网关，比厂商接口更稳）**：NewAPI `GET {base}/api/usage/token/`、
Sub2API `GET {base}/v1/usage`（`mode/quota_limited/rate_limits[{window:"5h"|"1d"|"7d",limit,used,remaining,reset_at}]`）、
CC Switch `GET {base}/user/balance`。用户 Key 来自中转站时优先走这三条。

### 第二轮补录（对照 GCMP 覆盖查漏）

| 服务 | 数据来源 | Endpoint | 鉴权 | 备注 | 置信度 |
| --- | --- | --- | --- | --- | --- |
| ClinePass | 社区逆向 | `GET https://api.cline.bot/api/v1/users/me/plan/usage-limits` | Bearer（API Key 即可） | `data.limits[].{type: five_hour\|weekly\|monthly, percentUsed, resetsAt}`，成功判据是 `success=true` 而非状态码；≥4 个独立实现一致 | 高 |
| Grok（Grok Build / SuperGrok） | 社区逆向 | `GET https://cli-chat-proxy.grok.com/v1/billing?format=credits`（回退 `/v1/billing`） | **OAuth** + `X-XAI-Token-Auth: xai-grok-cli` | 需 Grok CLI 登录态（`~/.grok/auth.json`）；响应为 protobuf 省略 0 值风格；与 xAI 官方 Management API（团队预付费余额）是两套东西 | 高 |
| StepFun 阶跃星辰 | 官方文档 | `GET https://api.stepfun.com/v1/accounts`（国际 `.ai`） | Bearer | `balance` / `total_cash_balance` / `total_voucher_balance`；**GCMP 漏做的一家** | 高 |
| Moonshot 开放平台余额 | 官方文档 | `GET https://api.moonshot.cn/v1/users/me/balance` | Bearer | `available_balance` / `cash_balance`（可为负）/ `voucher_balance`；与 Kimi Code 套餐是不同产品、不同 Key | 高 |
| OpenRouter | 官方文档 | `GET /api/v1/key`（任意 Key）／`GET /api/v1/credits`（**需 Management Key**） | Bearer | 429 可直接读 `X-RateLimit-*` 头；普通 Key 调 credits 得 403 | 高 |
| 硅基流动 | 官方文档 | `GET https://api.siliconflow.cn/v1/user/info`（国际 `.com`） | Bearer | `totalBalance` / `chargeBalance` / `balance`（赠送）；金额为字符串 | 高 |

**确认"无公开接口"（不要再找）**：百度千帆、讯飞星火——官方文档索引与 SDK 均无额度/用量端点。
**只有控制台 Cookie 能查（需内嵌浏览器，随时可能失效）**：阿里云百炼 Token Plan、火山方舟 Coding/Agent Plan、小米 MiMo。
**官方但有签名门槛**：腾讯云 TokenHub（`tokenhub.tencentcloudapi.com`，API 3.0 + AK/SK TC3 签名，不是 Bearer）。

## 二、高峰时段规则（可离线编码）

编码模型：`{ days: [1-7], start: "HH:MM", end: "HH:MM", tz: IANA, holiday_calendar? }`（1=周一）。

| 服务 | 是否区分峰谷 | 规则 | 置信度 |
| --- | --- | --- | --- |
| DeepSeek | 是（高峰 2 倍价） | 周一至周五 `01:00–04:00` 与 `06:00–10:00` **UTC**（= 北京 `09:00–12:00`、`14:00–18:00`）；**中国法定节假日全天按平峰**；平峰为高峰 5 折 | 高（官方） |
| GLM（bigmodel / Z.ai） | 是（平峰按 50% 积分抵扣） | 周一至周五 `14:00–18:00`（北京时间 = 新加坡时间 UTC+8）；周末全天平峰 | 高（官方） |
| Claude Code | **已取消** | 历史：周一至周五 `05:00–11:00` PT；官方 2026-05-06 取消高峰降额并翻倍 5h 限额 → UI 默认不展示峰谷 | 取消=高；历史时段=中 |
| MiniMax | 承认存在 | 官方明确「高峰时段存在动态限流」但**未公布时段** → 无法判定，UI 只能写「高峰期可能动态限流」 | 时段未找到 |
| Kimi / Codex / OpenCode Go / CommandCode | 套餐层否 | OpenCode Go 与 CommandCode 仅在使用 DeepSeek 系模型时透传上游峰谷价 | 高 |

**节假日数据**：`NateScarlet/holiday-cn`（每日自动抓取国务院公告，`{year}.json`，字段 `days[].date/isOffDay`）——
只取 `isOffDay=true` 的放假日；**调休上班的周末不计入高峰**（高峰窗口本身只覆盖周一至周五）。

## 三、实现参考（GCMP 的文件级设计）

`VicBilibily/GCMP`（VS Code 扩展，TypeScript，MIT）：为 GitHub Copilot Chat 注入多家模型提供商，附带额度查询面板。

### 3.1 GCMP 作为上游：能自动同步什么，不能同步什么

| 数据层 | 载体 | 能否自动 |
| --- | --- | --- |
| 模型清单 / 上下文 / 能力 / sdkMode | `https://gcmp.dev/configs/<id>.json` 或仓库 `src/providers/config/*.json` | **可全自动** |
| 聊天 baseUrl、模型级路由 | 同上 | 可全自动 |
| 峰谷时段（`tiers[].cron` + timezone）与单价 | 同上 | 可全自动（注意下面的形态坑） |
| 额度查询 endpoint / HTTP method / 鉴权头 | `src/quota/providers/*.ts` 的 `buildRequest` | **不可**（TS 代码，AST 只能提候选） |
| 响应字段路径 / 成功判据 / 单位换算 | 各 provider 的 `parseAndValidate` / `format` | 只能半自动 + 人工复核 |
| OAuth / CLI 类（Codex、Grok） | `src/cli/auth/*.ts` | 人工 |

**形态坑（实测）**：`models[].tokenPricing` 有**四种形状**——`null`（免费模型）、裸数组 `[in,out,cache]`、
`{USD:[...],RMB:[...]}`、`{pricing:{...},tiers:[...]}`；只有最后一种带峰谷 tiers。任何"照字段名硬取"的脚本
都会在这一步挂掉（我们的同步工具第一版就是这么挂的），必须先判类型。
**峰谷边界**：它的 cron 小时区间**含端点**（`* 9-11` ≡ `[09:00,12:00)`），与官方时段等价；
但写成 `14-18` 实际覆盖到 19:00，跨整点的官方区间（如 `06:00–10:00 UTC`）照抄会多算 1 小时。
**节奏与许可**：约 0.7 个 release/天（2026-01 起 184 个 release，最新 0.29.0/2026-10-16），`CHANGELOG.md` 逐版本维护；
MIT，Copyright (c) 2025 VicBilibily——可复用、需保留版权与许可声明，且不得暗示作者背书。
**注意它是"内部发布通道"**：`gcmp.dev/configs` 无 SLA 与兼容承诺，要按"可失败的上游"处理（缓存 + 失败保留上一版）。
**落地**：`ai-quota-rules` 仓库的 `tools/sync_gcmp.py` 按上述边界实现（拉快照 + 记录 `gcmpVersion`/`contentHash` +
与本仓库峰谷规则逐家 `--diff`）。

### 3.2 文件级结构
- `src/quota/providers/*.ts`：**每厂商一个文件**（`opencode.ts` / `commandcode.ts` / `kimi.ts` / `minimax.ts` /
  `deepseek.ts` / `zhipu.ts` / `clinepass.ts`），统一协议 + `src/quota/parsers/*` 负责响应解析。
- `src/quota/codexQuota.ts`：Codex 的 OAuth 用量读取（`wham/usage`）。
- `src/utils/pricing/pricingTierResolver.ts`：**离线峰谷判定**（5 字段 cron + IANA 时区），
  配 `src/providers/config/deepseek.json` 的 `"tiers":[{ "cron": "* 9-11,14-17 * * 1-5" }]`
  ——注意它的结束整点处理与官方 UTC 区间有 1 小时边界差，照抄要按官方区间重写。
- 另有 `src/quota/compatible/customUsageQuery.ts`：自定义用量模板（自建中转站场景）。

其它可参照：Rainytoken（安卓，多厂商卡片 + 桌面小组件，形态最接近移动端）、
CodexBar（macOS，Claude/CommandCode 的 OAuth 与 Cookie 路径记录最全，`docs/*.md`）、
`api-balance-checker-extension`（声明式 JSON 模板 + 响应字段归一化清单：`remaining/used/total/unit/expires_at`）。

## 四、口径陷阱

- **金额一律按字符串处理再转数**：DeepSeek / SiliconFlow / Novita 都是字符串；Novita 单位是 `1/10000 USD`。
- **窗口语义各不相同**：MiniMax 返回的是「剩余百分比」（`current_interval_usage_count` 名字像已用、实为剩余）；
  Kimi 的 `limit_month_total` 是账户总额度，不该出现在进度条上。
- **国内站 / 国际站是两套账号体系**：Kimi（`platform.kimi.com` vs `.ai`）、MiniMax（`.com` vs `.io`）、
  GLM（`bigmodel.cn` vs `api.z.ai`）——Key 不通用，混用 401。
- **不要默认远端规则可执行**：规则集只放数据（endpoint / 字段路径 / 时段），不含脚本或表达式引擎。
- 峰谷 UI 只在**有官方规则**的两家（DeepSeek、GLM）展示；其余写「无峰谷」或「可能动态限流」，
  否则等于替厂商编规则。

## 来源

| 内容 | 来源 |
| --- | --- |
| GCMP 的 provider/parser 划分与峰谷判定 | https://github.com/VicBilibily/GCMP（源码） |
| GCMP 公开配置通道（模型/价格/峰谷 cron） | https://gcmp.dev/configs/index.json 、`/configs/<id>.json`（实测 2026-10-19，gcmpVersion 0.29.0） |
| Compatible 自定义用量模板字段 | GCMP `src/types/sharedTypes.ts`、`src/utils/config/jsonSchemaProvider.ts`（url/method/authType/headers/`successConditions`/`fields[].arrayPath`/四则计算字段） |
| 第二轮补录各家 | ClinePass: GCMP `src/quota/providers/clinepass.ts`；Grok: GCMP `src/quota/grokQuota.ts` + `src/cli/auth/grokCliAuth.ts`；StepFun: platform.stepfun.com/docs/zh/api-reference/accounts |
| OpenCode Go 用量窗口 | https://opencode.ai/docs/go/ ＋ anomalyco/opencode PR #16513 |
| Kimi 用量结构 | https://github.com/MoonshotAI/kimi-code（`packages/oauth/src/managed-usage.ts`） |
| MiniMax 套餐额度 | https://platform.minimax.io/docs/m-plan/usage-rules 、/m-plan/faq 、MiniMax-AI/cli |
| DeepSeek 余额与峰谷 | https://api-docs.deepseek.com/api/get-user-balance 、/quick_start/pricing |
| GLM 峰谷与积分 | https://docs.bigmodel.cn/cn/coding-plan/overview 、https://docs.z.ai/devpack/overview |
| Claude Code 取消高峰降额 | https://www.anthropic.com/news/higher-limits-spacex |
| Codex wham/usage | https://github.com/openai/codex（backend-client 源码） |
| 节假日数据 | https://github.com/NateScarlet/holiday-cn |
