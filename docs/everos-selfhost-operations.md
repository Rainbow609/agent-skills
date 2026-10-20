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

## everos-memory MCP 通道

- 注册：`uvx everos-mcp`，env `EVEROS_BASE_URL`／`EVEROS_USER_ID`——身份由 MCP 服务端注入，工具调用无需传 user_id。
- 🌟 `add_memory(wait=true)` 会撞 MCP 客户端约 180s 超时：等待被掐死但**抽取仍在后台继续**（本会话实测：wait 超时，数分钟后检索命中）。默认 `wait=false`，写后 1-2 分钟再 `search_memory` 验证；`list_memories` 比 `search_memory` 更早可见新条目（工具自述官方明文）。
- `search_memory` **不暴露 method 参数**，恒走服务端默认（hybrid）——无 embedding 时该通道整体不可用（见下节）。

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

决策时间线：2026-10-18 个人记忆库（113 条）无损迁入 EverOS、Memorix 停写、双写废除；2026-10-19 zcode 内置记忆（`~/.zcode/cli/memories/` 自动记忆）由用户关闭——单写 EverOS 定版（全局 AGENTS.md「记忆（单写 EverOS）」节）。

**前任系统实测缺陷（公平复测：同主题条目两侧确证存在后，同查询双系统对测）**：

- 🌟 **Memorix 1.9.3 中文检索系统性失效**：中文查询 **6/6 零命中**——含精确标题子串「接续双开」「上色模型在线下载」（条目 #117/#113 确在库）；英文 token 2/2 命中（`restoreWindowStage`/`readSync`，考古精度好）。根因已源码实锤（dist/index.js `tokenize()` 10966 行）：**只按空白切分，无空格中文连续串＝整串单 token**，查询 token 须与文档 token 精确相等才命中；bundle 内 `NON_CJK_HYBRID_SIMILARITY` 常量印证 CJK 走独立的旧相似度路径。fast＝balanced：未配置 embedding，文档宣称的向量检索从未生效。
- 🌟 **装 embedding 也救不了中文（有界实验实锤，2026-10-19）**：配 SiliconFlow Qwen3-Embedding-8B（TOML 键＝`[embedding] provider="api"`——合法值仅 api/fastembed/transformers/auto，provider="off" 为官方脚手架默认禁用值；doctor 报 4096d ready）后：新写入且写入时已算好向量的测试条目，中文唯一关键词仍 0 命中、英文 token 立即命中。原因链＝启动水合 `allowNetworkProbe:false` 只附磁盘缓存（语料向量仅在写入时产生）＋CJK 查询走旧相似度路径绕过向量道。**结论：Memorix 中文检索不可修，放弃救治是正解。**
- **zcode 内置记忆**：MEMORY.md 索引超限截断（27.3KB > 24.4KB 上限，条目过长仅部分加载——harness 实测告警）；平台绑定仅服务 zcode。
- Memorix 时延恒 ≈1s/次（CLI 进程启动主导，112 条小库亦快不起来）。

**EverOS 换来的能力**：中文语义检索正常（改述命中、MCP 相关度 0.62 过 0.6 校准线）；hybrid 亚秒级（0.13-0.29s，Go 订阅线 decider 偶有秒级波动）；跨项目 `user_id` 作用域与 everos-memory MCP 身份注入；episode→case→skill 蒸馏管线（轨迹复用）。

** Memorix 终态定位**＝英文术语考古的冻结档案：不写、不删、不迁（其 112 条观察与 EverOS 语料是同主题的不同表示，无单点真源冲突）。检索顺序四轨见本目录 README「与其它记忆层的关系」。
