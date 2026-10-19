# OpenSpec 增强与并行代理生态调研（openspec-plus / 并行编排器 / openspec-agents）

> 适用前提：OpenSpec `@fission-ai/openspec` 1.14.2（spec-driven schema）；调研时间 2026-10-19。
> 复核等级：ifrankwang/openspec-agents 与 sudokar/openspec-plus 为源码/全文直读（高）；并行生态多数项目为 README + 关键源文件级（中，各项目自述指标未复跑）；本机安装与 MCP 冒烟为实测（高）。
> 结论有效期：社区项目（<50★ 居多）变化快，引用前建议回仓库确认活跃度。

## 0. 三条路线一句话定位

| 路线 | 代表 | 形态 | 一句话 |
| --- | --- | --- | --- |
| prompt 层增强 | sudokar/openspec-plus（214★） | 官方 skill 的包裹 skill | 把纪律写进提示词，无引擎无强制 |
| 外挂并行编排器 | gitguardex / interlock / conflux / opsx-turbo | 独立 CLI / workflow 脚本 | 调度多代理并行推进 change，进度依附单次运行 |
| **代码引擎编排插件** | **ifrankwang/openspec-agents（4★，本机已装）** | 插件（MCP server + 状态机 + 门禁） | 门禁由代码承载，状态落仓库，跨会话跨工具续跑 |

**共同背景共识**（三线 + 官方文档交叉印证）：spec 语义归 OpenSpec 官方 CLI，所有第三方都组合而非 fork CLI；编排层各拿各的。

## 1. sudokar/openspec-plus：抄机制，不整体安装

v1.6.1（MIT），2026-06 建，**2026-09-03 起停更，单人维护（bus factor 1）**，15 个 issue 里 13 个是作者自己的 PR，唯一外部采纳者公开弃用转回纯官方 + config.yaml 引导。约 4000 行纪律密度拉满：每阶段强制问答门禁 + 每片 2 个评审代理 + 1 个终审，一键 propose 会被拆成逐产物多轮问答。

**值得单独移植的机制**（按性价比）：
1. 4 个评审 prompt（implementer / spec-compliance / code-quality / final）+ 每片修复上限 3 次 + 「prompt 逐字转发、只替换占位符」派工契约
2. TDD 逐测试状态机：RED→VERIFY-RED→GREEN→VERIFY-GREEN→REFACTOR（必评），附 WRONG/RIGHT 反例批写
3. tasks 垂直切片纪律：每片一个可验证结果、WHAT not HOW、禁按层分组
4. 产物保真三件套：写前问答→模板映射 + 密度检查 + Session Context Fidelity Check（编码了「从上下文写产物结构性丢信息」这一真实失败模式）
5. spec-compliance 5 分类问题模型 +「不信任实现者报告、逐项枚举核对」

兼容性硬事实：对官方 CLI 硬依赖（Phase 0 全走 `openspec instructions --json`）；config.yaml 挂钩经 CLI 1.14.2 的 `context`/`rules` 透传有效（源码验证）；默认每周联网自检偏侵入（`autoUpdateCheck:false` 可关）。

## 2. 并行代理生态：共识印证读写分离，4 个可借鉴机制

调查对象：claude-plugin-sdd(32★) / gitguardex(28★) / conflux(27★) / interlock(23★) / opsx-turbo / openspec-human-agent-orchestration / openspec-flow / Parallel-OpenSpec-Development / jjay / openspec-batch-parallel-apply(空仓)。

**社区共识**（与全局规则「读写分离、单一写者收口」完全一致）：
- 隔离单元 = change/track/lane，一单元一 worktree（或 jj workspace）
- 只读任务全并行；共享文件、基建接线、最终集成必须串行
- 收口一律单一整合者 + PR-only；**无人采用 last-writer-wins**，冲突是 halt 或具名报错

**可借鉴机制**（按含金量）：
1. **tasks.md 三路合并器**（gitguardex `scripts/agent-reconcile-openspec-tasks.js`）：只合并 `- [ ]` 复选框并集，行数/非清单文本不一致直接拒绝——解决双代理各勾各的 tasks.md 的收口缺口
2. **按预测文件冲突分波次**（interlock `lib/waves.mjs`）：派工前为每任务预测 `paths`，共享路径任务并成同 lane 串行（连通分量）；「上限即代码」（`lib/limits.mjs` + CLI 退出码 + PreToolUse hook），不靠提示词自觉
3. **tasks.md 内 Track 分区**（opsx-turbo）：`## N. Track: <name> (depends: ...)`，apply 按真实文件耦合修正、共享文件进串行 integration track；「全绿 + 无失败 track + 账本清空」才许报成功
4. **派工前兄弟 PR 清单 + 热点串行化**（claude-plugin-sdd）：列出在途修改文件与 PR；近 50 次 PR 中 >50% 触及的文件禁并行

明确不必看：openspec-batch-parallel-apply（空仓）、openspec-flow（停更 alpha）、FRZRichard（2 commits 仅目录隔离）。

## 3. ifrankwang/openspec-agents：本机已装（v0.149.1）

### 3.1 定位与架构

三件套：①自定义 schema `spec-driven-standard`（比官方多 **clarify** 阶段）装进项目 `openspec/`；②TS 编排引擎（状态机 + 门禁，src ~9500 行，tests 63 文件 ~1164 用例，FakeGitRunner 零外部依赖）；③6 个 `opx_*` 工具（MCP stdio / DSH 原生双形态）。**不 shell 调用官方 CLI**，只读 `openspec/changes/<id>/` 并从 tasks.md 解析任务组；官方 CLI 继续管 propose/archive。

流程链：`/orchestrator {change-id}` → `orch_init`（建 `change/<id>` 分支 + `.worktree/<id>/ws`）→ analyze(架构师兜底) → implement(developer) → verify_tool → verify_task → verify_quality(5 维并行) → verify_cleanup → 收口（合回基准 + 销毁 worktree）。simple 模式 = implement → 单审查者 → 收口（**默认**）。进度存 `openspec/states/<id>.json`，跨会话/跨天/跨 harness（Claude Code/Codex/ZCode/OpenCode/DSH 五家）可续跑。

### 3.2 门禁（代码强制，均有源码与测试对应）

- **worktree gate**：无 worktree 路径时 `agent_submit` 直接拒（submit.ts:614-621）
- **must-do gate**：skill frontmatter 声明机器可读必做清单，验证步骤逐项覆盖或带结构化 `skip_reason`
- **tool-review checkpoint**：记录通过时 HEAD，下轮增量检测——纯文档直提、含代码走全量
- **收口门禁**：worktree 干净 + issue 全终态 + blocker 全解决才许合并；基准漂移无害判定（仅文档/版本号直合，实害回退重验）
- **exemptions.json**：豁免结论带 rule+file+line 键跨 change 沉淀，命中降 Info
- **谁提谁裁定** + 修复≥2 轮强制 5-Why；压制注解/关规则一律视为豁免申请

### 3.3 clarify 提案门禁

决策树逐轮访谈（每题带推荐答案；事实类自己查代码）→ 结构化 7 要素方案摘要 → **HARD-GATE：必须普通消息文字确认，点选项不算** → 独立复核子代理 `openspec validate --strict` 循环 ≤3 轮。增量：关联场景清点（共享逻辑所有入口同 change 适配）、规则边界推演（拦截侧+合法反例+判定挂载点）、契约变更逐条详列、tasks 禁收尾组。

### 3.4 ZCode 安装与验证（本机实测 2026-10-19）

- 插件页加市场 `ifrankwang/zcode-plugins` → 装 `openspec-agents` → 完全重启
- ZCode 形态载荷：23 skill（入口 `openspec-standard`/`orchestrator` + 10 通用 + 11 Java）、2 子代理（developer/reviewer）、MCP server（`.mcp-server/cli.mjs` 自包含 1.1MB）。**不含** openspec-propose/apply 工作流 skill——与官方 8 skill、`opsx:*` 命令零重名冲突
- 冒烟配方：`printf '{"jsonrpc":"2.0","id":1,"method":"initialize",...}' | node cli.mjs --transport stdio --worktree /tmp --unattended --strip-opx-prefix`，`tools/list` 应返回 6 工具（orch_init/orch_set_worktree/status/orch_complete_task_group/orch_set_unattended/agent_submit），会话内呈 `mcp__opx__*`
- 🌟 **旧会话不热刷新**：安装先于会话启动时，MCP 工具与 skill 快照不可见，须新会话（同 everos-mcp 案例）

### 3.5 使用要点

- 每项目一次：功能分支上 `/openspec-standard`（写 config.yaml + schemas/，合并幂等；回退=还原 schema 行）；`.gitignore` 加 `.worktree/` 与 `openspec/states/`
- 日常：`/opsx:propose {需求}`（官方流程，产物自动变严）→ `/orchestrator {change-id}`（只给 change 名 = simple 串行全任务组；full 或指定任务组须明说）
- 续跑：新会话说「继续编排 {change-id}」或查 `mcp__opx__status`
- 独立审查（不绑 change）：`review_scope` 四要素——`scope_type`(pr=**本地**分支区间 origin/* 拒收 / full)、`base_ref`/`head_ref`、`granularity`(simple/thorough)、`fix`(none/fix)；无人值守缺省 `none+simple`
- 中途放弃：删 `.worktree/<id>/` 与 `change/<id>` 分支即可，主干零残留

### 3.6 局限与本机注意

- **默认无人值守**（ZCode 子代理提问能力 Beta）：需人拍板处自行决断，审查门禁照常；`orch_set_unattended` 可关
- **Java/DDD 默认口味**：11 个 Java skill 非 Java 项目空转；通用 10 份照常作判据；非 Java 项目的确定性质量门靠项目自有检查命令补，审查薄一档
- 流程重：full 模式 6 站 + 5 维并行审查，token 显著偏高（README 自认比单 AI 慢）；单人维护（但 149 次迭代、发布纪律严格、2026-10-16 仍活跃）
- 与自制多代理配方同仓库**勿混用**：编排期间工作副本纪律归插件，自己的 worktree/委派配方留给非 OpenSpec 任务

## 4. 裁决记录（2026-10-19）

- openspec-plus：不装，机制清单供移植（§1）
- 并行生态：不引入外挂编排器，4 机制按需借用（§2）
- openspec-agents：**已安装 ZCode 插件（0.149.1）**；首跑选低风险小项目 simple 模式试水，manbo-reader 因 12 个在途 change + 鸿蒙工作流暂缓
