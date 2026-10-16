# AGENTS.md / Skills 工具生态：现成工具、成熟度与最小工作流

> 适用前提：先问「有没有现成工具/技能帮我维护 AGENTS.md 与 Skills」时读这篇——**回答是：有，但成熟度两极分化**。
> 配套：写作实践（机制对照 / 长度红线 / 量化证据）见本目录 `agents-md-best-practices.md`；本文只讲工具生态与选型，不重复写作原则。
> 证据：star / `pushed_at` / license 均为 2026-10-16 `gh api` 实测；npm 下载量为 last-month；论文与仓库路径抽验记录见文末 §6。

## 0. 一句话结论

**检查器与同步器已工程化，优化器全是个人玩具，eval 类有三套可用重武器但没有全家桶**；并且没有任何工具能替代「失败驱动的人工修剪」——实证（§3）显示自动优化经常在 holdout 上回退、按「被忽略」批量删可能删掉有用指令。

## 1. AGENTS.md 侧

### 1.1 同步 / 分发 —— 唯一真正成熟的类别（值得立刻评估）

| 工具 | 能力 | 实测活跃度 | 备注 |
| --- | --- | --- | --- |
| `dyoshikawa/rulesync` | 统一真源生成各 agent 配置（rules / commands / MCP / ignore / subagents / **skills**），可反向 `import`，附 `fetch` 拉官方 skills | 1520★，当日仍在提交，npm **122 万下载/月** | **唯一同时产出 AGENTS.md 与 skills、且支持 `zcode-plugin` 打包目标**的工具；生态事实标准 |
| `intellectronica/ruler` | 一套 rules 分发到 Claude / Copilot / Cursor / Aider 等，支持嵌套加载 | 2945★，31.8 万/月 | README 自标 "Beta Research Preview"；skills 支持弱于 rulesync |

其余同类（claude-agentsmd 18★、cortesi/agentsmd 9★、ai-agent-sync 0★ 等）均为小项目或玩具。**本体系现状用软链 + `@AGENTS.md` 指针已够**，除非要同时维护 ≥3 个工具再上 rulesync。

### 1.2 linter / 校验器 —— 数量爆炸、无权威

已核实 ≥20 个（GitHub + npm + Marketplace），**最高 star 仅 60**（`driftlint`，2026-10-13）；月下载量最高的 `@yawlabs/ctxlint` 也只有 11★（53,616 下载/月，倒挂疑为 MCP/CI 自动化）。**选择标准 = 是否有 CI 形态 + 是否仍在推**，而非名字相似度。代表：
- `driftlint` — 找「代码已不支持」的声明（本类最高 star）;
- `@yawlabs/ctxlint` — 对照真实代码库查坏路径/坏命令/矛盾/重复，含 `--fix`、CLI/CI/pre-commit/MCP 四形态；
- `vigiles` — 15★，`lint` 作确定性 CI 门禁，`audit` 跑脚本化模型测「规则是否真的触发」（最接近可用的 eval 形态）。

### 1.3 生成器

`buildermethods/agent-os`（5508★，从代码库提取 conventions 成 standards 并按任务注入）；`agent0ai/dox`（1486★，「自文档化层级 AGENTS.md」框架，与三层体系直接相关）；各 CLI 内建 `/init` 是事实默认生成器。**注意**：arXiv 已证「仓库综述型内容无帮助」，生成器产出的文档必须人工裁剪。

### 1.4 优化 / 压缩器 —— 🌟 没有成熟工具

全部 ≤26★ 的 Claude Code skill 单品，且半数停止更新：`wrsmith108/claude-md-optimizer`（26★，无 license，4 个月未更）、`please-optimize-my-claude`（16★）、`claude-docu-optimizer`（15★）、`agents-md-optimizer`（3★）。⚠️ 18k★ 的 `microsoft/SkillOpt` 对象是 **skills** 不是 AGENTS.md（见 §2.2）。

### 1.5 eval / 遵循度测量 —— 专用工具的唯一实例已归档

`vltansky/agents-md-evals`（4★，**archived**）。可用替代 = 通用 eval 基建自建：`promptfoo`（26025★）+ `vigiles audit`；方法论侧（tessl/stet 的 baseline→change→rerun 闸门）见配套文档。

### 1.6 CI 集成

GitHub Marketplace 检索 "agents.md" 共 **23 个 Action**（个体 0–90★，最大 `agents-shipgate` 90★），pre-commit 生态有 8 个 hook 仓库——**目录成形、无官方背书**，选择同 §1.2 标准。

## 2. Skills 侧（SKILL.md）

### 2.1 🌟 本机已有能力的天花板（实测，2026-10-16）

| 组件 | 实测能力 |
| --- | --- |
| ZCode `skill-creator` 0.1.0 | 目录**只有 SKILL.md**（方法论 loop：写草稿 → **2–3 条 test prompt 手跑** → 改进；原文承认「ZCode 不能并行开评测子代理」）→ **无批量 eval、无评分脚本、无 lint** |
| ZCode `plugin-creator` 0.1.1 | `validate-plugin.mjs` 只校 plugin 清单/路径/占位符，不评 skill 内容质量 |
| `npx skills`（vercel-labs/skills，35127★） | 子命令 add/use/remove/list/find/update/init/sync——**无 lint / validate / score** |

**行动计划：不必去 GitHub 找新东西，先把上游 `anthropics/skills` 的 `skills/skill-creator` 补齐**（已核实其目录）：
- `scripts/`：`quick_validate.py`（静态校验）、`improve_description.py`（**专治触发率**）、`run_eval.py`、`run_loop.py`、`aggregate_benchmark.py`、`generate_report.py`、`package_skill.py`
- `agents/`：grader / comparator / analyzer 子代理；`eval-viewer/` 结果查看器；`references/schemas.md`
- 官方方法论文档另见 agentskills.io 的「Optimizing skill descriptions」「Evaluating skill output quality」（`evals/evals.json` + with/without 配对 + `benchmark.json` delta/stddev + blind comparison）。

### 2.2 能进生产的三套重武器

| 工具 | 定位 | 实测 |
| --- | --- | --- |
| `microsoft/SkillOpt` | **真·优化器**：把 skill 当可训练参数，optimizer 生成有界 add/delete/replace 编辑，**validation-gated 接受**（held-out 分数严格提升才留），产物 300–2000 token `best_skill.md` | 18460★，MIT，PyPI，arXiv 2605.23904（README 自述 +23.5 分等未独立复现） |
| `NVIDIA/SkillEvaluator` | **真·三层 eval**：Tier1 校验 / Tier2 语义去重（embeddings）/ Tier3 with-without 实跑 + **Skill Lift**（Docker 沙箱） | 571★，Apache-2.0，官方文档站 + arXiv 2608.20614；完整跑需 provider + Docker |
| 上游 `anthropics/skills` 的 skill-creator | 官方唯一「创建 + 校验 + 描述优化 + eval + 打包」全链 | 随官方仓库更新；本机版是裁剪 fork（§2.1） |

### 2.3 方法论形态（可装的技能）

`alchaincyf/darwin-skill`（6358★，中文为主）：9 维 rubric（含失败模式编码、明文禁「建议/可以考虑/视情况而定」、高风险行动黑名单）、多评委+早停、三层 human checkpoint，已被 SkillOpt 列入集成名单；`obra/superpowers` 的 `skills/writing-skills`（299950★ 主项目内）：TDD 式技能开发——「没看过代理在没有 skill 时怎么失败，就不知道 skill 教得对不对」；`hqhq1025/skill-optimizer`（183★）：挖历史工作流 → 个性化 → 可发布三段。

### 2.4 linter 层与安全（质量 vs 安全是两件事）

- 质量 linter 全是个人作品：`google/skills_lint.dart`（6★，最正规但有 "not an officially supported Google product" 声明）、`William-Yeh/agent-skill-linter`（12★，含 publishing readiness）、`himself65/skill-lint`（15★）、`rajesh-gsn/skill-lint`（15★，浏览器版）、`skillsmith`（0★）等——**只查格式，查不了「触发得准不准、任务表现有没有提升」**。
- 官方标准侧仅 `skills-ref validate`（agentskills/agentskills 内置），README 自述「**不应用于生产**」→ 「官方质检」不存在，只有 spec（spec 硬约束可直接当 lint 规则表：name 必须等于父目录名、description 1–1024 字符、body 建议 <500 行等）。
- **安全侧有厂商级方案**（装前必扫）：`NVIDIA/SkillSpector`（20310★，Apache-2.0）、`snyk/agent-scan`（3139★）。市场不安全是实证的：RankClaw 全量扫 14,704 个 skill，表面启发式判恶 6.6% vs AI 深审 16.4%（**漏 60%**）。

### 2.5 分发与市场

`npx skills` 是事实标准（35k★，NVIDIA 官方也用它安装）；目录站 `skills.sh`（有 Security audits 栏目但无质量评分）；`tech-leads-club/agent-skills`（7061★，唯一把「验证后分发」当卖点）；`iflytek/skillhub`（5223★，企业自托管注册中心）；`ComfyHQ/awesome-claude-skills` 等清单流量大（77k★）但**无质量门禁**。

## 3. 社群评价与失败案例（决定「要不要用」）

1. **自动优化会被 holdout 打回（独立复现）**：一位用户对自家 CLAUDE.md 跑 8 轮 Codex「自优化」——训练片上涨，在干净 10 任务 holdout 上回退（footprint 变宽、token 涨、code-review 正确率降，**而测试全绿**）。这是对 stet 失败模式的独立复现，不是同一事件重述。
2. **理论界给出了「最优文件大小」结论**（arXiv 2610.11007，已核摘要）：存在与候选数无关的最优文件大小上界；「全部追加」可任意劣于选子集；**「删掉 agent 忽略的指令」必然可能删掉有用的**；反馈本质是删失的（缺失指令只有在造成损害时才产生反馈）→ 支持「按真实失败增删」，反对「按忽略批量删」。（论文自报的 10/40 条最优规模**未复核**）
3. **收益流向弱模型**（pre-registered 实验，DOI 10.1145/3843282.3844425）：弱执行器读强模型写的 context +26pp 定位率，读自己写的 +0.0pp；广随机样本上任何 context 都不提升 → 「写文件让强模型更强」论据不足。
4. **73.8% 的 AI 配置产物提交一次后永不修改**（ASE 2026，441 仓库观测）→ 维护类工具的市场前提本身是弱的；别指望工具替你保鲜。
5. **技能包规模本身即负收益**："140+ skills made my agents worse at triggering"；装上≠变好，先测触发率再扩库。

## 4. 最小工作流（本体系可直接用）

1. **不上同步器**：现有 软链 + `@AGENTS.md` 指针已够（本机 `~/.claude/AGENTS.md` → `~/.zcode/AGENTS.md` 软链实测可用）；要维护 ≥3 个工具时才评估 rulesync。
2. **提交前只报错、不改写**：`agnix`（`agent-sh/agnix`，452★，455 规则 / CI / 15 贡献者——检查器类唯一「工程化」样本）或 `driftlint`；**不要用 `--fix` 自动改写**（§3.1 教训）。
3. **硬约束下沉 fail-closed 钩子/CI**：规则没有 pass+fail fixture 就不加载（determinstic > 文本指令）。
4. **人工失败驱动修剪**：只在 agent 真实失败后增/删——不要按「被忽略」批量删（§3.2 已证明会删掉有用的）。
5. **有预算才做 eval**：改前改后回放历史 PR，必须看 holdout。skill 侧用上游 skill-creator 脚本；AGENTS.md 侧用 promptfoo 自建或 vigiles audit。
6. **本机待办**：① 把上游 skill-creator 的 `scripts/` 与 `agents/` 补进本机插件副本（或直接以 skills 形态装上游 full 版）；② 用 SkillSpector / snyk agent-scan 对现有技能库做一次装前安全扫描。

## 5. 存疑与未找到

- **optimizer 零第三方复现**：没有任何 optimizer 发布过 holdout/回退数据；除 §3.1 的 n=10 帖外无「优化后回退」的一手对照实验。
- 对 `agnix` / `vigiles` / `driftlint` / `rulewarden` / `clawmark` **无任何第三方批判性评测**（都太新）。
- skills 市场无第三方质量审计；GitHub Marketplace 多数 Action 只核对了名称未核仓库。
- 中文社区只有同步/管理器讨论（V2EX 186 帖集中在同步管理，且带失败案例：ccswitch「会强制写回 Agent 的配置文件」）；linter/optimizer 的中文评价未找到可靠资料。
- 本次 GitHub 搜索 API 中途限流，长尾低星项目可能漏（补搜建议：`"instruction file drift"`、`"rules compiler"`）。
- `@agentwares/agentsmd-lint`（npm 278 下载/月）指向的 GitHub 仓库 404；`@yawlabs/ctxlint` 下载量与 star 严重倒挂。

## 6. 抽验记录（本次亲测）

- `gh api` 实测 star / pushed_at / license 与调研笔记逐条一致：`rulesync` ★1520（2026-10-16）、`ruler` ★2945、`agent-os` ★5508、`microsoft/SkillOpt` ★18460、`NVIDIA/SkillEvaluator` ★571、`NVIDIA/SkillSpector` ★20310、`agent0ai/dox` ★1486、`wrsmith108/claude-md-optimizer` ★26（无 license）。
- 上游 `anthropics/skills`（★181414）：根目录含 `.claude-plugin / skills / spec / template`；`skills/skill-creator/` 下确有 `scripts/`（`quick_validate.py`、`improve_description.py`、`run_eval.py`、`run_loop.py`、`aggregate_benchmark.py`、`generate_report.py`、`package_skill.py`）、`agents/`、`eval-viewer/`、`references/`。本机 ZCode 版实测只有 1 个文件 `SKILL.md`。
- `agnix` = `agent-sh/agnix` ★452（`gh search repos` 实测）。
- arXiv 2610.11007 摘要与定理（上界 / 全追加更差 / 删除有害 / 删失反馈）已对原文核验。
- 原始调研笔记（含全部 URL 与未核实标注）在 manbo-reader 仓库 `.tmp/research/`（agentsmd-tools / skills-tools / tooling-reviews）。
