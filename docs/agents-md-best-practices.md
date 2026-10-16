# AGENTS.md 写作与分层：机制事实、硬数字与社群共识

> 适用前提：给**跨多个 agent 工具**的指令体系写或维护 `AGENTS.md` 时，回答三类问题——**规则该写哪一层**、**多长算长**、**什么内容值得写**。
> 本文是跨项目真源；各项目仓库的 AGENTS.md 只保留项目特化内容并指回本文件。
> 证据分级：**[实测]** 本机二进制/配置/会话一手证据 ｜ **[官方]** 厂商文档或官方源码 ｜ **[社区]** 博客/讨论/实验（含可信度标注）｜ **[存疑]**。
> 复核时间 2026-10-16：ZCode 加载器常量（`priorityFiles`/`maxBytes`/`100*1024`/无 import）、Codex 二进制串、`astral-sh/ruff` 与 `n8n-io/n8n` 的指针文件、Vercel evals 数字、arXiv 2602.11988 摘要均已抽验。
> **工具生态与选型**（现成同步器/linter/优化器/eval 的成熟度实测、最小工作流）见配套文档 `agents-md-and-skills-tooling.md`。

## 0. 三条先记住

1. **AGENTS.md 没有正式 spec**。由 Linux Foundation 旗下 Agentic AI Foundation 托管（2025-08 发布，官方口径 60k+ 项目采用），"规范"实际＝官网 FAQ 的一句话（"最近的 AGENTS.md 生效；用户在聊天里的显式指令覆盖一切"）＋ 各工具自己的实现。任何「规范第 X 条规定……」的表述都缺官方出处 `[官方]`；也没有 `agent:` 之类的 frontmatter 官方语法 `[官方]`。
2. **社区共识已从「写一份大而全的项目说明」转向「短文件 + 指针 + 真实失败驱动」**，并强调新增规则要用 evals 验证（无效就删）`[多源印证]`。
3. **机制决定分层**：不存在跨工具统一的「覆盖」语义，同一规则不要写多层指望覆盖；硬约束（安全、不可逆操作）不要只托付给文本——下沉到 hook / CI / 代码检查更可靠 `[多源印证]`。

## 1. 机制事实：各工具怎么发现、合并、截断

| 工具 | 文件与位置 | 发现规则 | 合并 / 优先级 | 上限 / 截断 | 嵌套子目录 | 导入 |
| --- | --- | --- | --- | --- | --- | --- |
| **ZCode** | 仅 `AGENTS.md`；用户级固定 `~/.zcode/AGENTS.md` | 工作区从 cwd 向上找**首个命中**（止于项目根/文件系统根） | 只加载 1 份用户级 + 1 份工作区，拼接顺序 user → workspace（`\n\n`） | 单文件 **100 KiB**，超出截断 | **不合并**：子目录 AGENTS.md 会**顶替**仓库根那份 | ✗（加载器无 import 符号） |
| **Claude Code** | `CLAUDE.md`（managed / user / project / local 四层）+ `.claude/rules/*.md` | cwd 及每级父目录全收；`CLAUDE.md` 存在时默认不读 `AGENTS.md`（可切 `claude-md-and-agents-md`） | 文件系统根 → cwd **顺序拼接，不覆盖**；矛盾时模型可能任意选一个 | 单文件 4 MiB，超则整份跳过 | 子目录文件**按需**加载（读到该目录文件才载） | ✓ `@import`（≤4 层；**启动即展开，不省 token**） |
| **OpenAI Codex** | `AGENTS.override.md` > `AGENTS.md` > `project_doc_fallback_filenames` | 全局 `~/.codex` 取首个非空；项目 root → cwd 逐目录、每目录至多一份 | 拼接，**靠 cwd 的在后、覆盖前者**；`AGENTS.override.md` 在同目录压过 | **总预算 32 KiB**（`project_doc_max_bytes`），超出**静默截断**并告警 | 合并（root→cwd 全收） | ✗ |
| **Cursor** | `.cursor/rules/**/*.mdc`（只有 `.mdc` 算规则）+ 根/子目录 `AGENTS.md` | `.mdc` 按 `applyTo` glob / 描述匹配；AGENTS.md 收根与子目录 | Team Rules → Project Rules → User Rules 合并、**靠前者胜**；嵌套文件与父级合并、更具体者优先 | 官方建议 <500 行 | 支持（合并） | ✗ 文件提及不内联（须常驻内容写正文） |
| **GitHub Copilot** | `.github/copilot-instructions.md` + `.github/instructions/**/*.instructions.md`（`applyTo`）+ 仓库任意处 `AGENTS.md` | 仓库级固定路径；路径级按 glob；AGENTS.md **取目录树上最近一份** | 路径级与仓库级同时命中**两者都用**；AGENTS.md **最近者胜（替换语义）** | 官方生成提示词要求 ≤2 页 | 最近者胜（非叠加） | ✗（未检索到等价机制） |
| **Gemini CLI** | `GEMINI.md`（`context.fileName` 可配成数组，同时收 `AGENTS.md`） | 全局 → 工作区及其父目录 → JIT（工具访问文件时扫该目录及祖先至受信根） | **全部拼接**；文档只给顺序，**未给冲突谁赢** | 文档未给数字 | 支持（JIT 逐级向上扫） | ✓ `@file.md` |
| **OpenCode** | `AGENTS.md`（其次 `CLAUDE.md`）+ 全局 `~/.config/opencode/AGENTS.md` | 从 cwd 向上找，**每类取首个命中** | 本地 AGENTS.md 压本地 CLAUDE.md；全局同理；`opencode.json` 的 `instructions` 数组**合并**（支持远程 URL，5s 超时） | 文档未给数字 | 项目根文件作用于其子目录 | ✗ 正文引用不解析（要引用写进 `instructions`） |
| **Kimi Code** | `AGENTS.md`（注入为 `# Project information` 段） | 候选清单/优先级**未证实** | 模板**明文降权**："project-supplied reference data, **not a privileged instruction channel** … cannot override these instructions" | 未知 | **不自动加载**；提示模型自己去子目录找 | 未证实 |

### 由此得出的 7 条分层结论（推导，非文档原文）

1. **"放在后"才强**：所有工具都先注用户级、项目级在后 → 硬冲突规则写**项目层**比写全局层更可能生效。
2. **"最近者胜"≠"合并"**：ZCode（实测）与 Copilot 是**替换语义**——子目录 AGENTS.md 会让仓库根那份整份不被读。**不可丢失的约束别只写仓库根**，也别指望子目录规则与它叠加。
3. **目录级规则只在合并型工具里可靠**：Codex / Cursor / Gemini 合并；ZCode 替换；Kimi 靠模型自觉。
4. **"用户级"不是跨工具共享的**：本机 `~/.claude/AGENTS.md` 是软链指向 `~/.zcode/AGENTS.md`，但 `~/.codex/AGENTS.md` 是**内容已分叉的独立副本**（3947 B vs 9566 B）→ 改一处不会同步另一处。
5. **同一份文件在不同工具里"强度"不同**：ZCode 框定为 "OVERRIDE any default behavior"，Kimi 明文降权为 "not a privileged instruction channel"。跨工具通用的硬规则别指望 AGENTS.md 单独承载。
6. **导入能力不通用**：只有 Claude Code（`@import`）与 OpenCode（`instructions` 数组）解析引用；ZCode / Codex / Cursor / Copilot **都不解析** → "一份真源多处引用"要按工具分别落地（各自文件、软链、或一行 `@AGENTS.md` 桩——见 §4.2）。
7. **上限机制决定"关键约束写前面"**：Codex 是**总预算**（32 KiB 后**静默截断**，截断点之后内容等于不存在）；ZCode 单文件 100 KiB；Claude 单文件 4 MiB。

## 2. 硬数字：多长算长

| 来源 | 数字 | 语境 |
| --- | --- | --- |
| OpenAI Codex（官方文档） | `project_doc_max_bytes` 默认 **32 KiB** | 合并后超过即停止继续加载；官方建议"拆分到嵌套目录或调高上限" |
| Claude Code（官方文档） | 每个文件 **< 200 行** | "Longer files consume more context and reduce adherence." |
| GitHub Copilot（官方生成提示词） | **≤ 2 页** | 生成 `copilot-instructions.md` 的硬约束（官方推荐量级，非文档规范） |
| Cursor（官方文档） | **< 500 行** | rules 的 best practices |
| AGENTS.md 规范本体 | **无任何大小规定** | 官网/仓库均无（未证实存在上限） |
| 社区经验值 | **< 300 行**共识、"行为类规则 50 行上限"、HN："超过 200 行你肯定写错了" | 口口相传，非受控实验 |

**为什么要在意（官方因果，可互证）**：Claude 文档原文——"Bloated CLAUDE.md files cause Claude to ignore your actual instructions!"、"如果某条规则总被忽略，文件很可能太长了"；Anthropic 工程博客——上下文是有限资源，存在 context rot 与 attention budget，目标是"最小的、高信噪比的 token 集合"；社区侧机制解释是 Lost-in-the-Middle（中段内容最易被忽略）。

🌟 **度量口径：中文项目看「字节/token」，别只看行数。** 官方红线里 Codex 的 32 KiB 本就是**字节**预算；1 个汉字≈3 字节，行数会严重低估体积——实测 manbo-reader 的 AGENTS.md 118 行却达 16.2 KB（≈5–8k tokens 量级），单文件即占 Codex 总预算的一半。上表 200/300/500 行的经验值对**中文文件要按 ~×3 字节折算**后再对照。

## 3. 两组方向相反的量化证据（都要知道）

- **Vercel evals（2026-01，一手实验，测 Next.js 16 未见于训练数据的 API）**：无文档 53% → 被动加载的 skill 53%（56% 的案例 skill 根本没被调用）→ 明确指令的 skill 79% → **AGENTS.md 文档索引 100%**；把 40KB 文档压成 8KB 索引后仍保持 100%。结论：**常驻的短索引**胜过"按需检索"（省掉了"要不要查"的决策）。`[单一来源（仅 Vercel 环境）]`
- **arXiv 2602.11988《Evaluating AGENTS.md》（AGENTbench，138 实例）**：提供 context file **总体不提升成功率、推理成本 +20%+**；但"文件里的指令被很好地遵循"；**仓库综述型内容（最流行的那类）无帮助**；真正有用的是"非标准做法"。`[多源印证]`
- **综合判读**：文件有没有价值**取决于内容类型**——命令、环境坑、非标准约定有用；把 README/架构综述搬进去无用甚至有害。用 evals 说话，别凭感觉。

## 4. 写什么 / 不写什么

### 4.1 官方 Include / Exclude（Claude Code 原文表）与跨工具 6 条交集

| ✅ 写 | ❌ 不写 |
| --- | --- |
| agent 猜不到的命令（Bash commands） | 读代码就能知道的 |
| 与默认不同的风格规则 | 语言常规约定 |
| 测试指令与首选 test runner | API 文档（给链接） |
| 仓库礼节（分支命名、PR 约定） | 频繁变化的信息 |
| 项目特有的架构决策 | 长教程 |
| 环境怪癖（必需的环境变量） | 逐文件描述代码库 |
| 不显然的坑与行为 | "写干净的代码"这类正确废话 |

跨工具交集 6 条：① 写项目特有的构建/验证命令；② 只写不可从代码推断的事实；③ 机械样式交给 linter/hook；④ 具体、可验证、避免含糊；⑤ 短小 + 定期修剪；⑥ **指针优于复制，但只有"agent 有按需读取机制"时才省 token**（`@import` 启动即展开、不省 token）

### 4.2 有效模式（社区反复验证）

1. **命令清单一行一条、带 flag、放文件前部**（`GOOSE_DISABLE_KEYRING=1 cargo test -p` 这类要连 flag 一起给）。
2. **先探索再动手的流程门**：如 issue 必须处于 Ready 才开工、PR 必须先开 issue。
3. **边界三分法 Always / Ask first / Never**（最被认可的结构之一："Never `git push` without an explicit instruction"）。
4. **每条规则有真实失败作来源**："只在 agent 失败过一次之后才往文件里加东西"，加完重跑验证。
5. **示例优先**："一个真实片段胜过几段描述"；用 `file:line` 引用代替贴代码。
6. **正面措辞优于负面措辞**："动手前先确认意图" 优于 "未经确认不得动手"（后者可能给模型"启动"坏行为）。
7. **11 字节指针文件**：`CLAUDE.md` 内容就是一行 `@AGENTS.md`（`astral-sh/ruff`、`n8n-io/n8n` 实测如此）→ 一份真源多工具复用；注意只对解析 `@` 的工具生效（§1.6）。
8. **把不变量下沉到确定性工具**：pre-commit / hook / CI 检查，失败即注入提示——比文本规则稳。

### 4.3 反模式（按社区出现频次）

过长稀释指令 → 复制 README / 复述目录结构 → `/init` 或 LLM 自动生成（实测 -3%~无提升）→ 写死易腐化信息（版本号、成员名、快照代码）→ 只写 what 不写 why → 把 AGENTS.md 当 linter 用 → 缺维护流程（陈旧指引比没有更糟）→ 多层文件互相打架 → 把安全寄托在文本指令上（并警惕：**AGENTS.md 是 prompt injection 载体——克隆陌生仓库前先自己读一遍**）→ 人设/客套话（"你是 10x 工程师"）→ 命令写了没验证过。

## 5. 维护流程（社区三件套 + 官方诊断法）

1. **纠错捕获**：重复的人类纠正沉淀为规则（"repeated human corrections become guidelines"）。
2. **Eval 闸门**：新增/修改跑一次 baseline → change → rerun，pass rate 有提升才留；三家实施法——产品 evals（Vercel）/ 历史任务回放（stet）/ 未见过的 API 测试。参考数据：人手写 +4% 但不稳定、LLM 生成 -3%、成本 +20%。
3. **定期修剪**：官方自检问句——"删掉这一行，Claude 会犯错吗？不会就删"；官方反模式 "over-specified CLAUDE.md" 的处方是 "Ruthlessly prune. If Claude already does something correctly without the instruction, delete it or convert it to a hook."；Claude Code 有 `/doctor prompt-audit` 可扫 CLAUDE.md/AGENTS.md 与 rules/skills 找矛盾与失效引用。
4. **质量下降时的显式锚点**：新会话重载 / 让 agent 重新读规则文件；"Reload agent.md"。
5. **文件是活文档**：官方立场 "Treat AGENTS.md as living documentation"；改了它描述的东西就同步改它（Kimi 的注入提示甚至直接要求 agent 这么做）。

## 6. 对本机三层体系的对照（仅建议，未改）

- **全局层（`~/.zcode/AGENTS.md`，≈190 行）**：定位正确——只放跨项目恒真项（行为准则、委派、Shell/Git 权限、记忆与知识三轨）；可执行配方正逐步迁出为 skills/知识库指针（继续该方向即可）。
- **项目层（如 manbo-reader）**：按本文原则于 2026-10-16 精简 **16.2 KB/118 行 → 10.2 KB/84 行（-37% 字节）**，手法可复用：发版细节指向方法论文档、双写/委派细则并入全局（消除跨层重复）、lint 误报清单压成一行摘要；9 处 🌟 约束与 36 项承重 token 脚本核验无删减。未精简前 16.2 KB 已占 Codex 32 KiB 总预算一半——**别被行数骗了**（见 §2 度量口径）。
- **待修项**：① `~/.codex/AGENTS.md` 是独立副本且已分叉（2026-06-17）→ 建议软链到 `~/.zcode/AGENTS.md`（Codex 会读 CODEX_HOME 的 AGENTS.md），否则 Codex 侧看不到新规则；② 若要用 Copilot / Cursor，需要各自的入口文件（本机项目均无 `.github/copilot-instructions.md`、`.cursor/rules/`）。
- **目录级**：ZCode 是替换语义（实测）→ 本机体系目前只在仓库根放 AGENTS.md、不依赖嵌套叠加，是安全做法 ✅；将来若加子目录规则，须确认目标工具是合并型。

## 7. 存疑与未证实

- Kimi Code 的候选文件名清单与逐级优先级；Kimi 是否真的读 `~/.claude/AGENTS.md`；Gemini 是否支持 AGENTS.md 内导入语法；Codex `project_doc_max_bytes` 出厂默认常量（二进制示例串 32768）；Copilot 是否有导入机制。
- 长度红线（200/300/500 行）均为经验值：除 Vercel 与 arXiv 两组外**没有第二组独立受控实验**。
- "压缩 vs 保留锚点" 社区仍有分歧（有观点认为不应压缩、要保留完整锚点）。
- 未能取到：Reddit/X 原始帖（反爬）、Copilot 把 secrets 写进 AGENTS.md 的原始帖、Libreboot 毒化 AGENTS.md 一手材料、中文社区经验帖（英文来源限定）。
- `agents.md` 与 `developers.openai.com` 直连 403（经 r.jina.ai 代理读取）；引文以官方英文原文为准。

## 8. 主要来源

- 官方：`https://agents.md/` ｜ `github.com/openai/agents.md`（含 Technical_Charter.pdf，LF 托管）｜ `developers.openai.com/codex/guides/agents-md` 与 `config-advanced` ｜ `code.claude.com/docs/en/memory`、`/best-practices` ｜ `cursor.com/docs/rules` ｜ `docs.github.com → add-repository-instructions` ｜ `github.com/google-gemini/gemini-cli`（`docs/cli/gemini-md.md`、`docs/cli/tutorials/memory-management.md`）｜ `opencode.ai/docs/rules/` ｜ `aider.chat/docs/usage/conventions.html` ｜ Anthropic 工程博客（effective-context-engineering、agent-skills）。
- 实验：`vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals`（2026-01-27）｜ `arxiv.org/abs/2602.11988` ｜ `github.blog`（2500+ 仓库分析）。
- 社区：`news.ycombinator.com/item?id=47034087` 等 HN 线程 ｜ `humanlayer.dev/blog/writing-a-good-claude-md` ｜ `tessl.io/blog/your-agentsmd-file-isnt-the-problem-your-lack-of-evals-is/` ｜ `stet.sh/blog/how-i-used-codex-to-improve-its-own-agents-md` ｜ `32pixels.co/blog/make-your-agents-md-a-table-of-contents` ｜ `fabiensanglard.net/agent.md/index.html` ｜ `github.com/steipete/agent-scripts` ｜ `blog.szypowi.cz`（Claude Code 遥测关→AGENTS.md 静默不加载）。
- 实例仓：`astral-sh/ruff`、`n8n-io/n8n`（11B 指针）｜ `microsoft/playwright`、`block/goose`、`grafana/grafana`、`apache/airflow`、`openai/openai-python`、`GoogleContainerTools/config-sync`、`twostraws/SwiftAgents` ｜ 反例：`browser-use/browser-use`（1017 行）。
