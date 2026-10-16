# OpenSpec / OPSX 官方文档精读（概念 · 权威契约 · 坑）

> **来源**：Fission-AI/OpenSpec 仓库。该仓库**没有 GitHub Wiki**（`OpenSpec.wiki.git` 404），官方知识全量在两处：`docs/`（26 篇，顶部标注 legacy 且部分过时，但内容最全）＋ `docs-lab/`（新文档站 openspec.dev/docs 的源码，2026-10 仍在迁移、部分页面是空壳）。
> **复核**：2026-10-16 克隆 main 通读。核心 6 篇（overview / concepts / workflows / writing-specs / opsx / agent-contract）逐篇精读，其余 18 篇经子代理通读摘要；**spec-driven 权威契约与 `.openspec.yaml` 字段以 docs-lab `reference/` 新版页面为准**（旧版示意模板与新版 schema 实际模板有差异，本文按新版）。存疑处标注。
> **定位**：六命令速览＋按阶段模型分级见 [`ai-coding-workflow-openspec.md`](./ai-coding-workflow-openspec.md) §2；本文是官方全量知识的系统沉淀。

## 1. 心智模型

**五个概念**（overview.md）：

1. **Specs 是真相**：`openspec/specs/<domain>/spec.md` 描述系统**当前**行为，按 domain 组织（`auth/`、`payments/`、`ui/`）。
2. **Change 是工作单元**：`openspec/changes/<name>/` 一个文件夹装下一个特性的全部（proposal、design、tasks、delta specs）。一 change 一意图。
3. **Delta 只描述变化**：不重写整份 spec，只写 `ADDED` / `MODIFIED` / `REMOVED`（新版还有 `RENAMED`）——这是 OpenSpec 适配存量代码库（brownfield）的关键。
4. **Artifacts 依存构建**：`proposal(why) → specs(what) → design(how) → tasks(steps) → implement`，DAG 依赖。
5. **Archive 回折真相**：delta 合入主 specs，change 移入 `changes/archive/YYYY-MM-DD-<name>/`。

**四原则**：fluid not rigid（无阶段门）／iterative not waterfall／easy not complex／brownfield-first。
**「Enablers, not gates」**：依赖表示「什么成为可能」，不强制顺序；实现中发现 design 错了就直接改 design.md 继续。

## 2. 双 profile 与 12 workflow

- **core（默认）6 个**：`propose`（一步建 change＋全部规划产物）、`explore`、`apply`、`update`、`sync`、`archive`。
- **expanded 6 个**（`openspec config profile` 启用后逐项目 `openspec update`）：`new`（只建空脚手架）、`continue`（按依赖图建下一个产物）、`ff`（一次建齐全部规划产物）、`verify`、`bulk-archive`、`onboard`（11 阶段实战教学，15-30 分钟）。
- **Delivery 维度**：装 skills / commands / both（默认），`openspec config set delivery skills`；profile 名只描述 workflow 集合，与 delivery 无关。
- **拼写因工具而异**：`/opsx:<id>`（Claude Code、ZCode 等 `commands/opsx/<id>` 目录形态）、`/opsx-<id>`（Cursor 等）、Codex 只认 `$openspec-*`（强制 skills-only，写 `.agents/skills/`）、Kimi=`/skill:openspec-*`、Amazon Q=`@opsx-<id>`。以 `openspec init` 输出的 Getting started 行为准。
- **ff vs continue**：能一句话说清全 scope 用 ff；边做边想用 continue。
- 本机对照：已装 8 个 skill＝core 6 ＋ expanded 的 verify-change、bulk-archive-change（skills-only 形态，故调用名是 `/openspec-verify-change` 这类，无 `/opsx:` 冒号形式）。

## 3. spec-driven 权威契约（★ 最有价值一节）

来源：docs-lab `reference/schemas/spec-driven/index.md`（= 仓库 `schemas/spec-driven/schema.yaml` 全文，agent 实际收到的 instruction）。

### 3.1 proposal.md

模板四节：`## Why`（1-2 句动机）／`## What Changes`（bullet，breaking 标 **BREAKING**）／`## Capabilities`（New + Modified 各一列）／`## Impact`。

- **Capability 命名规则**：按**持久的系统能力**命名（`user-auth`），不按本 change 的工作命名（`add-login-endpoint`）；kebab-case；避免大杂烩名；修改用已存在的精确路径，复用而非造近义名。
- 动笔前先 `openspec list --specs` 盘点能力清单，`openspec show <id> --type spec --json --no-scenarios` 低成本查重（⚠️ 不带 `--specs` 的 `openspec list` 列的是在途 change，**永远不显示已有能力**）。
- **零 delta 校验**：没有 capability 且未声明 `skip_specs: true` → `openspec validate` 拒绝；**不要为了过校验编造 requirement**。

### 3.2 Delta spec（`specs/<capability-path>/spec.md`，一能力一文件）

四种 delta 操作（**旧版文档只写三种，`RENAMED` 是 schema.yaml 里的第四种**，`FROM:`/`TO:` 格式）：

| 操作 | 语义 | 硬规则 |
| --- | --- | --- |
| `## ADDED Requirements` | 全新行为 | archive 时追加 |
| `## MODIFIED Requirements` | 改既有行为 | **整块替换**：从主 spec 复制完整 requirement 块再改，必须携带所有存续 scenario，缺一即校验失败、archive 拒绝（最常见的跨 change 冲突坑）；部分内容会在归档时丢细节 |
| `## REMOVED Requirements` | 行为下线 | **必带 `**Reason**` 与 `**Migration**`** |
| `## RENAMED Requirements` | 仅改名 | `FROM:`/`TO:` |

格式硬约束（schema.yaml 原文级）：

- **Scenario 必须恰好 4 个 `#`（`#### Scenario:`）**——3 个 `#` 或用 bullet 会**静默失败**（校验不报错但场景不被识别）。
- Requirement 描述（标题到首个 scenario 之间）**≤500 字符**：超长在 ADDED 与主 spec 被 validate 警告、`--strict` 判失败；MODIFIED 不许为凑长度拆改既有块（要拆需用户明确要求，且拆出的行为各成 ADDED）。
- 新 capability 的 delta 首节是 `## Purpose`（≥50 字符，`--strict` 检查）；archive 会把它作为新主 spec 的 Purpose，缺了留 `TBD` 占位。**既有 capability 的 delta 不要写 Purpose**（会被忽略）。
- 规范关键词用 `SHALL`/`MUST`（避免 should/may）；每条 requirement 至少一个 scenario。
- delta 写在别的文件（如 `specs/user-auth.md` 扁平文件）会被 validate/archive 拒绝——archive 永不合并它们。

### 3.3 design.md（按需跳过）

**只在四个条件之一成立时才写**：跨模块/新架构模式；新外部依赖或重大数据模型变更；安全/性能/迁移复杂度；需要先行技术决策的模糊性。否则 agent 直接跳过它写 tasks。
模板：`Context` / `Goals / Non-Goals` / `Decisions`（含 why-X-over-Y 与备选）/ `Risks / Trade-offs`（[Risk] → Mitigation）／可选 `Migration Plan`、`Open Questions`。
`Open Questions` 的定义边界：**真正可延迟的未知**——若答案会改变 specs/方案/任务拆分，必须现在问用户，不准留到 tasks 阶段。

### 3.4 tasks.md 复选框解析契约（apply 阶段按它跟踪）

- 只有 `- [ ] X.Y 描述` 形式被跟踪；勾选 `[x]` 大小写/空格不限（`- [ x]` 也算完成）；`[~]`/`[-]`/`[]` 一律未完成；**无复选框的行不跟踪**。
- 每个任务**必须在描述里写验证方式**（测试/命令/可观察结果），不单设验证任务（除非跨任务集成验证）。
- **测试与文档落在各自任务组内**，禁止攒到最后一个组——晚组首次踩到早组工作时失败会沿组级联回传。
- 归档等流程步骤放文末 `## Workflow follow-up` 平铺 bullet（不跟踪进度）。
- 恢复语义：`/opsx:apply` 从**第一个未勾任务**续跑；FAQ 明说「计划在文件不在聊天史」——新会话直接 apply，且**实现前清空上下文窗口效果更好**。

## 4. 元数据与配置体系

### 4.1 `.openspec.yaml`（change 级，建 change 时生成）

| 键 | 作用 |
| --- | --- |
| `schema` | 本 change 的工作流 schema（建时写入，**赢过**项目 config 的事后修改） |
| `created` | YYYY-MM-DD |
| `goal` / `affected_areas` | 意图与预期触达范围（新版新增字段） |
| `skip_specs` | 声明无 spec delta（纯重构/工具/文档）；与 specs/ 下有文件共存 = 校验冲突 |
| `retire_capabilities` | 授权 archive 删除被掏空的能力（删的是文件、只能靠 git 找回，所以必须显式） |
| `x-*` | 顶层扩展键（`x-tracker: SB-5497`），OpenSpec 不读写；小写前缀、仅顶层、不能有空格 |

未知键不报错但 `validate --strict` 判失败（x-* 除外）；元数据错误直接中断命令，不像 config.yaml 那样降级。

### 4.2 `openspec/config.yaml`（项目级）

- `schema`（默认 schema）、`context`（注入**所有**产物，**硬上限 50KB**）、`rules`（按 artifact id 注入对应产物）、`operations.apply.guidance` / `operations.archive.guidance`（advisory，与 rules 严格分离）、`githubCopilot.cloudAgent`。
- 注入形态：`<context>` 全产物可见、`<rules>` 仅匹配产物、`<template>` 为 schema 内置模板。
- 🌟 文件名必须是 `config.yaml` **不能 `.yml`**；改动即时生效无需重启。
- store 引用（beta）：`references:`（只读上下文）、`store:`（默认 store，兜底非覆盖，显式 `--store` 永远赢）。

### 4.3 schema 系统与优先级

- **解析优先级**：CLI `--schema` ＞ change `.openspec.yaml` ＞ 项目 `config.yaml` ＞ 默认 `spec-driven`。
- schema 存放优先级：项目 `openspec/schemas/<name>/`（推荐，随代码受控）＞ 用户 `~/.local/share/openspec/schemas/` ＞ 包内置。
- 定制最短路径：`openspec schema fork spec-driven my-workflow`；`schema validate` 查语法/模板存在/循环依赖；`schema which [--all]` 查解析来源。
- schema.yaml 字段：`artifacts[]`（`id`/`generates` 支持 glob/`template`/`instruction`/`requires`）＋ `apply.requires`/`apply.tracks`。`artifacts:` 列表顺序决定同时 ready 时谁先（非字母序）。
- 社区 schema（独立仓库，复制进项目用）：intent-driven、superpowers-bridge、nanopm、e2e-runbooks、anvil（含对抗式 review 的 VERDICT 门禁）、ml-research。

## 5. 生命周期语义（sync / verify / archive）

- **sync 可选**：把 delta 合入主 specs 但 change 保持 active；archive 会提示补做，多数人不用手跑。场景：并行 change 要建立在未归档 change 的新能力上。
- **verify（expanded）三维校验**：Completeness（任务全勾/requirement 有码/场景有测）、Correctness（实现符合 spec 意图）、Coherence（design 决策反映在代码结构）；分级 CRITICAL/WARNING/SUGGESTION；**不阻塞 archive——把关责任在人**。
- **archive 在无人环境的雷区**：agent 工具调用/CI/stdin 关闭时，无 `--yes` 则**不动任何文件、exit 1**；重跑必须带齐原 flag（`--skip-specs`/`--no-validate`），裸 `--yes` 不等价。
- **capability 退役**：REMOVED 掏空某能力最后一条 requirement 时，须 change 声明 `retire_capabilities: true` 才删其主 spec；spec 还有 Purpose 之外的自定义内容（如 `## Notes`）会拒绝退役并点名行号。
- 归档输入安全（行为契约）：delta 来源仅取 `openspec status --json` 的 `artifactPaths.specs.existingOutputPaths`；合并前必须消费 `openspec instructions specs --json` 快照；非零/无效 JSON = 查询失败，**写 spec 前停下**。
- `validate --archived` 独立作用域：校验 archive 下每个 change 的 tasks 复选框全勾（可挂 pre-commit）。

## 6. Update vs New 判定（改提案还是开新 change）

三个测试（workflows/opsx 篇）：**Identity** 同一工作的细化？／**Scope 重叠 >50%**？／**原 change 能否独立收尾**？→ 是则 Update，否则 New。原则：**「Update preserves context. New change provides clarity.」** 类比 git 分支。
`/opsx:update` 的边界：只改规划产物**从不改代码**；双向对账（design 改动可回波 proposal）；逐产物先确认再写；不新建无文件的 artifact（那是 continue 的事）。
explore 的行为边界：**永不写代码**；不主动建 change——仅当你要求或接受提议时写你同意的内容。技巧：带问题不带方案（"logins feel slow" 优于 "add a Redis cache"）；探索发现不值得做也是赢。

## 7. CLI 机器契约要点（agent-contract.md，自称经 src/ capstone audit 核对）

- `--json` 模式：stdout 恰好一个 JSON 文档（2 空格缩进），人话/转圈全走 stderr；失败也打 JSON（命令的 null-shape + `status: [diagnostic]`）。
- 诊断 envelope 统一：`{severity, code, message, target?, fix?}`；退出码仅 0/1（prompt 取消 130）。
- 键名大小写分家族：store 系 snake_case、workflow 系 camelCase，`root.store_id` 恒 snake_case（已知不一致，官方记录在案）。
- root 选择优先级：`--store` ＞ 最近祖先 `openspec/` ＞ 全局 `defaultStore` ＞ 报错/隐式。store 感知路径优先用返回的 `planningHome.root`，不要自己推 repo 相对路径。
- `update` 的 drift 语义：**生成文件归 OpenSpec 所有**——skills 按版本戳、commands 按内容 diff 判定，手改会被覆盖（skills 版本匹配则不动，`--force` 强刷）；自己的说明写别处，扩展位用 `x-*`。
- 🌟 **升级两步制**：先 `npm install -g @fission-ai/openspec@latest` 再逐项目 `openspec update`——旧 CLI 跑 update 会**假报最新**且不带新工作流。
- Node ≥ 20.19.0；无 `openspec uninstall`（手删全局包＋各工具目录 skills/commands＋AGENTS.md marker 块）；`init --tools <ids>` 会**不问即删** legacy 遗留。
- beta 三件（命令名/flag/JSON 可能变）：**stores**（独立规划仓，OpenSpec 从不自动 clone/pull/push）、**worksets**（`openspec workset create/open` 生成 `.code-workspace` 一窗开 store+repo，让 agent 看全图；`--tool claude/codex` 暂时禁用）、working context。
- 遥测默认开（仅命令名+版本），`OPENSPEC_TELEMETRY=0` / `DO_NOT_TRACK=1` / CI 自动关。

## 8. 多语言与存量项目

- **多语言硬约束**：结构标题（`## ADDED Requirements` 等）与 `SHALL`/`MUST` 关键词**保持英文**——校验依赖它们；requirement/scenario 正文可用目标语言（官方提供含简体中文的六语言 `context:` 片段）。新项目 `openspec init --language`；已有项目**直接编辑 `context` 字段**（`--language` 不会覆盖已有 config）。
- **brownfield-first 工作法**：不为整个存量库补文档，只为即将改动的部分写 spec；specs 一次一 change 生长；**忍住回填全部 spec 的冲动**（无现实约束会陈旧）。已有 PRD/SRS 当作 explore 的**素材**而非待转换物，明确反对一次性整体导入。
- Monorepo：仓库根一个 `openspec/`，domain 映射包/服务；真跨多仓库才上 beta stores。
- 大代码库务必填 `config.yaml` 的 `context:`。

## 9. 坑清单（跨篇汇总）

1. `openspec ...` 只在终端、`/opsx:...` 只在 AI 聊天框——没有「交互模式」可启动（最常见的首个困惑）。
2. `#### Scenario:` 少一个 `#` 静默失败（§3.2）。
3. MODIFIED 丢 scenario → 校验错误 `omits scenario(s) the current spec still has`——修法是回主 spec 把场景拷回 delta。
4. 零 delta 忘写 `skip_specs: true` → validate 拒绝。
5. CI/archive 无 `--yes` → 不动文件 exit 1；重跑带齐原 flag。
6. 旧 CLI 跑 `update` 假报最新。
7. `config.yaml` 写成 `.yml` 静默不生效；`context:` 超 50KB 报错。
8. `rules:` 键必须匹配 schema artifact id，否则 "Unknown artifact ID in rules"。
9. `openspec init` 在**运行目录**建 `openspec/`——monorepo 子包误跑会建错位置。
10. change 名必须小写 kebab-case（数字开头可）；skills-only 工具 `/opsx` 永不自动补全属正常。
11. 生成文件手改会被 `update` 覆盖（§7 drift 语义）。

## 10. 与本机体系对照（manbo-reader）

- 目录结构一致：`openspec/changes/<name>/` ＋ `changes/archive/YYYY-MM-DD-<name>/`（manbo 的批量归档目录 `archive/2026-10-16-*` 即官方形态）。
- 本机 8 技能＝core 6 ＋ expanded 2（verify/bulk-archive），skills-only 形态。
- **模型选择两说并存**：官方 FAQ 只建议「规划与实现都用高推理档」，未给分级策略；「按阶段分级选模型」是博客作者的实践优化（见 ai-coding-workflow-openspec.md §2.2），两者不冲突——分级是在官方建议之上的成本裁剪。
- manbo 实践差异点：归档用 `/openspec-archive-change` 技能而非 `/opsx:archive`；中文正文＋英文结构标题正好符合官方多语言约束。

## 11. 参考链接

- 仓库：<https://github.com/Fission-AI/OpenSpec>（docs/ 与 docs-lab/ 即本文来源）
- 新文档站：<https://openspec.dev/docs>
- 本文未逐条收录：`cli.md`（48KB 全量 flag 参考，用时直查）、`supported-tools.md`（40 工具接线明细）、`migration-guide.md`（legacy→OPSX 一次性迁移）、`examples.md`（7 个配方）
