# 规则集/配置下发的国内可达方案（镜像与 CDN 选型 + 客户端多源兜底）

> 适用前提：应用需要从 GitHub 上游仓库定期拉取「规则集 / 配置 / 数据文件」，用户主要在中国大陆。
> 本文给的是**可落地顺序 + 失败判据 + 校验降级**，不是"哪个 CDN 最好"的口号。
> 证据日期 **2026-10-19**；调研环境出口在香港且走透明代理，**凡大陆可达性均标注「未实测」**，
> 只用公开证据（社区 issue/官方文档/本机旁证）佐证。落地实例见 `ai-quota-rules` 仓库的 `mirrors/mirrors.json`。

## 核心结论

1. **raw.githubusercontent.com 不能作大陆主通道**（DNS 未被污染但从大陆不可依赖）；jsDelivr 可用但"不是中国 CDN"，
   分支引用有 **12 小时缓存**，且**限流时返回 HTTP 200 + 正文 `429: Too Many Requests`**——只看状态码会把垃圾写进缓存。
2. **免备案的稳定通道只有两条**：Gitee raw（大陆直连最稳，但同步靠手动/`同步更新`按钮，且有仓库被下架先例）
   与 npmmirror（`registry.npmmirror.com/<pkg>/<ver>/files/<path>`，需先发 npm 包，不返回 ETag）。
3. **ghproxy 类只能兜底**：节点全在境外，域名持续漂移（`ghproxy.com` DNS 污染、`raw.gitmirror.com` /
   `hub.gitmirror.com` 已 NXDOMAIN）。因此**镜像列表必须放在可远程更新的配置里**，不能硬编码进 App。
4. **要大陆稳定体验就得备案**：Cloudflare 的 China Network 是 Enterprise 独立订阅、每个域名都要 ICP，
   R2/Pages/Workers 不在其内（推测）；走"域名备案 + 境内 CDN"才有保障，且**网站备案与 App 备案互不通用**。
5. **共同范式**：多源顺序写在配置数据里、文件自带版本、缓存"先本地后远端"、**下载失败绝不覆盖旧文件**、
   换源要判内容合法性而不只看 HTTP 状态码。

## 一、可达性矩阵（2026-10-19）

| 端点 | 大陆解析器结果 | 本机实测（香港出口） | 公开证据 | 评级 |
| --- | --- | --- | --- | --- |
| `raw.githubusercontent.com` | 正常解析（未污染） | 200 | 多个规则仓库 README 明写"大陆需加速" | 大陆不可依赖（未实测） |
| `cdn.jsdelivr.net` | Cloudflare | 200，1.83s | 社区记录限流假 200、大文件下不完 | 可用但不稳 |
| `fastly.jsdelivr.net` | Fastly | 200，1.39s | OpenClash #5356 记录同样 429/超时 | 同上 |
| `testingcf.jsdelivr.net` | Cloudflare | 200，0.72s | jsDelivr #18734：作者建议改用它绕开某 ISP 不通 | 备用首选 |
| `gcore.jsdelivr.net` | Cloudflare | 200，1.99s | MetaCubeX README 列为第三镜像 | 备用 |
| `jsdelivr.net`（主站） | 阿里/DNSPod DoH 均返回 `1.2.3.4` | — | 说明主站域名在大陆 DNS 层被封 | 站点不可用 |
| `cdn.jsdelivr.net.cn` | 解析到香港 IP（来历不明） | — | 社区反馈无法访问（2026-10-04） | 不建议依赖 |
| `gh-proxy.com` | Cloudflare | 200，1.09s | 社区建议从 ghproxy.com 迁到它（2026-07-04） | 可用（兜底） |
| `ghfast.top` | 美国 HostPapa | 200，2.16s | 同机 `mihomo-config` 已在用 | 可用（兜底） |
| `ghproxy.net` | 法国 OVH | 200，**11.51s** | 无状态公告 | 兜底（慢） |
| `ghproxy.com` | 韩国 KT | 请求失败 | DNS 污染严重、易 RST | 不可用 |
| `raw.gitmirror.com` / `hub.gitmirror.com` | **NXDOMAIN** | 失败 | — | 已失效 |
| `gitee.com` raw | 正常 | 200，带 ETag + `max-age=60` | — | 大陆直连最稳（免备案） |
| `registry.npmmirror.com` | 正常 | 200，`max-age=31536000`，**无 ETag** | — | 大陆直连稳（免备案） |

## 二、jsDelivr 的真实约束（官方文档）

- 缓存：**分支引用 12 小时**、tag/semver 永久、version aliasing 7 天；有永久 S3 缓存，
  **tag 一旦命中就改不掉**（只能发新 tag + 调 purge API）。
- 限制：单文件 > 20 MB 不支持（整包 > 150 MB 不支持）。
- 官方叙事是"靠近中国城市"，**不是"在中国大陆境内"**。
- 事故范式（OpenClash #5356，2026-10-15）：限流时返回 **HTTP 200，正文是纯文本 `429: Too Many Requests`**；
  16 MB 文件在 `cdn.jsdelivr.net` 上下不完。教训：**必须按"正文不是合法 JSON/长度越界"判失败**。
- 另一类：jsDelivr #18734（2026-08-27，仍 open）"特定 ISP 上间歇性完全不可达"，官方未定位。

## 三、Gitee 与 npmmirror（两条免备案通道）

- **Gitee**：支持从 GitHub 导入仓库；`同步更新` 按钮是**强制同步（直接覆盖）**；社区版配额
  单仓库 ≤ 500 MB、单文件 ≤ 50 MB、账号 5 GB、仓库数 ≤ 1000 —— 规则集几百 KB 完全够。
  raw 直链 `https://gitee.com/<owner>/<repo>/raw/<branch>/<path>` 可用。**风险**：`dev-sidecar` README 明写
  "Gitee 上的同步项目已被封禁"，故不能作唯一源。
- **npmmirror**：把数据作为 npm 包发布（`npm publish` 到官方 registry）→
  `https://registry.npmmirror.com/<pkg>/<version>/files/<path>` 直接取包内文件（实测 200，
  `Cache-Control: max-age=31536000`，**无 ETag**，只能靠 URL 里的版本号寻址）。
  一次发布同时得到四个入口：npm 源 + `cdn.jsdelivr.net/npm/<pkg>@<ver>/<file>` + `unpkg.com/...` + npmmirror。
  注意 npm 支持 unpublish（72 小时规则），而 jsDelivr 的永久缓存会继续提供旧副本（安全网，也是"改不掉"的坑）。

## 四、备案 + 境内 CDN（唯一能保证大陆体验的通道）

- Cloudflare `developers.cloudflare.com/china-network/`：China Network 属 **Enterprise 单独订阅**，
  **每个 apex 域名都要有效 ICP 备案**，大陆机房由**京东云**运营，且明确"并非所有产品可用"
  （只点名 WAF/DDoS/Bot、境内权威 DNS、Global Acceleration）——**R2 / Pages / Workers 不在其中（推测）**。
- 腾讯云 COS 文档原文：自定义域名"请确保输入的域名已备案"，且**只认网站备案，App 备案无法接入**。
- 阿里云 OSS 默认域名对 HTML/图片强制 `Content-Disposition: attachment`，要正常行为就得绑自定义域名（→ 备案）。
- 成本量级（估算）：OSS 标准存储 ¥0.12/GB/月；腾讯云 CDN 大陆流量 ¥0.21/GB（0–2TB 档）。
  规则集 100 KB × 10 万 DAU × 日 3 次 ≈ 900 GB/月 ≈ **¥190/月**；
  **用 ETag/If-None-Match 拿 304 可再降一个数量级**——小文件高频拉取正是 304 最有效的场景。

## 五、生态里的既有做法

| 项目 | 多源策略 | 本地兜底 | 版本/校验 | 失败降级 |
| --- | --- | --- | --- | --- |
| mihomo rule-providers | 单 `url`，多源靠 README 给链接 | `path` 本地缓存 + `path-in-bundle` 内置包 | 内部按 hash 比对，内容未变不重写；有 ETag 开关 | **下载失败保留旧文件**（读本地失败才回退 bundle） |
| Loyalsoldier/clash-rules | README 每文件给 raw + jsDelivr 两条并注明 12h 延迟 | 无 | 无 | 靠客户端 |
| MetaCubeX/meta-rules-dat | README 表格给 GitHub Release / cdn / testingcf 三列 | 无 | 无 | 靠客户端 |
| anti-AD | raw + **自有域名**双通道 | 无 | 无 | 靠客户端 |
| EasyList / AdGuard 系 | 单份文件，头部带 `Version/Last modified/Expires/Commit` | 客户端按 `Expires` 更新 | **文件内版本号 + commit + 过期天数** | 客户端保留旧副本 |
| OpenClash（GEO 库） | 用户手工换主机 | 保留旧库 | 无 | 反面案例：假 200 覆盖过旧库 |
| dev-sidecar | 多镜像 + 测速自动切换 | 代理层本地缓存 | 无 | **自动切换 + 测速** |

可提炼的 5 条共识：① 多源顺序写进配置数据；② 文件自带版本；③ 先本地后远端且失败不覆盖；
④ 换源要判内容合法性（假 200、challenge 页）；⑤ 内容地址与校验信息分离（小 `manifest.json` 指向带版本的文件）。

## 六、推荐方案（客户端）

```
GitHub 上游（唯一真源：main 开发，tag 发布）
  └─ Actions：schema+语义校验 → 生成 ruleset.json → manifest.json(version/sha256/size/min_client_version)
     → 打 tag + Release → （可选）npm publish → （可选）境内 CDN
多源（同一份文件的多个 URL，清单本身可远程更新）
  ① 备案域名 + 境内 CDN   ② Gitee raw   ③ npmmirror
  ④ jsDelivr 四主机轮换    ⑤ ghproxy 池   ⑥ raw GitHub（仅海外）
客户端：内置兜底副本 → 磁盘缓存（current/previous 双槽）→ 内存态（UI 只读内存态）
```

- **拉取顺序**：先拉 `manifest.json`（约 0.5 KB）比版本，版本新才拉全量；单次刷新总预算 20–25 s、
  **最多试 3 个源**（省电省流量），失败就等下次。
- **失败判据**：`404/410` 立即换源；`403/5xx/超时/Cloudflare challenge` 换源；
  **TLS 证书错误 → 本次禁用该源**（防中间人）；`2xx` 但正文非法 JSON/长度越界 → 换源。
- **退避**：某源连续失败则跳过 12 小时（持久化），成功清零；记住上次成功的源，
  但每周强制从源 ① 重新探测一次。
- **校验八步**（任一步失败都丢弃本次下载、保留上一版）：HTTP 层（2xx/304）→ 字节数与
  `Content-Length` 一致 → 首字节为 `{` 且大小在 [1 KB, 512 KB] → JSON 解析 + `schema_version` 已知 →
  `sha256` 与 manifest 一致 → 语义校验（https、id 唯一、时区合法）→（可选）ed25519 验签 →
  `min_client_version <= 本机`，否则只读不生效并提示升级。
- **原子写**：写临时文件 → fsync → rename（不要直接覆盖正式文件，进程被杀会留半截文件）。
- **版本比较**：用单调的字符串版本号（如 `2026.10.19.1`），**不要用时间戳**（时钟不可信）。
- **只用 HTTPS + 系统 CA**；规则文件**只能是数据**，不含脚本/表达式引擎。

## 七、落地实例

`ai-quota-rules`（https://github.com/Rainbow609/ai-quota-rules）按上述方案搭好：
`mirrors/mirrors.json`（六源 + 拉取策略 + 失败判据，含"哪个源已失效"的历史注记）、
`tools/{validate,build}.py`（离线校验 + 生成 manifest/sha256）、
`.github/workflows/publish.yml`（校验 → 构建 → dist 变更才提交并打 tag 发 Release → 可选 npm 发布）。

## 来源

| 内容 | 来源 |
| --- | --- |
| jsDelivr 缓存/限制/限流假 200 | https://github.com/jsdelivr/jsdelivr（README 即官网数据源）；OpenClash #5356（2026-10-15） |
| 特定 ISP 不可达 | jsDelivr #18734（2026-08-27） |
| ghproxy 迁移与失效 | cssxsh/mirai-skia-plugin#23（2026-07-04）；docmirror/dev-sidecar#699（2026-08-28） |
| Gitee 导入/同步/配额/风险 | help.gitee.com/questions/GitHub仓库快速导入Gitee及同步更新；help.gitee.com/account/usage-quota；dev-sidecar README |
| npmmirror 能力 | https://npmmirror.com（官方定位）+ 本机实测 `registry.npmmirror.com` |
| Cloudflare China Network | https://developers.cloudflare.com/china-network/ |
| 备案与价格 | 腾讯云 COS 自定义域名文档；腾讯云 CDN 计费文档；阿里云 OSS 计费/域名文档 |
| 生态做法 | mihomo `component/resource/vehicle.go`、`fetcher.go`；MetaCubeX / Loyalsoldier / anti-AD / EasyList README |
