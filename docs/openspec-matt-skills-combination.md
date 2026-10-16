# OpenSpec × Matt Skills 结合实践

> **来源**：mattpocock/skills 官方 Discussion [#285「How does it compares to openspec or other spec driven frameworks?」](https://github.com/mattpocock/skills/discussions/285)（2026-05 提问、2026-09 代表性回答）＋ 两边官方文档全量精读（见 [`openspec-official-guide.md`](./openspec-official-guide.md) 与 [`matt-pocock-skills-guide.md`](./matt-pocock-skills-guide.md)）。
> **复核**：2026-10-16。#285 为一手讨论（dexhunter 方案原文引用）；Reddit 同题帖（r/claudeskills "Matt Pocock, Superpowers, OpenSpec — do you pick one?"）正文被反爬挡住，仅证明困惑普遍，未采信内容；「冲突面清单」与「结合模式」为本仓基于两套官方文档的分析性结论（标注为分析，非官方）。
> **适用前提**：截至 2026-10 社群实践仍少（无专门 bridge schema）；若后续出现成熟集成方案应更新本文。

## 1. 官方立场：互不集成

- 两边文档**互不提及对方**。OpenSpec 的社区 schema 列表（intent-driven、superpowers-bridge、nanopm、e2e-runbooks、anvil、ml-research）没有 matt skills；matt 的 README 只点名 GSD / BMAD / Spec-Kit 为「接管过程」的反面，未点名 OpenSpec。
- 各自的官方扩展面：OpenSpec = `openspec schema fork` ＋ 社区 schema 平权复制；matt = 「Hack around with them. Make them your own」（技能可改可组，SCOPE 明确拒绝代客集成类新技能提案）。**粘合是用户自己的事**。

## 2. 社群实况

Discussion #285 的三个声音：

1. **提问者**（OpenSpec 用户）：这技能集是替代还是互补？并指出 OpenSpec 与 GSD/BMAD/Spec-Kit 不同、并不锁死流程（「The OpenSpec process doesn't force this. Unlike GSD, BMAD or Spec-Kit.」）。
2. **BurtHarris**：对比 Spec-Kit，matt 技能「更轻量、更敏捷」，适合独立开发者。
3. **dexhunter**（2026-09，代表性结合方案，原文要点）：
   - OpenSpec 保留 proposal / specs / design / tasks 且无刚性阶段门 → 其 README 立场支持「不锁流程」；
   - 承认**重叠区**：`/to-spec`（spec 发布到 issue tracker）与 `/to-tickets`（拆票）覆盖了 OpenSpec proposal 与 tasks 生成的同一地盘；
   - **建议**：「If OpenSpec already works for you, keep its artifacts as the authoritative plan. Use `/grill-with-docs` to clarify decisions, carry those decisions into your OpenSpec proposal/design, then continue its implementation and archive workflow. You can adopt selected skills without maintaining a second competing set of specs and tickets. That handoff is something you arrange explicitly.」

Reddit r/claudeskills 同题帖与 [intent-driven.dev 的 OpenSpec＋自定义 schema 模板](https://intent-driven.dev/blog/2026/05/10/spec-driven-development-openspec-opencode)（OpenSpec 侧深度定制路线）说明「选一个还是都要」是普遍困惑，但成熟整合方案尚未出现。

## 3. 正交性分析（为何分层成立）

| | OpenSpec | Matt Skills |
| --- | --- | --- |
| 本质 | **规格产物层**：文档即闸门（delta→主规格→archive） | **执行纪律层**：对齐/反馈/评审/环境改进的行为规范 |
| 真源 | `openspec/specs/` ＋ `changes/` | issue tracker ＋ GLOSSARY/ADR ＋ 对话 |
| 独有能力 | delta 机制、主规格演化、archive 审计轨 | grilling、tdd、code-review 双轴、retro、diagnosing-bugs、wizard |
| 重叠区 | `propose`（spec 产物）、`apply`（执行） | `to-spec`/`to-tickets`（spec/票产物）、`implement(-spec)`（执行） |

**重叠区只有上述两组；不使用 `to-spec` / `to-tickets` / `implement-spec` 即可零真源冲突**——其余 matt 技能全部与 OpenSpec 正交互补。

## 4. 三种结合模式

- **模式 A：权威计划层＋纪律层（推荐，即 dexhunter 方案）**。OpenSpec 管规格真源；matt 出纪律：`grill-with-docs` 做前置对齐（结论搬进 proposal/design）、apply 阶段驱动 `tdd`、收尾 `code-review` 双轴＋`pr` 的 door call、周期 `retro` / `improve-codebase-architecture`；`triage` 处理外来 issue。
- **模式 B：tracker 中心（不推荐）**。matt 的 issue 链路做计划真源，OpenSpec 降级为单 change 文档化工具——放弃 delta/主规格演化等于丢掉 OpenSpec 核心价值。
- **模式 C：schema 集成（DIY，工程量大）**。把 matt 的阶段做成自定义 OpenSpec schema artifact（如 `grilling`/`research` 进依赖图），或等社区 bridge schema。截至 2026-10 无人发布。

## 5. 冲突面清单（组合时必须显式裁决）

1. **spec 真源二选一**：`openspec/specs/` vs GitHub issues。模式 A 下 issues 只放外来报告（bug/feature request），规格走 OpenSpec。
2. **tasks 双轨**：用 OpenSpec `tasks.md`，不跑 `to-tickets` 拆票。
3. **grilling 结论去向**：写进 OpenSpec `design.md`（Decisions 节），不另立文档。
4. **术语分工**：`GLOSSARY.md` 放领域词，`specs/` 放行为描述；ADR「三关」（难逆转/意外性/真权衡）判据可复用于 design.md 的取舍记录。
5. **触发优先级**：两套都装后 model-invoked 触发面变宽，需在 AGENTS.md 写明（如「规格类工作优先走 OpenSpec 流程」），避免 tdd/code-review 在错误时机自动触发。

## 6. 落地示例（manbo-reader，已按模式 A 配置）

`triage` 管外来 issue → `/grill-with-docs` 增强 `/opsx-explore` 对齐环节（产出决策＋GLOSSARY/ADR 懒创建）→ 结论进 proposal/design → `/opsx-apply` 内驱动 `tdd`（pre-agreed seam 在 design 阶段议定）→ `code-review` 双轴＋PR door call → 周期 `retro`。已配好 `docs/agents/`（issue-tracker=Github Issues、五默认标签、单上下文 domain 布局）。

## 7. 参考链接

- Discussion #285：<https://github.com/mattpocock/skills/discussions/285>
- Reddit r/claudeskills 同题帖：<https://www.reddit.com/r/claudeskills/comments/1wwqyom/matt_pocock_superpowers_openspec_do_you_pick_one>（正文需登录，仅标题可证）
- OpenSpec＋自定义 schema 社区模板：<https://intent-driven.dev/blog/2026/05/10/spec-driven-development-openspec-opencode>
