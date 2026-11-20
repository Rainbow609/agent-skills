# EverOS 自托管运维与集成配方

> 适用：everos 1.4.2（uv 安装，`~/.local/bin/everos`，HTTP API `127.0.0.1:8000`）。
> 证据口径：**官方明文**＝包内置 default.toml/env.template/源码注释；**实测**＝2026-10-19 本机操作与计时；**推演**＝未逐项复测，标注「推演」。
> 同族文档：[opencode-zen-gateway-session-header.md](./opencode-zen-gateway-session-header.md)（Go 网关会话头与本地注入代理）、[coding-plan-quota-and-pricing.md](./coding-plan-quota-and-pricing.md)（订阅额度）。

## 部署与进程管理

- 启动＝`everos server start`（自守护进程化，父进程归 launchd）；**只有 `start` 一个子命令**，无 stop/restart（官方 `everos server --help` 明文）。重启＝kill＋start。
- 🌟 实测坑：SIGTERM 后进程可能**挂起不退**（端口已释放、但 OME 引擎锁仍持有，新实例报 `EngineLockHeldError` 启动失败）——SIGTERM 等 4-5s 不退就 `kill -9`；引擎锁是 flock 文件锁，进程死锁自释放。
- **开机自启（2026-10-20 配置，实测）**：此前**无 launchd/brew 服务管理条目**，纯手动 start、重启即失联
  （实际案例：10 组 everos-mcp 客户端因服务端不在而空转）。现配 LaunchAgent
  `~/Library/LaunchAgents/com.rainbow.everos-server.plist`：`RunAtLoad` 登录拉起 +
  `ThrottleInterval 30s` 兜底，**不配 KeepAlive**——`start` 自守护后包装进程即退，
  KeepAlive 会把「启动成功→包装退出」误判为崩溃无限重启打转，还反复撞上面的 EngineLockHeldError；
  日志 `/tmp/everos-server.{log,err}`。加载：`launchctl bootstrap gui/$(id -u) <plist>`（卸载 bootout）。
  在线判定：`curl -m 3 http://127.0.0.1:8000/` 返回 HTTP 404（API 服务器根路由为空）＝服务已听。

## 配置体系（~/.everos/）

| 文件 | 管什么 | 生效方式 |
|---|---|---|
| `everos.toml` | api/sqlite/lancedb/llm/decider/multimodal/embedding/rerank/clustering… 模型与运行面 | 进程缓存，**改后必须重启**（embedding/llm capability 首次构建即缓存——`component/embedding/accessor.py` 官方明文） |
| `ome.toml` | 抽取策略开关/cron/gate/重试 | **约 2s 热加载**（文件头官方明文）；未知键直接报 `StartupValidationError`（防拼错静默失效） |

- 环境变量 `EVEROS_<SECTION>__<KEY>` 优先级高于 toml（everos.toml 头部注释明文）；进程 env 无 `EVEROS_*` 时 toml 即权威。
- rerank/multimodal 未配置＝启动 warning ＋能力缺席（软依赖，见下）——不是错误，服务照常起。

## 写路径 v2 契约（实测闭环：add→accumulated→flush→extracted）

```json
POST /api/v2/memory/add
{"app_id":"default","project_id":"default","session_id":"mcp-<user_id>-<12hex>","async_mode":false,
 "messages":[
   {"sender_id":"<user_id>","sender_name":"User","role":"user","timestamp":<epoch_ms>,"content":"…"},
   {"sender_id":"assistant-<user_id>","sender_name":"Assistant","role":"assistant","timestamp":<ms+1>,"content":"…"}]}
```

- 🌟 缺 `session_id` 直接拒收（INVALID_INPUT，实测）；自托管 app_id/project_id 缺省 `"default"`（everos-mcp `config.py` `_env_scope` 明文）。
- `async_mode:false`（同步）：抽取完成后返回 `{"status":"extracted"}`；缺省＝入队返回 `accumulated`，**立即 flush 会与缓冲写入竞态**（everos-mcp `client.py` 注释明文）。
- flush：`POST /api/v2/memory/flush`，body 同 scope＋session_id；返回 `no_extraction`＝缓冲已空（可当「已处理」证据复用）。
- 身份两侧惯例：user 侧 sender_id=`EVEROS_USER_ID`，assistant 侧=`assistant-<user_id>`（everos-mcp `server.py` 明文）。

### 抽取 JSON 尾逗号故障与 prompt slot 修复（2026-10-20 实测闭环）

- **故障与定位**：长中文条目抽取时 `episode_extract_retry` 连续报 `Illegal trailing comma before end of object`（deepseek-v4.1-flash 对长 JSON 稳定输出尾逗号，重试救不了——每次都坏），重试期间 flush 撞上变 500（MCP 侧表现＝`background add_memory failed: Internal server error`）；**短条目不受影响**。定位一条命令：`grep episode_extract_retry /tmp/everos-server.log`。
- **官方修复位（1.4.2）＝prompt slot 覆盖**：`site-packages/everos/config/prompt_slots/episode_extract.yaml`（`_config_root()` 指向包内 `config/`；注释明文「`~/.everos/` 三层覆盖预留未来里程碑」，即当前版本唯一官方定制位）。做法＝`enabled: true` + `template` 填入官方 `everalgo/user_memory/prompts/en/episode.py::EPISODE_GENERATION_PROMPT` 全文，末尾（recency 位）追加「RFC 8259 严格语法块：禁尾逗号 / 转义引号换行 / 裸 JSON 对象输出」。**模板契约**：三个占位符 `{conversation_start_time}`/`{conversation}`/`{custom_instructions}` 必须保留；字面大括号必须双写（`render_prompt` 镜像 `str.format`：`{{`→`{`，占位符缺失不报错会静默漏渲染）。
- **验收**：同一长条目重写，全链路零重试（episode upserted=1 / atomic_facts count=19 attempt=0 / user_profile UPDATE / flush 200）。
- **⚠ 升级即失效**：`uv tool upgrade everos` 会把该 yaml 重置回 `enabled: false`——抽取又开始报尾逗号时先查这里。种子副本在 `~/.everos/prompt_slots/episode_extract.yaml`，恢复后 `launchctl kickstart -k gui/$(id -u)/com.rainbow.everos-server` 重启（实测 kickstart -k 干净换 pid，未触发 EngineLockHeldError）。
- **2026-10-23 复现与边界**：prompt slot 仍为 `enabled: true` 且含 RFC 8259 严格块，但同批两条约 1500–2000 字的长中文条目仍出现尾逗号：一条连续 3 次重试失败并令 `/api/v2/memory/flush` 返回 500，另一条长条目则成功入库——**属概率性失败，不是「长条目必坏」**。拆成约 350–450 字的两条短消息后均一次成功（episode upserted=1、atomic_facts 17/11、flush 200）。处置顺序：先看 yaml 是否被升级重置；若已启用仍失败，**优先拆短重写**，不要只重启或无限重试。
- **❌ 2026-11-20 已作废**：1.6.0 起 prompt slot 机制整体移除（自定义提示词只读包内 `config/custom_instructions/`，`~/.everos/` 覆盖仍是「未来里程碑」），1.7.0 升级后该 yaml 静默失效、只剩宿主机 3 次重试；用户裁定「接受内置提示词」，`~/.everos/prompt_slots/` 已删。**升级后再遇尾逗号故障，不要再找回这条路径**，直接拆短重写。

## everos-memory MCP 通道

- 注册：`uvx everos-mcp`，env `EVEROS_BASE_URL`／`EVEROS_USER_ID`——身份由 MCP 服务端注入，工具调用无需传 user_id。
- 🌟 `add_memory(wait=true)` 会撞 MCP 客户端约 180s 超时：等待被掐死但**抽取仍在后台继续**（本会话实测：wait 超时，数分钟后检索命中）。默认 `wait=false`，写后 1-2 分钟再 `search_memory` 验证；`list_memories` 比 `search_memory` 更早可见新条目（工具自述官方明文）。
- `search_memory` **不暴露 method 参数**，恒走服务端默认（hybrid）——无 embedding 时该通道整体不可用（见下节）。

## profile → magpie 摘要投射（固定动作，launchd 每晚 03:40）

分层后的**唯一单向桥**：EverOS `user_profile`（台账派生物）→ magpie 一条摘要（开局注入）。方向铁律：只 EverOS→magpie；magpie 侧手工编辑会在下次投射被覆盖。

- **脚本**：`~/git/agent-skills/scripts/everos-profile-digest.py`，仅用标准库，`/usr/bin/python3`（3.9.6，无 PyYAML）可直接跑；符号链接 `~/.local/bin/everos-profile-digest`。
- **读**：`POST http://127.0.0.1:8000/api/v2/memory/get`，body `{user_id, memory_type:"profile", page_size:1}` → `data.profiles[0].profile_data`（JSON：`summary` / `implicit_traits[{trait,description,basis,evidence}]` / `explicit_info`），无需解析 md/YAML。用户清单来自 `~/.everos/default_app/default_project/users/` 下的目录名。
- **写**：magpie 的 MCP HTTP 端点 `http://127.0.0.1:3425/mcp/magpie/memory`（SSE 响应，本机免 key）。先 `memory_search {tags:[everos-profile-digest]}` 找到旧条目，再 `memory_save` 带 `id` 覆盖 → 幂等，库里永远只有一条（首建 2026-11-20 `m_0983bd244a2f`，kind=preference / scope=global / origin=agent）。kind 必须是 preference/rule/fact 之一：magpie 的注入块只渲染这三类，profile 类只进库、永远不进各代理的指令文件。
- **内容与预算**：来源是每用户的 `explicit_info` 事实（`summary` 也参与），按源序**整条**入选；与已有事实重复时只留较长的（标点归一后做包含判定），跨用户同样去重——profile 里 `summary` 往往就是某条 `explicit_info` 的浓缩版，合并后只剩一份。总长 **320 字封顶**（这条每晚进**所有代理的开局上下文**），放不下的整条丢弃，不截断成半句。`implicit_traits` 只取**证据 ≥5 条**的（最多 3 个）作为「证据充分的习惯」——trait 名是内部分类词，罗列 24 个既无信息量、又与全局规则重复。
- **手动**：`everos-profile-digest`（写）、`--dry-run`（只打印）、`--print-id`。日志 `~/Library/Logs/everos-profile-digest.log`。
- **调度**：`~/Library/LaunchAgents/local.magpie.profile-digest.plist`（Label `local.magpie.profile-digest`，03:40，RunAtLoad false）。重载：`launchctl bootout gui/$(id -u)/local.magpie.profile-digest; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.magpie.profile-digest.plist`；立刻验证：`launchctl kickstart -k gui/$(id -u)/local.magpie.profile-digest`。
- **失败面**：EverOS(:8000) 或 magpie 网关(:3425) 未起 → 退出码 1、日志留 `cannot reach EverOS or Magpie`，次日 03:40 自愈，无需人工补。
- **已知边界**：只有跑出 profile 的用户才有画像行——当前仅 `manbo-reader`；`deepseek-harness` / `git-workspace` / `knowledge-import` / `mihomo-config` 有目录无 profile，脚本跳过并记 `no profile, skipped`。

## magpie 注入块（`## Memory`）的刷新

指令文件里的记忆块由 magpie 写在 `<!-- magpie:begin -->` 与 `<!-- magpie:end -->` 之间，位于 `## 记忆…` 之后：

- **只渲染 `preference` / `rule` / `fact` 三类 active 条目**；`procedure` / `reference` / `profile` 只进库、不注入。全局条目按 Preferences/Rules/Facts 分组，项目条目按 `sources[].dir` 分到 `When working in <dir>:` 段；每条 400 字截断，`why` 以 `(why: …)` 附后。
- **刷新面（两个方向都不对）**：`memory_save` / `memory_forget`、`magpie library sync`、重启 magpie app 都**不会**让这个块反映新记忆；而 `magpie library instructions set` 会用 magpie 内部那份旧快照重排整块，把手工/脚本排好的内容**覆盖回旧文案**。所以：改完记忆跑 `magpie-memory-block` 才能进注入；每次 `instructions set` 之后也必须紧接着再跑一次。
- **重排**：`scripts/magpie-memory-block.py`（符号链接 `~/.local/bin/magpie-memory-block`），读 `~/.config/magpie/memory/m_*.md`（md 是源，`index.json` 会滞后），覆写 `~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.omp/agent/AGENTS.md` 的 Memory 段；内容未变时不动文件。改渲染规则前先确认 magpie 侧格式未变（这是对 magpie 内部格式的复刻）。
- **调度**：`~/Library/LaunchAgents/local.magpie.memory-block.plist`（03:45，紧跟 03:40 的 profile 投射）。日志 `~/Library/Logs/magpie-memory-block.log`。
- **升 active**：`memory_save` 只改内容、不改 `status`，candidate 想进注入得直接改 md frontmatter 的 `status: active`（`index.json` 会滞后，以 md 为准）。

## 检索方法矩阵与软依赖设计（官方源码）

| method | 硬依赖 | embedding 缺席时 |
|---|---|---|
| `KEYWORD` | 无 | ✅ 实测 39ms 可用 |
| `VECTOR`/`HYBRID`/`AGENTIC`/`LLM_MULTIROUND` | embedding（agentic 另需 rerank） | **硬 422 `ProviderNotConfiguredError`**——manager.py guard 注释官方明文：「宁过拒，不静默降级」（防 NoneType 深埋报错） |

- `EmbeddingCapability`／`RerankCapability`＝软依赖包装：provider 建不出（缺字段/坏 URL/不支持的 provider 名）→ `available=False`，**启动即定、改配置需重启**（accessor.py 官方明文）。
- 写路径 embedding 缺席不阻塞：cascade 经 `embed_or_none` 写 `vector=None`（文本照常入库）；聚类/profile/reflect/skill 等衍生策略检测到缺席整体跳过。
- 补配向量后有 `memory/cascade/_backfill.py` 回填管线（模块在案；回填细节未读——**存疑**）。
- 维度硬门槛：向量列固定形状、≥1024 维（本地实测：nomic-embed-text 768 维被 Episode schema 拒收）。

## 官方模型实践（default.toml / env.template 明文）

- `[llm]` 官方默认＝`openai/gpt-4.1-mini` @ OpenRouter（一个 key 全目录）；`[decider]` 留空继承＝官方推荐的单模型部署形态。
- 🌟 **decider 换模型时 model/base_url 必须同动**：只改 model 不改端点＝每次调用 404 且检索循环**不报错**、静默降级到固定 top-ranked 还谎报完整结果（default.toml 注释官方明文）。
- `[multimodal]` 独立配置，**必须支持 image_url parts**（官方默认 Gemini flash @ OpenRouter）。
- `[rerank]` 三 provider 形状：`deepinfra`（`POST {base}/{model}`，key 必填）／`vllm`（`POST {base}/rerank`，响应 `results[].relevance_score`，key 可空）／`dashscope`（阿里原生）；官方默认模型 `Qwen/Qwen3-Reranker-4B`。
- 抽取管线＝纯 chat＋JSON 解析（坏 JSON ValueError 自动重试，**不用 function calling**）——选型三要求：中文好、JSON 干净、**非思考变体**。

## 隐私上云阶梯（按暴露面从小到大）

`decider 上云`（只见检索中间态候选）＜ `embedding 上云`（文本作为输入出机，但输出向量不可逆重建）＜ `抽取上云`（轨迹原文全文作为 prompt 出机）。全本地则无暴露面。切分方案按敏感度组合，无官方指引（推演：官方默认全云）。

## 性能实测账（M4 / 16GB，2026-10-19）

| 指标 | 本地 Ollama（qwen3-4b 抽取＋qwen3-embedding） | 全上云（deepseek-v4.1-flash ＋ SiliconFlow Qwen3-Embedding-8B/Reranker-4B） |
|---|---|---|
| hybrid 检索 | 实测 411s（Ollama 卡死期）；健康时亦分钟级 | **0.23-0.27s** |
| 抽取 | 47s/memcell | flush 全批 **7.5s** 返回 extracted |
| keyword | 39ms | 39ms |

- 🌟 **Ollama 卡死诊断配方**（实测归纳）：驻留模型的小补全连续超时＋进程 CPU 0%＝runner 卡死/请求队列堵死，与负载无关——重启 Ollama 即恢复。
- 16GB 上双大模型互挤（4.7GB embedding＋2.5GB chat）＝换装风暴主因；思考模式是 4B 抽取慢的主嫌疑（推演：`ollama show --template` 含 thinking 分支，未逐 prompt 复测）。
- Ollama 服务另一消费者共存（如 opencode 自动探测）时排队放大；无显式 `OLLAMA_NUM_PARALLEL` 时 16GB 默认并行度极低（推演）。

## 迁移原因：为什么 EverOS 成为唯一记忆通道（2026-10-18 定案，10-19 复测加固）

决策时间线：2026-10-18 个人记忆库（113 条）无损迁入 EverOS、Memorix 停写、双写废除；2026-10-19 zcode 内置记忆（`~/.zcode/cli/memories/` 自动记忆）由用户关闭——单写 EverOS 定版。

2026-11-20 **分层定版**（用户裁定）：EverOS 存**长台账**，magpie 存**注入用短摘要**，方向单向——定案与事实先落 EverOS，只有开局必须知道的规则/偏好才摘要进 magpie，同一件事不在两边各写一份。全局 AGENTS.md 该节由「记忆（单写 EverOS）」改名为「记忆（分层：EverOS 台账 + magpie 摘要）」，并补上 magpie 层的定位（此前 magpie 块教 `memory_save` 与本规则相互矛盾，是双写漂移的来源）。同日 EverOS 由 1.5.1 升至 1.7.0，五个云端面（llm/multimodal/decider/embedding/rerank）统一改走本机 magpie 网关→OpenRouter。

**前任系统实测缺陷（公平复测：同主题条目两侧确证存在后，同查询双系统对测）**：

- 🌟 **Memorix 1.9.3 中文检索系统性失效**：中文查询 **6/6 零命中**——含精确标题子串「接续双开」「上色模型在线下载」（条目 #117/#113 确在库）；英文 token 2/2 命中（`restoreWindowStage`/`readSync`，考古精度好）。根因已源码实锤（dist/index.js `tokenize()` 10966 行）：**只按空白切分，无空格中文连续串＝整串单 token**，查询 token 须与文档 token 精确相等才命中；bundle 内 `NON_CJK_HYBRID_SIMILARITY` 常量印证 CJK 走独立的旧相似度路径。fast＝balanced：未配置 embedding，文档宣称的向量检索从未生效。
- 🌟 **装 embedding 也救不了中文（有界实验实锤，2026-10-19）**：配 SiliconFlow Qwen3-Embedding-8B（TOML 键＝`[embedding] provider="api"`——合法值仅 api/fastembed/transformers/auto，provider="off" 为官方脚手架默认禁用值；doctor 报 4096d ready）后：新写入且写入时已算好向量的测试条目，中文唯一关键词仍 0 命中、英文 token 立即命中。原因链＝启动水合 `allowNetworkProbe:false` 只附磁盘缓存（语料向量仅在写入时产生）＋CJK 查询走旧相似度路径绕过向量道。**结论：Memorix 中文检索不可修，放弃救治是正解。**
- **zcode 内置记忆**：MEMORY.md 索引超限截断（27.3KB > 24.4KB 上限，条目过长仅部分加载——harness 实测告警）；平台绑定仅服务 zcode。
- Memorix 时延恒 ≈1s/次（CLI 进程启动主导，112 条小库亦快不起来）。

**EverOS 换来的能力**：中文语义检索正常（改述命中、MCP 相关度 0.62 过 0.6 校准线）；hybrid 亚秒级（0.13-0.29s，Go 订阅线 decider 偶有秒级波动）；跨项目 `user_id` 作用域与 everos-memory MCP 身份注入；episode→case→skill 蒸馏管线（轨迹复用）。

** Memorix 终态定位**＝英文术语考古的冻结档案：不写、不删、不迁（其 112 条观察与 EverOS 语料是同主题的不同表示，无单点真源冲突）。检索顺序四轨见本目录 README「与其它记忆层的关系」。
