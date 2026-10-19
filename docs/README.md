# docs/ — 跨项目通用知识沉淀

本目录存放**跨项目可复用**的通用知识（规划比价、工具配方、平台坑、官方结论精炼），是本仓库「知识真源」的一部分。
项目特化内容（某项目的 `file:line`、项目策略与取舍）留在各项目仓库里，**不复制进来**——避免同一结论两处副本漂移。

## 索引

| 文档 | 主题 | 来源 | 入库 |
| --- | --- | --- | --- |
| `coding-plan-quota-and-pricing.md` | 订阅制 Coding Plan 额度与单价速查（OpenCode Go / Z.ai GLM / Kimi） | 通用 | 2026-10-15 |
| `git-common-knowledge.md` | Git 常用知识：vendor / workflow / worktree | 通用 | 2026-10-15 |
| `harmonyos-mcp-ecosystem.md` | 鸿蒙开发 MCP 生态（官方双线、模拟器工具组、避坑清单） | 通用 | 2026-10-16 |
| `kimi-code-agent-tools-whitelist.md` | Kimi Code 子代理 tools 白名单（必须用 Kimi Code 工具名） | 通用 | 2026-10-15 |
| `tag-based-release-workflow.md` | tag 唯一版本源：打 tag 之后的开发与版本演进 | manbo-reader 实践 | 2026-10-15 |
| `harmonyos-app-continuation.md` | HarmonyOS 应用接续：接入要点、硬数据、生命周期坑、调试配方 | manbo-reader 调研 | 2026-10-16 |
| `agents-md-best-practices.md` | AGENTS.md 写作与分层：8 工具加载机制对照、长度红线、量化证据、写/不写清单与维护流程 | 本体系实践 + 官方与社群调研 | 2026-10-16 |
| `agents-md-and-skills-tooling.md` | AGENTS.md / Skills 工具生态：同步器/linter/优化器/eval 的成熟度实测、社群失败案例、最小工作流与「上游 skill-creator 补齐」行动计划 | 本体系实践 + GitHub/npm/社群调研 | 2026-10-16 |
| `ai-coding-workflow-openspec.md` | AI Coding 工作流参考：初始化三件套（Skills/MCP/AGENTS.md）、OpenSpec opsx 六命令与按阶段模型分级、提示词模板、giscus strict=SHA-1 机制与跨语言评论聚合 | 外部博客调研（Ruixe 2026-09）+ giscus 官方文档一手复核 | 2026-10-16 |
| `openspec-official-guide.md` | OpenSpec/OPSX 官方文档精读：心智模型、core/expanded 双 profile、spec-driven 权威契约（delta 四操作/场景格式硬约束/复选框解析）、元数据与配置体系、生命周期语义、CLI 机器契约、坑清单与 manbo 对照 | 官方仓库 docs/ + docs-lab/ 一手精读（2026-10-16） | 2026-10-16 |
| `matt-pocock-skills-guide.md` | Matt Pocock Skills 官方精读：四大失败模式哲学、user/model 两层调用轴、idea→ship 主链与三 on-ramp、GLOSSARY/ADR 共享语言、主链技能硬规则（seam/tracer bullet/双轴评审/door call）、writing-for-agents 写作方法论、官方已知 bug 清单 | 官方仓库 README/SCOPE/AGENTS/GLOSSARY + 3 核心 SKILL.md 精读，其余 30+ 技能 docs 子代理通读（2026-10-16） | 2026-10-16 |
| `openspec-matt-skills-combination.md` | OpenSpec × Matt Skills 结合实践：官方互不集成、社群代表方案（#285 dexhunter：OpenSpec 权威计划层＋grill 前置澄清＋不养双真源）、正交性分析、三种结合模式、五项冲突面裁决、manbo 落地示例 | Discussion #285 一手 + 两篇精读文档分析（2026-10-16） | 2026-10-16 |
| `agent-orchestrator-planner-patterns.md` | AI 编码代理「主会话=规划者」编排模式：规划者四职责框架、六家官方一手对比（Anthropic/Codex/Copilot/Cursor/Cognition/Google）、多代理 vs 单线程分歧裁决（读写分离条款）、社区专家配方四家（Harper Reed/IndyDevDan/Ralph/Matt Pocock）、反模式八条、本机体系覆盖度与五条增量 | 六家官方文档/工程博客 + 社区作者一手文章（2026-10-17 两轮并行子代理调研） | 2026-10-17 |
| `harmonyos-image-moire.md` | 图像抗摩尔纹（anti-moiré / descreen）：三类摩尔纹的区分与判据、「缩放比例决定条纹」核心机制、空间域/频域/选择性掩膜/AI 四类方案盘点（含「AI 无端侧生态」判定）、HarmonyOS 三通道可行性与工程配方 | manbo-reader 调研 + GitHub 实访 + 本机 SDK 实查（2026-10-16 二次核验 + 三次跨模型复核） | 2026-10-16 |
| `opencode-zen-gateway-session-header.md` | opencode Go 网关强制会话头与本地注入代理（含 content-encoding 透传、DeepSeek thinking 回传两个后续坑、Go 档模型协议面速查） | 实测（ZCode + verify_ui 端到端） | 2026-10-16（10-18 增补） |
| `deveco-codegenie-mcp-guard.md` | deveco-codegenie MCP 的 tools/list 并发丢包缺陷：根因、可复用排查手法、透明 guard 代理全文与并发验收 | manbo-reader 会话实测（8/12 并发对照） | 2026-10-18 |
| `everos-selfhost-operations.md` | EverOS 1.4.2 自托管运维：进程管理（start-only／SIGTERM 挂起需 -9）、配置热加载边界、写路径 v2 契约实测、MCP 通道坑、检索方法矩阵与软依赖设计、官方模型实践（decider 静默 404 坑）、隐私上云阶梯、本地 Ollama vs 全上云性能账与卡死诊断配方、迁移原因（Memorix 中文检索失效公平复测 6/6 零命中） | 实测（本机 M4/16GB 全链计时）＋ everos 1.4.2 包源码明文 | 2026-10-19 |
| `opencode-config-sync-gotchas.md` | opencode 1.18 接入同步链：技能零管道（原生读 ~/.agents/skills）、agents tools 数组非法＝配置校验整体报错、MCP 本地格式转换、全局 AGENTS.md 路径、git track／apm deny CWD 两坑 | 实测（opencode 1.18.15）＋官方文档明文 | 2026-10-19 |
| `openspec-agents-ecosystem-survey.md` | OpenSpec 增强与并行代理生态三线调研：openspec-plus 抄机制清单（不整体安装）、并行编排器共识（读写分离印证）与 4 个可借鉴机制（tasks.md 三路合并/冲突分波/Track 分区/热点串行）、openspec-agents 深读与 ZCode 安装使用配方（本机已装 0.149.1：门禁机制、clarify HARD-GATE、MCP 冒烟方法、旧会话不热刷新坑、无人值守与 Java 口味局限） | 两仓库源码/全文直读 + 十仓库 README/关键源文件 + 本机安装实测（2026-10-19） | 2026-10-19 |

## 知识同步约定（防偏移 / 毒化 / 遗漏）

1. **单一真源（防偏移）**：可跨项目复用的结论以本目录为准；项目侧只留**指针 + 项目特化细节**，不复制全文。发现两处措辞不一致时，以本目录（最近一次经一手复核的版本）为准，并回改项目侧。
2. **同步即复核（防毒化）**：入仓前必须回到一手来源核对（官方文档原文 / 实测输出 / 官方工具源码），文头注明适用前提与复核时间；二手转述与未证实内容一律显式标注「存疑」，并写明试过哪些检索。
3. **清单化（防遗漏）**：本表为 `docs/` 全量索引，新增 / 删除 / 改名文档必须同 PR 更新；每条注明来源与入库日期。
4. **落地流程**：`<type>/<描述>` 功能分支 + PR（不直推 main）；纯文档变更。条款与仓库 `AGENTS.md`「记忆」节第 3 条（跨项目知识入库）配套。

## 与其它记忆层的关系

- **EverOS（自托管 127.0.0.1:8000）**：跨会话/跨项目记忆**唯一写入通道**（everos-memory MCP；运维与契约配方见 `everos-selfhost-operations.md`）；
- **各项目 `docs/`**：项目特化深度调研（带 `file:line` 证据）；
- **本目录**：跨项目通用真源（本文件为索引）。

检索顺序：EverOS → 项目 `docs/` → 本目录 → 自行调研（产物按同样顺序回写各层）。细则见仓库 `AGENTS.md`「记忆（单写 EverOS）」节与各项目 `AGENTS.md`。（Memorix 与 zcode 内置记忆已弃用仅存档，2026-10-19 起。）
