# ArkUI 无障碍 API 事实表

> 每条事实带来源。来源分两级：
> - **源码**（高可信）：本仓 `arkui_ace_engine` 注册/实现核验。
> - **官方文档**（中可信）：`interface_sdk-js` 未在本工作区检出，下限 API 与外部模块契约以公开官方文档为准
>   （arkts-universal-attributes-accessibility 开发指导/参考）。
> 维护：API 演进后按本表来源列增量核验更新；事实冲突时以源码为准并回溯修订。

## 通用属性（声明式）

| 属性 | 签名 | 下限 API | 关键语义 | 来源 |
|------|------|----------|----------|------|
| accessibilityText | `.accessibilityText(value: string \| Resource)` | API 12 | 无障碍播报文本；不为空时优先于显示文本（原文本不再播报）；组播报时作为组文本候选 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10448`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:72-80`；优先级 `frameworks/core/accessibility/utils/accessibility_property_utils.cpp:43`（GetContent）；下限 API 官方文档 |
| accessibilityDescription | `.accessibilityDescription(value: string)` | API 10 | 操作后果/详细说明；在文本后播报并**替代**系统默认新手提醒；用户关闭新手提醒后不播报 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10450`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:108-126`；替代语义官方文档 |
| accessibilityGroup | `.accessibilityGroup(value: boolean, options?: AccessibilityGroupOptions)` | API 12 | 容器聚合为单一聚焦单元整体播报；组文本=用户文本优先，否则组内文本聚合 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10447`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:32-70` |
| accessibilityLevel | `.accessibilityLevel(value: 'auto' \| 'yes' \| 'no' \| 'no-hide-descendants')` | API 12 | 可识别性控制；`no` 只隐藏当前节点，`no-hide-descendants` 连同后代隐藏；与 accessibilityImportance 等价（level 推荐） | 枚举源码 `frameworks/core/components_ng/property/accessibility_property.h:494-501`（Level 常量，无 default）；等价写入 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:170-173`；下限 API 官方文档 |
| accessibilityImportance | `.accessibilityImportance(value: 同 level 枚举)` | API 12 | 同 accessibilityLevel（历史名） | 源码等价写入 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:165-168`；下限 API 官方文档 |
| accessibilityChecked | `.accessibilityChecked(value?: boolean)` | API 13 | 二态/三态物理选中（Checkbox、Toggle）；undefined 重置并可由系统依据组件状态判断；checked 需真实状态源同步：`@State` + 受控 `.select(state)` + `.onChange()`（**Checkbox 无 onSelect 方法**，状态同步一律用 onChange） | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10456`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:211-225`；Checkbox 无 onSelect 经 DevEco 260（API 26）SDK 首编实测核验（2026-10 评测 vod-3）；下限 API 官方文档 |
| accessibilitySelected | `.accessibilitySelected(value?: boolean)` | API 13 | 互斥单选当前项（List、Tabs）；undefined 重置 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10455`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:195-209`；下限 API 官方文档 |
| accessibilityRole | `.accessibilityRole(value: Role)` | API 12 | 角色声明，读屏按角色播报组件类型 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10457`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:243-258`（枚举转 role 字符串）；下限 API 官方文档 |
| accessibilityNextFocusId | `.accessibilityNextFocusId(value: string, options?: { isConsiderDescendants?: boolean })` | API 18（isConsiderDescendants API 26） | 自定义下一获焦节点；isConsiderDescendants 控制子节点参与模式 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10449`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:87-106`；下限 API 官方文档 |
| accessibilityDefaultFocus | `.accessibilityDefaultFocus(value: boolean)` | API 18 | 页面默认读屏焦点（首焦点） | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10459`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:279-288`；下限 API 官方文档 |
| accessibilityVirtualNode | `.accessibilityVirtualNode(value: () => void)` | API 11 | 自绘内容虚拟子节点；辅助工具读取虚拟节点语义而非绘制内容；**参数直传 @Builder 回调函数**，不要包成 `{ builder: ... }` 对象（对象包裹编译报错 `'builder' does not exist in type '() => any'`） | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10453`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:175-193`；签名经 DevEco 260（API 26）SDK 首编实测核验（2026-10 评测 vod-3）；下限 API 官方文档 |
| accessibilityScrollTriggerable | `.accessibilityScrollTriggerable(value?: boolean)` | API 18 | 是否支持滑动触发滚动（可见区无可聚焦组件时屏幕朗读自动发起滚动） | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10461`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:227-241`；下限 API 官方文档 |
| accessibilityStateDescription | `.accessibilityStateDescription(value: string)` | API 18 | 状态描述补充播报 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10469-10470`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:128-137`；版本差异官方文档 |
| accessibilityCustomActions | `.accessibilityCustomActions(value: Array<{ name: string, action?: string, onAction: () => void }>)` | API 12 | 自定义读屏操作菜单；name 与 onAction 缺一不生效 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10487`、解析 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:380-429`；下限 API 官方文档 |

## 事件/方法

| 事件 | 签名 | 下限 API | 关键语义 | 来源 |
|------|------|----------|----------|------|
| onAccessibilityFocus | `.onAccessibilityFocus(callback: (isFocus: boolean) => void)` | API 18 | 读屏聚焦/失焦回调（移入/移出）；参数为聚焦状态；undefined 可取消注册 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10458`、实现 `frameworks/bridge/declarative_frontend/jsview/js_accessibility.cpp:260-277`；下限 API 官方文档 |
| onAccessibilityHover | `.onAccessibilityHover(callback: (isHover: boolean, event: AccessibilityHoverEvent) => void)` | API 12 | 开启无障碍后单指触摸组件触发（悬停探测）；**回调双参数**：isHover=触摸进入/离开布尔，event=位置等事件信息；单参数 `(event)` 写法编译报错（`boolean` 与 `AccessibilityHoverEvent` 参数不兼容）；与属性可叠加 | 源码 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10422`、实现同文件 `:11817-11824`；签名经 DevEco 260（API 26）SDK 首编实测核验（2026-10 评测 vod-3）；下限 API 官方文档 |

## 动态播报（@ohos.accessibility / @kit.AccessibilityKit）

| API | 签名 | 下限 API | 关键语义 | 来源 |
|-----|------|----------|----------|------|
| accessibility.sendAccessibilityEvent | `accessibility.sendAccessibilityEvent(eventInfo: accessibility.EventInfo): Promise<void>`（EventInfo 含 type/bundleName/triggerAction/customId 等） | API 版本以官方文档为准（外部模块） | 界面内容动态更新时辅助服务不会自动识别，需主动发送事件（如 requestFocusForAccessibility 请求聚焦抢播报） | 仓内真实用法 `advanced_ui_component/treeviewv2/source/treeviewv2.ets:1384`（导入 `:20` `import { accessibility } from '@kit.AccessibilityKit'`）；完整契约官方文档（中可信） |

## 播报优先级（组内）

读屏查询组件内容（`AccessibilityPropertyUtils::GetContent`）：
1. 用户设置文本（accessibilityText / 组文本）优先；
2. 否则取组内文本聚合（GetGroupText）。

来源：源码 `frameworks/core/accessibility/utils/accessibility_property_utils.cpp:43`。

## 事实冲突处理

Skill 输出与事实表冲突时，以事实表为准并回溯修订知识库；发现事实表与最新源码/官方文档冲突时，
停止输出生成，提示维护者更新事实表（来源列可增量核验）。
