---
name: hmos-arkui-accessibility-skill
description: Guides ArkUI/HarmonyOS screen-reader accessibility adaptation — routes demands to accessibilityText/Description/Group/Level/Checked/Selected/VirtualNode and focus attributes, enforces semantic guardrails and build-profile.json5 API version gating. Use when the user mentions 接入/适配无障碍, 读屏/屏幕朗读, 播报文本, 聚合播报, 自定义走焦/首焦点, Canvas 自绘内容读屏读不到, or works on .ets files involving accessibilityGroup, accessibilityChecked, accessibilityVirtualNode, onAccessibilityHover/Focus, or accessibility compile errors.
license: MIT
metadata:
  version: "1.1.0"
---

# ArkUI 通用无障碍快速接入 Skill

帮助开发者为 ArkUI 应用快速、正确地适配无障碍能力（屏幕朗读等辅助技术）。

## 核心工作流（必须按序执行）

### 第 0 步：D0 默认能力门（先判"要不要适配"）

ArkUI 默认已支持屏幕朗读，自动播报四要素：**组件类型、文本内容、操作结果、当前状态**。
有文本内容的标准组件（如 Button：朗读"按钮，提交订单，单指双击即可执行"）**无需适配**。

- 开发者诉求**泛化**（如"要从哪里开始适配无障碍"）：先输出 D0 门说明——默认播报四要素、
  需要额外适配的边界（无文本图标/图片、自绘内容、需显式状态语义、聚合/走焦等高阶诉求）、
  无障碍可达三前提（可识别、功能及操作信息、状态与行为）——然后**明确询问**默认能力是否满足，
  此时**不直接生成属性代码**。
- 诉求**明显超出**默认能力（如"图标读屏听不出是干嘛的"）：跳过 D0，直接进入第 1 步路由
  （如无文本图标 → A 无文本播报）。
- 默认可满足：明确告知"已默认适配，无需额外设置"，**不输出多余属性代码（避免过度适配）**，收尾。

### 第 1 步：诉求路由（A~G）

| 诉求 | 开发者会怎么说 | 属性 | 下限 API |
|---|---|---|---|
| D0 | 默认屏幕朗读够用吗？ | 无需适配 | — |
| A 让无文本元素能读懂 | "图标按钮读屏听不出是干嘛的" | `accessibilityText` | 12 |
| B 说明操作后果 | "聚焦只播'单指双击即可执行'太含糊" | `accessibilityDescription` | 10 |
| C 整组朗读降噪 | "日期三个 Text 分开读，很碎" | `accessibilityGroup(true)` | 12 |
| D 控制可识别性 | "关键操作要能被聚焦 / 装饰元素别读出来" | `accessibilityLevel`（`auto`/`yes`/`no`/`no-hide-descendants`；auto 决策指引见第 3 步规则 5） | 12 |
| E 传达选中状态 | "复选框/单选项读不出选没选" | `accessibilityChecked`（二态/三态）/ `accessibilitySelected`（互斥单选） | 13 |
| F 自绘制组件读屏 | "Canvas/自绘内容读屏读不到" | `accessibilityVirtualNode` | 11 |
| G 自定义走焦 | "自定义首焦点 / 下一个获焦焦点" | `accessibilityDefaultFocus` / `accessibilityNextFocusId` | 18 |

路由判定后**说明判定依据**（对应开发者原话）。组合诉求（如 A+E、C+D+A）一次落齐，不留半成品。
详表与对比见 `references/decision-matrix.md`。

### 第 2 步：API 版本门禁（涉及有下限的属性时必做）

读取工程 `build-profile.json5` 三字段：`compileSdkVersion` / `compatibleSdkVersion` / `targetSdkVersion`：

- 任一字段 **低于属性下限** → 阻断该属性路径：说明需 API X+，给出提升字段的具体修改建议，
  **不生成无法编译的代码**。
- 字段缺失/文件缺失 → 请求开发者补充版本信息，不臆测放行。
- 焦点类（API 18+，如 accessibilityDefaultFocus/NextFocusId/onAccessibilityFocus）：对满足版本的工程
  仅做版本软提示，不阻断。
- 事件回调版本差异：`onAccessibilityHover` 需 12+，`onAccessibilityFocus` 需 18+，逐方法标注。

### 第 3 步：语义硬规则（输出前强制自检）

1. **A/B 职责边界**：`accessibilityText` = 是什么（功能简述）；`accessibilityDescription` = 点了会怎样
   （操作后果/不可用原因）。text 中不放操作引导与状态信息。
2. **覆盖语义（强制确认）**：组件既有文本又设 `accessibilityText` 时，**原文本不再播报**。
   就地修改既有文本组件前，必须先向开发者提示该后果并取得确认，未确认前不修改。
3. **替代语义**：`accessibilityDescription` 替代系统默认新手提醒；用户关闭新手提醒开关后
   description 也不播报——不能承诺"必达"。
4. **checked vs selected**：checked = 控件物理状态（二态/三态，Checkbox/Toggle）；
   selected = 互斥单选当前项（List/Tabs）。输出对比表（见 decision-matrix）。
5. **level 取值与 auto 决策指引**：仅 `auto` / `yes` / `no` / `no-hide-descendants`（`no` 只隐藏当前节点，
   `no-hide-descendants` 连同后代隐藏；源码级枚举，无 `default` 值）。`auto` 决策指引：
   - **支持场景**：组件无确定性聚焦/隐藏诉求、维持系统默认行为时，可建议 `auto`，并说明其语义
     ——由无障碍服务与 ArkUI 按组件类型和内容综合判断，**不保证聚焦或隐藏结果**；
   - **不支持场景**：诉求为"关键操作必须可聚焦"、"元素必须不播报"等**确定性要求**时，
     **不输出 `auto` 方案**，改给 `yes` / `no` / `no-hide-descendants` 显式取值建议；
   - **必传信息**：向开发者明确传递"`auto` 结果不确定，确定性诉求须使用显式取值"。
6. **反 group**：group 后组内某组件仍需单独朗读 → 该组件 `accessibilityLevel('yes')`。
7. **播报优先级**：`accessibilityText` 不为空时朗读无障碍文本，否则朗读显示文本。
8. **文案质量**：text 支持字符串或资源引用，简洁达意。

### 第 4 步：输出模式（按开发者意图）

- **方案模式**：输出适配方案 + 改前/改后播报差异说明，不改文件。
- **就地模式**：目标唯一明确时在原属性链上**追加**属性，保留既有属性/样式/事件链，
  展示改动说明与路由依据，不改无关文件。
- 意图不明 → 追问确认模式。

### 第 5 步：信息不足时追问

缺组件类型、缺诉求、缺 build-profile 版本字段时，针对缺失项追问（限定在无障碍适配必需信息内），
不输出臆造方案。

## 知识库索引（references/）

| 文件 | 内容 | 何时读 |
|------|------|--------|
| `references/api-facts.md` | 属性/事件事实表（签名/下限 API/来源） | 任何属性用法输出前 |
| `references/decision-matrix.md` | A~G 详表、checked/selected 对比、反 group、组合诉求、组件类别接口选择 | 路由判定与组合诉求 |
| `references/group-dynamic-announcement.md` | 聚合播报与动态播报（sendAccessibilityEvent） | C 类诉求/动态更新 |
| `references/event-and-focus.md` | 事件响应（hover/focus）与自定义走焦 | 事件回调/走焦诉求 |
| `references/virtual-node.md` | Canvas/自绘虚拟节点方案 | F 类诉求 |
| `references/faq-vod.md` | 已知缺陷与编译报错答疑 | text 不生效/编译报错 |

## 代码模板（templates/）

- `templates/basic_attributes_template.ets` — A/B/D/E 基础属性组合
- `templates/group_announcement_template.ets` — C 聚合 + 反 group
- `templates/event_focus_template.ets` — 事件回调 + 走焦 + 动态播报
- `templates/virtual_node_template.ets` — F 虚拟节点

输出代码时以模板为基线，按第 2/3 步做版本与语义适配。

## 输出前检查清单

- [ ] D0 门：泛化诉求先说明默认能力并询问，未确认前不生成代码；默认可满足时零属性收尾
- [ ] 版本门禁：涉下限属性已读 build-profile.json5 三字段，任一低于下限即阻断并给字段提升建议
- [ ] A/B 职责：text=是什么、description=点了会怎样，text 中无操作引导与状态信息
- [ ] 覆盖语义：既有文本组件设 text 前已提示"原文本不再播报"并取得确认
- [ ] checked/selected：物理状态用 checked、互斥单选用 selected，未混用
- [ ] level 取值：确定性诉求未输出 auto，使用 yes/no/no-hide-descendants 显式取值
- [ ] 组合诉求（如 A+E、C+D+A）一次落齐，无半成品
- [ ] 输出模式符合开发者意图（方案/就地/追问），就地模式保留原属性链与无关文件
