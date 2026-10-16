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

另有 `opencode-zen-gateway-session-header.md`（opencode Go 会话头与本地注入代理）在 PR #5 中待合并，合入时补入本表。

## 知识同步约定（防偏移 / 毒化 / 遗漏）

1. **单一真源（防偏移）**：可跨项目复用的结论以本目录为准；项目侧只留**指针 + 项目特化细节**，不复制全文。发现两处措辞不一致时，以本目录（最近一次经一手复核的版本）为准，并回改项目侧。
2. **同步即复核（防毒化）**：入仓前必须回到一手来源核对（官方文档原文 / 实测输出 / 官方工具源码），文头注明适用前提与复核时间；二手转述与未证实内容一律显式标注「存疑」，并写明试过哪些检索。
3. **清单化（防遗漏）**：本表为 `docs/` 全量索引，新增 / 删除 / 改名文档必须同 PR 更新；每条注明来源与入库日期。
4. **落地流程**：`<type>/<描述>` 功能分支 + PR（不直推 main）；纯文档变更。条款与仓库 `AGENTS.md`「记忆（双库同步）」第 3 条配套。

## 与其它记忆层的关系

- **Memorix MCP**：本机跨会话语义检索层（坑点 / 决策 / 配方，项目作用域）；
- **各项目 `docs/`**：项目特化深度调研（带 `file:line` 证据）；
- **本目录**：跨项目通用真源（本文件为索引）。

检索顺序：Memorix → 项目 `docs/` → 本目录 → 自行调研（产物按同样顺序回写各层）。细则见仓库 `AGENTS.md` 与各项目 `AGENTS.md`。
