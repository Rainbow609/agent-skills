# AI 编码代理「主会话=规划者」编排模式调研

> **来源**：官方一手文档/工程博客六家（Anthropic、OpenAI Codex、GitHub Copilot/Spec Kit、Cursor、Cognition、Google Jules/Gemini CLI）＋ 社区专家配方四家（Harper Reed、IndyDevDan、Geoffrey Huntley/Ralph、Matt Pocock）。2026-10-17 两轮并行子代理调研，全部结论带一手 URL。
> **复核**：官方来源直读官方文档站/工程博客/官方仓库原文。两处官方站点不可访问已换一手替代源并核实：OpenAI 官方文档站 403 → 改用官方仓库系统提示原文（`codex-rs/core/gpt-5.2-codex_prompt.md`）；Gemini CLI 旧文档站 404 → 改用官方仓库 `docs/cli/plan-mode.md`。社区配方均为作者本人一手文章/仓库。
> **适用前提**：2026-10 口径；各厂商产品形态迭代快，机制细节以届时官方文档为准。
> **定位**：与 [`agents-md-best-practices.md`](./agents-md-best-practices.md)（规则文件写作）、[`matt-pocock-skills-guide.md`](./matt-pocock-skills-guide.md)（执行纪律层）、[`ai-coding-workflow-openspec.md`](./ai-coding-workflow-openspec.md)（工作流分级）互补——本文只回答一个问题：**主会话（主代理）作为规划者，业内公认它该做什么、不做什么、怎么做**。

## 1. 共识框架：规划者只做四件事

把六家官方与四家社区来源叠加，主会话的职责收敛为四项，每项业内都有对应机制：

| 职责 | 业内机制 | 代表来源 |
| --- | --- | --- |
| ① 对齐与定案 | plan 先生成、批准前零代码改动；决策必须由人/主代理做，agent 自问自答=跑坏了 | Jules/Gemini/Cursor/Spec Kit 全员一致；Matt grilling 的 facts/decisions 二分 |
| ② 产出书面计划 | 计划产物化（spec/plan.md/fix_plan.md）——真实用途是**给一个新鲜上下文的交接协议**；票粒度=一个 context window | Spec Kit 分阶段门；Matt to-tickets；Ralph fix_plan.md |
| ③ 写 brief 委派 | 四要素（objective/输出格式/工具与来源指引/清晰任务边界）；内容 durable 而非 precise（写契约不写文件路径行号） | Anthropic multi-agent 博文；Matt triage |
| ④ 收口核验 | 亲自走读关键产物 + fresh-context 评审子代理；要证据（测试/截图）不要自称成功；agent 不自评、不自行 commit | Anthropic best practices；IndyDevDan "Agent proposes, code disposes" |

规划者**不做**的：读密集探索（污染主上下文）、跑确定性命令（"已知测试套件直接跑，用 agent 跑什么也买不到"）、实现细节。

## 2. 官方一手做法对比（六家）

| 厂商 | 规划者形态 | 关键机制 | 一手来源 |
| --- | --- | --- | --- |
| Anthropic | 编排者 + 子代理过滤器 | explore→plan→code→commit；brief 四要素；fresh-context 评审 | [Best Practices](https://code.claude.com/docs/en/best-practices)、[Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system) |
| OpenAI Codex | 单线程规划者 | Plan tool 三律；提示词内无任何委派语言 | [官方系统提示](https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/gpt-5.2-codex_prompt.md) |
| GitHub Copilot | 后台执行 + 人审门 | 一任务一 PR；Spec Kit 四阶段逐段复核 | [coding agent](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent)、[Spec Kit 公告](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/) |
| Cursor | Plan Mode + 子代理 | 仅复杂任务排计划；子代理背景必须写进 prompt | [Plan Mode](https://cursor.com/docs/agent/plan-mode)、[Subagents](https://cursor.com/docs/agent/subagents) |
| Cognition | **反对多代理** | 单线程线性 + 压缩蒸馏；共享完整轨迹 | [Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents) |
| Google | plan 先审批 | Jules 生成可审阅 plan；Gemini CLI Plan Mode 严格只读 | [Jules Docs](https://jules.google/docs/)、[Gemini CLI plan-mode](https://raw.githubusercontent.com/google-gemini/gemini-cli/main/docs/cli/plan-mode.md) |

### 2.1 Anthropic：最完整的正面表述

- **规划边界**：explore→plan→code→commit 四段，"Separate research and planning from implementation to avoid solving the wrong problem"；**一句话说得清的 diff 直接做，plan mode 有开销**。
- **子代理定位**："intelligent filters"（智能过滤器）——只回摘要不回原始输出，主对话保持干净；brief 必须含 objective/输出格式/工具与来源指引/清晰任务边界四要素；成本硬数字：单代理 4×、多代理 ~15× token。
- **上下文工程**：context window 是"最重要的待管理资源"；长任务三法＝压缩（compaction）/ 外部笔记（计划落文件）/ 子代理架构。
- **收口核验**："have a subagent review the diff in a fresh context"——评审者看不到生成推理才能讲真话；要求证据而非自称成功。

### 2.2 OpenAI Codex：单线程规划者的极简形态

提示词里完全没有 subagent/委派语言。Plan tool 三律值得单独抄：

1. 跳过最简单的 25% 任务，不排计划；
2. 单步任务不做计划；
3. **每完成一个子任务立即更新计划**——计划是活的调度板，不是一次性文档。

### 2.3 GitHub Copilot / Spec Kit：分阶段人审门

coding agent 后台执行"一任务一 PR"，官方明示 "Logs do not replace your own review and testing"。Spec Kit 把"人=规划者"写进流程：specify→plan→tasks→implement，**每阶段人工复核后才准进入下一阶段**，"The AI generates the artifacts; you ensure they're right"。

### 2.4 Cursor：计划产物化 + 子代理背景自足

Plan Mode 只对复杂/多文件/架构类任务启用，先澄清提问再研究代码库；计划落盘 markdown 可审改。子代理独立上下文（看不到会话历史），**父代理必须把背景写进 prompt**——背景不随委派自动继承，这条所有人都踩过。

### 2.5 Cognition：最重要的反对派

两条原则："Share context, and share full agent traces, not just individual messages"；"Actions carry implicit decisions, and conflicting decisions carry bad results"。并行子代理看不到彼此完整轨迹，隐含假设互相冲突导致结果不一致；默认用**单线程线性代理**保上下文连续，超长任务用压缩模型蒸馏决策，并断言"拆活→起子代理→合并"的架构天然脆弱。

### 2.6 Google：plan 先审批

Jules：任务先产出可审批的 plan，"You can review and approve it before any code changes are made"；自动读仓库根 AGENTS.md 使计划更相关。Gemini CLI Plan Mode：严格只读环境（Research/Design/Plan 三阶段），内置调研子代理但规划权在主代理，批准即退出只读开工。

## 3. 核心分歧与裁决：多代理并行 vs 单线程

表面对立：Anthropic 拥抱多代理（15× token 换并行与上下文隔离）vs Cognition 判死多代理（隐含决策冲突）。**裁决是读写分离**——Cognition 反对的实质是**多个写代理并行改代码**（每个 action 隐含一个决策，写者之间必然冲突）；Anthropic 的多代理成功案例全部是**只读研究并行**（探索、调研、评审互不踩脚）。

工程化条款（可直接写进编排规则）：

1. 只读任务（探索/调研/评审）可并行，天然无冲突；
2. 写任务并行须同时满足：互不相交的文件集 + 无隐性耦合（共享状态/共享顺序假设）；
3. 任何情况下**单一写者收口**——合并与提交归主代理。

## 4. 社区专家配方

- **Harper Reed**（[My LLM Codegen Workflow](https://harper.blog/2025/02/16/my-llm-codegen-workflow-atm/)）：三段产物＋三道人审门——对话模型反问式逼问出 `spec.md` → 推理模型出 `prompt_plan.md`+`todo.md` → codegen 执行；规划约 15 分钟，执行成败取决于第二步（计划质量）。
- **IndyDevDan**（[super-simple-software-factory](https://github.com/disler/super-simple-software-factory)）：把控制面从提示词搬进代码——"control plane out of the prompt and into Python"，ADW 脚本持有序、重试、验收；"Agent proposes, code disposes"；跨阶段只传 typed JSON——"Context transfers in code, not in conversation"。这是规划者角色**制度化**的极致形态。
- **Ralph**（[ghuntley.com/ralph](https://ghuntley.com/ralph/)）：主上下文退化为调度器——规划用多子代理产出/反复重写 `fix_plan.md`，plan 与 specs 每轮确定性注入；build/test 只留 1 个子代理以保背压。
- **Matt Pocock**（[mattpocock/skills](https://github.com/mattpocock/skills)，精读见 [`matt-pocock-skills-guide.md`](./matt-pocock-skills-guide.md)）：与本主题最相关四条——①两层调用轴：编排层（user-invoked）不写纪律、纪律层（model-invoked）不管编排，**规划者=编排层的唯一 occupant**；②票尺寸判据＝"一个新鲜 context window 装得下"，tracer bullet 垂直切片（按层拆票是最常被违反的规则，实测 3/4 返工）；③spec 写完**开 fresh session 执行**——计划产物就是给干净上下文的交接协议；④triage 产 brief：**durable 而非 precise**——只写类型/签名/行为契约，永不写文件路径行号（issue 会躺几周而代码在变）。

## 5. 反模式清单（8 条）

| # | 反模式 | 症状与判据 | 出处 |
| --- | --- | --- | --- |
| 1 | Context rot | token 越多召回越降，注意力预算被占用；应求"最小高信号 token 集" | Anthropic context engineering |
| 2 | 摘要有损 + 多写者冲突 | 多个写代理产出冲突决策与碎片化上下文；子代理宜只读问答 | Cognition |
| 3 | 过度委派 | 官方自曝早期"简单查询 spawn 50 个子代理"、重复劳动、超 200k 截断、非确定性难调试 | Anthropic multi-agent（教训章） |
| 4 | 规划者被实现细节污染 | 主会话亲自读多文件做调研 → 上下文灌爆、判断力下降；解法=委派，"keeping your main conversation clean" | Anthropic best practices、Ralph |
| 5 | 无缝流水线 | 把整个 SDLC 丢给一个模型变成 "machine with no seams"，"done" 只等于代理停止说话；**禁止代理自评、自己 commit** | IndyDevDan |
| 6 | 冷重启重试 / 确定性工作交代理 | 重试丢弃全部上下文；跑已知测试套件 "buys you nothing at all"——确定性代码直接跑，不派 agent | 同上 |
| 7 | 完美 prompt 迷信与过早 a2a | "no such thing as a perfect prompt"；过早引入 agent-to-agent/微服务编排是 "red hot mess" | Huntley/Ralph |
| 8 | 审查者无限追 finding | 被告知"找 gap"的 reviewer 即便代码没问题也会报问题；须限定只报影响正确性/违反明确需求的项，且在 fresh context 跑 | Anthropic best practices |

## 6. 落地对照：本机体系覆盖度与增量清单

本机既有体系（全局 AGENTS.md 的 orchestrator-worker 规则 + OpenSpec 权威计划层 + Matt skills 执行纪律层，结合模式见 [`openspec-matt-skills-combination.md`](./openspec-matt-skills-combination.md)）对四职责的覆盖：brief 四段≈四要素（③）、"回接核验强制"≈收口（④）、"规划与定案不外包"=各家共识中最独特也最正确的一条（①）、OpenSpec tasks.md≈书面计划（②）。**覆盖度高，真正的增量只有五条**：

1. **Codex 计划三律**：把"跳过最简 25% 不排计划""每完成子任务即更新计划"写进规划规则——后者补上"计划是一次性文档"的隐含倾向。
2. **评审负面清单**：给评审子代理显式指令"只报影响正确性或违反明确需求的项"——防审查者无限追 finding（#8）。
3. **spec 定稿后 fresh session 执行**：Anthropic 与 Matt 链路共同背书；同一长会话从规划干到实现正撞反模式 #4。
4. **并行条件显式化**：把 §3 的读写分离条款写明（只读可并行；写须互不相交文件且无隐性耦合；单一写者收口）。
5. **控制面进代码**（远期）：IndyDevDan 的 "context transfers in code" 是脚本化编排（typed 中间产物 + 代码控制流）的理论地基；已有多代理工作流平台的场景下即"编排脚本持有顺序/重试/验收，子代理只做限界节点"。

> 以上五条已于同日（2026-10-17）落为全局 AGENTS.md 规则（本仓库「子代理委派」节），规则以 AGENTS.md 为准，本节保留调研依据。

## 7. 参考链接

- Anthropic：[Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) ｜ [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents) ｜ [Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system) ｜ [Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- OpenAI Codex：[GPT-5.2 Codex 系统提示（官方仓库原文）](https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/gpt-5.2-codex_prompt.md)
- GitHub：[About coding agent](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent) ｜ [Spec Kit 公告](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/) ｜ [github/spec-kit](https://github.com/github/spec-kit)
- Cursor：[Plan Mode](https://cursor.com/docs/agent/plan-mode) ｜ [Subagents](https://cursor.com/docs/agent/subagents)
- Cognition：[Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents)
- Google：[Jules Docs](https://jules.google/docs/) ｜ [Gemini CLI Plan Mode（官方仓库）](https://raw.githubusercontent.com/google-gemini/gemini-cli/main/docs/cli/plan-mode.md)
- 社区：[Harper Reed 工作流](https://harper.blog/2025/02/16/my-llm-codegen-workflow-atm/) ｜ [super-simple-software-factory](https://github.com/disler/super-simple-software-factory) ｜ [Ralph](https://ghuntley.com/ralph/) ｜ [mattpocock/skills](https://github.com/mattpocock/skills)
