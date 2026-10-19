# EverOS 自托管运维与集成配方

> 适用：everos 1.4.2（uv 安装，`~/.local/bin/everos`，HTTP API `127.0.0.1:8000`）。
> 证据口径：**官方明文**＝包内置 default.toml/env.template/源码注释；**实测**＝2026-10-19 本机操作与计时；**推演**＝未逐项复测，标注「推演」。
> 同族文档：[opencode-zen-gateway-session-header.md](./opencode-zen-gateway-session-header.md)（Go 网关会话头与本地注入代理）、[coding-plan-quota-and-pricing.md](./coding-plan-quota-and-pricing.md)（订阅额度）。

## 部署与进程管理

- 启动＝`everos server start`（自守护进程化，父进程归 launchd）；**只有 `start` 一个子命令**，无 stop/restart（官方 `everos server --help` 明文）。重启＝kill＋start。
- 🌟 实测坑：SIGTERM 后进程可能**挂起不退**（端口已释放、但 OME 引擎锁仍持有，新实例报 `EngineLockHeldError` 启动失败）——SIGTERM 等 4-5s 不退就 `kill -9`；引擎锁是 flock 文件锁，进程死锁自释放。
- 无 launchd/brew 服务管理条目（自行守护）。

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
