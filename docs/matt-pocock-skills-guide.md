# Matt Pocock Skills（mattpocock/skills）官方知识精读

> **来源**：[mattpocock/skills](https://github.com/mattpocock/skills)「Skills for Real Engineers」——作者日常使用的 agent 技能集，Claude Code 官方插件分发（v1.3.1，2026-10-16 克隆 main）。
> **复核**：README / SCOPE / AGENTS.md / GLOSSARY / engineering 分类页＋grill-with-docs、to-spec、implement 三个核心 SKILL.md 主代理逐篇精读；其余 30+ 技能的 docs 页（aihero.dev 同源）、in-progress/misc SKILL.md 与 CHANGELOG 经子代理通读摘要。原话金句均保留英文原文。
> **定位**：入门与工具生态见 [`agents-md-and-skills-tooling.md`](./agents-md-and-skills-tooling.md)；本文沉淀该技能集的**方法论骨架**（四大失败模式、两层调用轴、端到端链路、写作方法论），单技能细节按需查官方 docs 页 `aihero.dev/skills-<name>`。

## 1. 定位与哲学：四大失败模式（README 骨架）

作者立场：反对 GSD / BMAD / Spec-Kit 这类「接管过程」的重流程——本集技能**小、可改、可组合**，与 OpenSpec 同为轻量流派但切面不同（OpenSpec 管「文档关住 AI 自由度」，Matt 管「工程基本功灌进技能」）。

| 失败模式 | 解法 | 技能 |
| --- | --- | --- |
| #1 Agent 没做我想要的（misalignment） | grilling session：让 agent 反过来拷问你 | grill-me（非代码）/ grill-with-docs（代码，最受欢迎） |
| #2 Agent 太啰嗦（语言不共享） | 共享语言 GLOSSARY.md＋ADR | grill-with-docs / domain-modeling ——作者称「可能是全仓最酷的技术」：统一语言→命名一致→agent 少花 token 思考 |
| #3 代码跑不起来（反馈回路缺失） | red-green 测试环＋纪律化诊断 | tdd / diagnosing-bugs |
| #4 建成泥球（agent 加速软件熵增） | 每天投资设计（Kent Beck）、deep module（Ousterhout） | to-spec 先盘问模块 / codebase-design 词汇 / improve-codebase-architecture 周期扫描（「survey, not a rescue」） |

## 2. 架构：两层调用轴（全仓不变式）

- **user-invoked**（`disable-model-invocation: true`）：只能人敲 `/xxx`，职责=**编排**（orchestrate）；**任何技能不得调用它**——未配置时只能提示人跑 `/setup-matt-pocock-skills`。
- **model-invoked**：人可调、agent 也可按任务自动够取，承载**可复用纪律**（tdd / code-review / grilling / domain-modeling…）。
- 组合哲学的极致：`grill-with-docs` 全文只有一句——「Call the Skill tool twice, for "grilling" and "domain-modeling"」；`implement` 也只是「取票→在 pre-agreed seam 调 tdd→完成调 code-review→commit」。**编排层不写纪律，纪律层不管编排**。
- bucket 规则：`engineering/`＋`productivity/` 是 promoted（必进 README＋插件清单）；`misc/` 冻结；`in-progress/` beta 随装随改随删；`deprecated/` 弃用。
- `ask-matt` 是全仓路由器（描述处境→推荐技能或 flow，"recommends and stops"）；新增技能不更新它＝「a router that lies」。

## 3. 端到端链路

**主链（idea → ship）**：

```
grill-with-docs（驱动 grilling + domain-modeling）
  → to-spec → to-tickets（同一 context window，中间勿 clear/compact）
  → implement（逐票，内驱 tdd）或 implement-spec（任务图并行）
  → code-review → pr → retro
```

**三个 on-ramp（平行入口，都终于 `ready-for-agent`）**：
- 外来工作：`triage`（verify before you brief → 五状态机 → agent brief）。
- 大雾工程：`wayfinder`（map 四节：Destination / Decisions so far / Not yet specified(fog) / Out of scope；四种决策票 grilling/prototype/research/task；"plans and does not build"，map 清空→`/to-spec #<map>` 回主链）。
- 坏了的东西：`diagnosing-bugs`（修完同会话跑 retro 预防）。

**phase boundary 决策树**（ask-matt 持有，按序排除）：Continue（唯一保持 primary source）→ /clear → handoff（工作要「旅行」：换 harness/目录/同事/分叉）→ subagent（可 AFK 窄任务）→ /compact（兜底，不是首选）。

**grill 家族**：`grilling` 是唯一机制原语（design tree＋frontier＋round；`❓ Q1 - title`＋`➡️` 推荐答案；**facts vs decisions 二分**——事实派 subagent 查、决策必须等人答，agent 自问自答=跑坏了；frontier 空后还有确认闸）。三入口按答案在哪分：grill-me（自己脑中）/ grill-with-docs（代码库）/ to-questionnaire（别人）；聊不出来的题（"长文还是三页？"）→ prototype 看一眼带一行答案回来。

## 4. 共享配置与词汇层

- `setup-matt-pocock-skills` 每仓库跑一次，三产物落 `docs/agents/`：issue-tracker.md（GitHub/GitLab/本地 `.scratch/` markdown/自定义平权——**tracker 是配置不是假设**）、triage-labels.md（五规范名 `needs-triage/needs-info/ready-for-agent/ready-for-human/wontfix` 的映射）、domain.md（GLOSSARY/ADR 布局与消费规则）；并在 CLAUDE.md/AGENTS.md 写 `## Agent skills` 指针块。
- **GLOSSARY.md 规则**（头号违反=模型把它当 running spec 越写越大）：只放术语，一两句定义＋`_Avoid_` 拒用同义词；对话中敲定即**当场写入**；monorepo 用 GLOSSARY-MAP.md 分片。
- **ADR 三关**（缺一不写）：难以逆转＋无上下文会令人意外＋真实权衡的结果。
- 仓库自己 dogfood：本仓 GLOSSARY.md 即示范（Issue tracker / Issue / Decision ticket / Triage role，含 flagged ambiguities 段）。

## 5. 主链关键技能硬规则

- **to-spec**：不访谈、只综合已有对话；**seam 思想**——先画测试缝，优先既有缝、用最高缝、越少越好（理想 1 个），与用户确认后才写 spec；spec 模板七节（Problem/Solution/User Stories(长列表)/Implementation Decisions/Testing Decisions/Out of Scope/Notes）；**禁写文件路径与代码片段**（过时极快），唯一例外：prototype 产出的决策性片段（状态机/schema/类型形状）可内联并注明来源。写完直接打 `ready-for-agent`，不用再 triage。
- **to-tickets**：每票是 **tracer bullet**（垂直切片，穿 schema/API/UI/测试全层，落地即可 demo）＋声明 blocking edges；票尺寸=**一个新鲜 context window** 装得下。**垂直切分是最常被违反的规则**（实测：按层拆 26 票→每票约 20 次 agent 跑、3/4 返工）；检验问句「这票做完能 demo 什么？」。发布前 quiz 你批准。全库机械大重构例外：expand–contract（加新形式→分批迁移→删旧）。过度拆票同样常见（12 票配三行改动）。
- **tdd**：实为 red-green（**refactor 阶段已删**——agent 几乎不做，重构归 code-review；README 仍写三段是官方承认的未修不一致）；**pre-agreed seam**：没确认过的缝上一个测试都不写，无例外；三反模式：implementation-coupled（重命名内部函数就红）/ tautological（期望值按代码同法重算，须来自独立真值）/ horizontal slicing（先写一批测试=验证想象的行为）；**mock 只用于系统边界**（外部 API/时间/随机/文件系统/DB），永不 mock 自己的模块。
- **code-review**：双轴（Standards=仓库规范＋**Fowler 12 smell 基线**；Spec=忠实实现规格？）各跑一个互不污染的 subagent，**拒绝合并成单一结论**；每条发现必须带引用；Spec 轴找不到规格要明说 "no spec available" 而非编造需求。
- **pr**：PR body 三件套——Summary（选**最小可视化**：伪代码/调用树/Mermaid/shaped diff，让评审者读 diff 前看到形状）＋Evidence（before/after 实证；「测试绿了」不算证据）＋**Merge Danger**（one-way/two-way door＋blast radius——把「能不能合」从直觉变成可反驳声明；**agent 自己打的 door 判定别盲信**，写代码的人在给自己打分）。
- **retro**：改**环境**而非代码，只提议不擅改；机械违规→确定性检查（check 会 fail，句子不会）；评审规则写 `CODING_STANDARDS.md` 给 **reviewer 不给 implementer**（"standards belong to the reviewer"——实现者上下文压力最大）；**绝不往 AGENTS.md/CLAUDE.md 加规则**（每 session 载入、稀释、过时）。
- **implement-spec**（implement 的并行替代）：每票一个 git worktree implementer subagent，按任务图 frontier 并行，逐个 fast-forward 合入单一 integration branch；与 subagent 通信用 **context pointers**（指路径不贴摘要）。坑：code-review 只能在全部票落地后跑一次；并行票碰同一文件要预先加 blocking edge。

## 6. 规划与外围技能要点

- **wayfinder**：分界线是 **session 数不是项目大小**（单 session 规划用 grill-with-docs）；map 是 **index 不是 store**（决策活在票里，map 只留行＋链接）；"prototypemaxxing, not planmaxxing"——规划 27 票作废 13 张=瀑布陷阱，解法是 bounded destination＋激进 prototype。
- **diagnosing-bugs**：**先有紧反馈环（秒级、确定、一条能变红的具名命令）才许形成理论**——"A loop is not the goal. Tight is"；阶段是闸门非清单（进假设阶段前须 3-5 条可证伪假设给用户看）；间歇性 bug 目标是提高复现率而非干净复现。
- **prototype**：写**回答一个问题的弃代码**，问题优先、不写测试/抽象/持久化；**prototype 是 primary source**（v1.2 起不删，留 `prototype/<name>` 分支永不合并，答案进 commit/ADR）；一个 prototype 一次坐下答完，隔天没完=问题切太大。
- **research**：只认 primary sources（官方文档/源码/规范），每条声明带引用，落成 repo 内 Markdown；与 grilling 的分界是**产物保质期**——"如果产出是 decision 而非 fact，那是 grilling 不是 research"；过期研究文件要删（毒化后续阅读）。
- **triage**：只处理**外来** issue（自己 to-tickets 产的票已 agent-ready，再跑 triage 是浪费）；核心产物 **agent brief：durable 而非 precise**——只写类型/签名/行为契约，**永不写文件路径行号**（issue 会躺几周而代码在变）。
- **wizard**：agent 撞到只有人能做的步骤（配置三方服务/收密钥）→ 生成交互式 bash 脚本陪人走，**agent 只写脚本从不运行**（密钥不进模型上下文）。

## 7. 写作方法论：writing-for-agents（★ 对本体系最有价值）

一切 agent 读的文档（skill/AGENTS.md/spec/ticket/提示词）的写作参考。判据一句话："does an agent read this?"

- **默认动作用删不用解释**：解释模型已知的东西全是 **no-op**（花 context 换零行为改变）；no-op 测试看行为不看风格——删掉这句，行为变不变？
- **两种负载**：context load（常驻上下文的代价）vs cognitive load（人记住何时用哪个文档的代价——**别最小化它**，那是人的能动性）。
- **五杠杆**：context pointers（指路文本的措辞决定触发可靠性）、progressive disclosure、completion criteria（防 premature completion）、**leading words**（tight/tracer bullet/seam 等预训练已有的紧凑概念当思考把手——全仓的词汇纪律皆源于此）、pruning（单一真源＋逐句 no-op 测试）。
- **环境即权威**：package.json 脚本、目录布局、`--help` 本身是权威——复述它们=缓存一笔查询，**只缓存查不到的东西**（约定、缘由、坑）。
- 官方文档页统一骨架（可借鉴到知识库写作）：What it does / When to reach for it（含反指示）/ Common questions（真实用户报告的坑）/ It's working if（可验证的成功判据）。

## 8. 官方诚实暴露的已知 bug（选录，源自各 docs 页 Common questions）

1. research 后台 agent 会再 spawn 后台 agent（#530：单任务 450k token 三重跑）——盯后台任务列表手动杀。
2. code-review 的 subagent 可能再调 /code-review 扇出（见过 50+ agent）。
3. ask-matt 对 16 个 user-invoked 技能误报「未安装」。
4. tdd 的 seam 提示只报名字不给取舍（#607）——解法：to-spec 阶段就把 seam 议定。
5. grilling 的 frontier 由模型判断非图计算，可能把有依赖的两问放同轮——防线是你指出来。
6. wayfinder 的 agent 会在自己写的 Notes 里给自己开「带执行」的口子——接手别人的 map 先读 Notes。
7. domain-modeling 被别的技能拉起时常被跳过（grilling 跑完 GLOSSARY 未变即是征兆），需点名调用。

## 9. 与本机体系对照

- 本机已装其 23 个技能（engineering 17＋productivity 6），`~/.agents/skills` 双 harness 共享；本机此前**未跑过 `/setup-matt-pocock-skills`**——triage/to-spec/to-tickets 等依赖 `docs/agents/` 配置的技能在 manbo 上不可用，要用先跑 setup（勿在 manbo 主仓试，web/ 目录有独立 tracker 语义）。
- 印证：grilling＝全局规则「意图澄清模板」的工程化完整版；retro「AGENTS.md 不堆规则/标准给 reviewer」＝`agents-md-best-practices.md` 同结论；`git-pr-description` 技能可借鉴 pr 的 door call（one-way/two-way door 判定进 PR 描述）；GLOSSARY/ADR 共享语言对 manbo（中文注释＋🌟坑标）是增量实践，未采用、仅记录。
- 两套规范驱动对比：OpenSpec 的 delta/主规格是**产物中心**（文档即闸门），Matt 链路是**对话中心**（issue tracker 为真源、spec 是 issue）。manbo 现用 OpenSpec，不迁移。

## 10. 参考链接

- 仓库：<https://github.com/mattpocock/skills>（docs/ 目录＋ CHANGELOG 为本文来源）
- 每技能文档页：<https://aihero.dev/skills-<skill-name>>
- 安装：Claude Code 插件自更新；其余 `npx skills@latest add mattpocock/skills -a <agent>`（装后每仓库跑 `/setup-matt-pocock-skills`）
