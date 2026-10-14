# 已知缺陷与编译报错答疑（vod）

> 需求方 vod 记录 + 本仓源码核验结论。答疑时先判版本，再给结论。

## vod-1：AccessibilityText 不生效

**现象**：Search 组件和 Toggle 组件设置 `accessibilityText` 属性后不生效（播报仍为默认内容）。

**排查路径**（按序）：

1. **版本**：accessibilityText 需 API 12+，核对 build-profile 三字段；
2. **覆盖语义**：确认没有同节点更晚设置的同名属性或组件内部文本优先级场景；
3. **组件特化实现**：多数组件在各自 pattern 下有 `*_accessibility_property.h` 特化（KB 路由
   `docs/kb/architecture/accessibility.md`），Search/Toggle 的特化实现决定最终播报内容；
   特化组件上通用属性表现以当前版本源码为准；
4. **规避**：若特化组件不满足诉求，可用相邻容器承载语义（容器加 accessibilityText）或
   accessibilityDescription 补充，必要时反馈缺陷单。

**状态**：需求方 vod 在案（缺陷链接见 proposal_full.md vod 表）；Skill 输出答疑口径如上，
不承诺平台侧修复时间。

## vod-2：accessibilityStateDescription 编译报错

**现象**：开发者使用 `accessibilityStateDescription`，编译报错"接口未暴露"，只有
`accessibilityDescription` 可用。

**结论**：

- **版本门槛**：`accessibilityStateDescription` 为较新接口；旧版本 SDK 的 d.ts 未暴露会导致编译报错。
- **master 现状**：本仓 master 已注册该入口
  （源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10469-10470`，
  解析 `js_accessibility.cpp:128-137`），报错发生在**低于该接口起始版本的 SDK**。
- **处理**：
  1. 核对 build-profile 三字段，低于起始版本 → 提升版本或改用 `accessibilityDescription`（API 10+）替代；
  2. 注意替代差异：description 定位"操作后果/详细说明"且会替代新手提醒，stateDescription 定位"状态描述"，
     语义不同，替代时向开发者说明播报差异。

## vod-3：三处签名致首编失败（DevEco 260 / API 26 SDK 实测，2026-10 评测）

**现象**：按旧事实表输出代码，5 个页面首次编译报 7 个错误：

1. `Checkbox` 上 `.onSelect(...)` → `Property 'onSelect' does not exist on type 'CheckboxAttribute'`
   **正解**：Checkbox 状态同步用**受控三要素**——`@State` + `.select(state)` + `.onChange(cb)`，
   再挂 `.accessibilityChecked(state)`；
2. `.accessibilityVirtualNode({ builder: () => {...} })` → `'builder' does not exist in type '() => any'`
   **正解**：参数**直传 @Builder 函数** `.accessibilityVirtualNode(() => { this.node(); })`；
3. `.onAccessibilityHover((event: AccessibilityHoverEvent) => {...})` → 参数类型不兼容
   （`boolean` 不能赋给 `AccessibilityHoverEvent`）
   **正解**：回调为**双参数** `(isHover: boolean, event: AccessibilityHoverEvent) => {...}`。

**结论**：三处均已回写 `api-facts.md` / `virtual-node.md` / `event-and-focus.md` / 相关 templates；
后续输出以修订后事实表为准。事实表与其余 SDK 版本的差异，按"通用答疑模式"核对该版本 d.ts。

## 通用答疑模式（US-6：为什么编译报错）

1. 读报错中的属性名 → 查 `api-facts.md` 下限 API；
2. 读 build-profile 三字段；
3. 任一低于下限 → 给"提升字段"具体修改建议（不生成无法编译代码）；
4. 字段满足仍报错 → 引导查看 SDK 版本实际包含的 d.ts，或反馈缺陷单。
