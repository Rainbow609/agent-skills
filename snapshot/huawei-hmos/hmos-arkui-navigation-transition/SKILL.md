---
name: hmos-arkui-navigation-transition
description: 指导开发者为 ArkUI Navigation/NavDestination 配置转场动画。当用户提到 Navigation 转场、NavDestination 转场、转场动画、systemTransition、customTransition、customNavContentTransition、disableAnimation、页面跳转动画、禁用转场、自定义转场、可交互转场、系统转场等关键词时，务必使用此 skill。也适用于用户想要在鸿蒙应用中实现页面切换动画效果的场景，即使没有明确提到具体 API 名称。
---

# ArkUI Navigation/NavDestination 转场动画 Skill

本 skill 指导开发者为 Navigation/NavDestination 配置转场动画，帮助开发者从 systemTransition、customTransition、customNavContentTransition、disableAnimation 四类方案中选型并接入。

## 场景分流决策树

当开发者请求配置转场动画时，按以下三级决策树进行分流。每级以 API 归属（NavDestination/Navigation）+ 需求语义（禁用/系统/自定义/交互）判定。

```
开发者输入：文件路径 + 转场需求描述
  │
  ├─ 能否定位 NavDestination/Navigation 组件？需求是否与转场动画相关？
  │    ├─ 否 → 异常处理（见「异常输入处理」段）
  │    └─ 是 → L1：禁用 vs 启用
  │         ├─ 需求含「禁用」「关闭」「不要转场」→ 禁用分支（disableAnimation）
  │         │    ├─ 作用域为 NavDestination → 单页禁用（AC-5.1）
  │         │    └─ 作用域为 Navigation → 全局禁用（AC-5.2）
  │         └─ 需求为配置转场 → L2：页面级 vs 整体
  │              ├─ 容器为 Navigation、需求含「可交互」或「转场中响应」
  │              │    → 整体可交互（customNavContentTransition）（AC-4.1）
  │              ├─ 容器为 Navigation、无交互诉求
  │              │    → 提示整体方案通常用于可交互场景，询问是否需要页面级
  │              └─ 容器为 NavDestination → L3：系统 vs 自定义
  │                   ├─ 需求含「系统」「自带」→ 系统转场（systemTransition）（AC-2.1）
  │                   └─ 需求含「自定义」或排除系统 → 自定义转场（customTransition）
  │                        ├─ 含交互诉求 → 引导至 customNavContentTransition（AC-3.2）
  │                        └─ 无交互诉求 → 页面级自定义（AC-3.1）
```

### 四类分流定义

| 分流类别 | 归属组件 | 对应 AC | 决策树层级 |
|---|---|---|---|
| 页面级 systemTransition | NavDestination | AC-2.1 | L3（系统转场） |
| 页面级 customTransition | NavDestination | AC-3.1 / AC-3.2 | L3（自定义转场） |
| 整体 customNavContentTransition | Navigation | AC-4.1 | L2（整体可交互） |
| 禁用 disableAnimation | NavDestination / Navigation | AC-5.1 / AC-5.2 | L1（禁用分支） |

## 反模式警告：pageTransition ≠ customTransition

> **此节为生成代码前的强制检查项，违反会导致编译错误 `ArkTS:10505001`。**

`pageTransition()` 和 `customTransition(delegate)` 是两个完全不同的 API，**禁止混用**：

| | `pageTransition()` | `customTransition(delegate)` |
|---|---|---|
| **归属** | `CustomComponent` 生命周期方法（`@Entry`/`@Component` 基类） | `NavDestination` 链式属性方法 |
| **签名** | `pageTransition?(): void` — 无参数，无返回值 | `customTransition(delegate: NavDestinationTransitionDelegate): NavDestinationAttribute` |
| **用途** | **已废弃**的 router 页面转场（`PageTransitionEnter`/`PageTransitionExit`） | Navigation/NavDestination 自定义转场（`NavDestinationTransition` 数组） |
| **调用方式** | 在 `@Entry` struct 内覆写方法体 | 在 `NavDestination() {}` 后链式调用 `.customTransition(delegate)` |

**禁止写法（触发编译错误）：**

```typescript
// ❌ 错误：在 struct 中定义 pageTransition 方法并使用 NavDestinationTransitionDelegate 签名
@Component
struct ProductDetail {
  // 编译错误 10505001: pageTransition 签名必须是 () => void，
  // 不能是 (operation, isEnter) => Array<NavDestinationTransition> | undefined
  pageTransition(operation: NavigationOperation, isEnter: boolean): Array<NavDestinationTransition> | undefined {
    // ...
  }
}
```

**正确写法：**

```typescript
// ✅ 正确：customTransition 是 NavDestination 的链式属性方法，delegate 作为参数传入
@Component
struct ProductDetail {
  build() {
    NavDestination() {
      // 页面内容
    }
    .customTransition(this.customTransitionDelegate)  // 链式调用，不是方法覆写
  }

  // delegate 是 private 属性/箭头函数，不是名为 pageTransition 的方法
  private customTransitionDelegate = (operation: NavigationOperation, isEnter: boolean): Array<NavDestinationTransition> | undefined => {
    // 返回动画配置或 undefined
  }
}
```

**生成代码前的自检规则：**
1. 检查生成的代码中是否出现名为 `pageTransition` 的方法 — **如果出现，必须删除或改名**
2. `NavDestinationTransitionDelegate` 签名的函数只能通过 `.customTransition(delegate)` 链式调用传入，不能作为 struct 方法覆写
3. `pageTransition` 已废弃，本 skill 场景下不应在任何生成的代码中使用此方法名

## 反模式警告：通用属性名不可用作 struct 成员名

> **此节为生成代码前的强制检查项，违反会导致编译错误 `ArkTS:10505001`。**

ArkUI 通用属性（`CommonAttribute`/`CommonMethod` 上的方法）名称在 `@Component`/`@Entry` struct 中是**保留**的。在 struct 内声明同名成员变量（`@State`/普通属性）会与基类 `CustomComponent` 的同名方法签名冲突，触发编译错误：

```
Property '<name>' in type 'X' is not assignable to the same property in base type 'CustomComponent'.
Type '<member type>' is not assignable to type '{ (value: ...): CommonAttribute; ... }'.
```

转场动画场景下最容易踩坑的保留名（开发者常据此命名动画驱动状态变量）：

| 保留名 | 通用属性签名（节选） | 错误成员写法示例 |
|---|---|---|
| `scale` | `(value: ScaleOptions): CommonAttribute` | `@State scale: number = 1` |
| `opacity` | `(value: number \| Resource): CommonAttribute` | `@State opacity: number = 1` |
| `translate` | `(value: TranslateOptions): CommonAttribute` | `@State translate: TranslateOptions` |
| `rotate` | `(value: RotateOptions): CommonAttribute` | `@State rotate: number = 0` |
| `position` | `(value: Position): CommonAttribute` | `@State position: Position` |
| `offset` | `(value: Position): CommonAttribute` | `@State offset: number = 0` |
| `transform` | `(value: object): CommonAttribute` | `@State transform: object` |
| `visibility` | `(value: Visibility): CommonAttribute` | `@State visibility: number = 0` |
| `zIndex` | `(value: number): CommonAttribute` | `@State zIndex: number = 0` |

> 其余 `CommonAttribute` 方法名（`width`/`height`/`margin`/`padding`/`border`/`backgroundColor` 等）同样保留，完整集合以 ArkUI `.d.ts` 中 `CommonAttribute`/`CommonMethod` 声明为准。

**禁止写法（触发编译错误）：**

```typescript
// ❌ 错误：成员名 scale/opacity 与 CustomComponent 基类通用属性方法冲突
@Component
struct FeedbackPage {
  @State scale: number = 1        // 10505001: number 不可赋给 (value: ScaleOptions) => CommonAttribute
  @State opacity: number = 1      // 10505001: number 不可赋给 (value: number | Resource) => CommonAttribute

  build() {
    // ...
    .scale({ x: this.scale })
    .opacity(this.opacity)
  }
}
```

**正确写法：**

```typescript
// ✅ 正确：给成员名加业务/组件语义前缀，避开保留名
@Component
struct FeedbackPage {
  @State cardScale: number = 1
  @State cardOpacity: number = 1

  build() {
    // ...
    .scale({ x: this.cardScale })
    .opacity(this.cardOpacity)
  }
}
```

**生成代码前的自检规则：**
1. 检查生成的 struct 成员名是否命中 ArkUI 通用属性保留名（上表 + `width`/`height`/`margin`/`padding`/`border`/`backgroundColor` 等全部 `CommonAttribute` 方法名）— **命中则改名**
2. 命名建议：用业务或组件语义做前缀（`cardScale`/`titleOpacity`/`bgTranslate`），或加后缀（`scaleValue`/`opacityState`）
3. 此规则对所有 `@Component`/`@Entry` struct 通用；转场动画因频繁操作 `scale`/`opacity`/`translate`/`rotate` 尤其易踩坑，生成动画驱动状态变量时务必先核对保留名表

## 异常输入处理

当开发者输入满足以下任一条件时，输出明确的无法处理提示并请求补充输入，不臆造配置方案：

1. **文件路径不存在** — 提示「文件路径 `xxx` 不存在，请提供有效的 .ets 文件路径」
2. **文件中未找到 NavDestination/Navigation 组件** — 提示「文件中未找到 NavDestination/Navigation 组件，请提供包含这些组件的文件」
3. **需求描述为空** — 提示「请提供转场动画需求描述（如配置系统转场、自定义转场、禁用转场等）」
4. **需求与转场动画无关** — 提示「需求描述与转场动画无关，请提供与 Navigation/NavDestination 转场动画相关的需求」

## 能力调度

根据分流结果，调度对应能力段。每段引用 references 中的 API 签名和 templates 中的框架代码模板。

### 1. systemTransition 系统转场（AC-2.1）

当分流为页面级 systemTransition 时：

1. 确认开发者指定的 systemTransition 枚举值（或默认值 DEFAULT）
2. 输出 `.systemTransition(枚举值)` 配置方案，接入位置在 NavDestination 组件声明上
3. 枚举取值以 `references/navigation-transition-api.md` 中核对的 .d.ts 枚举值为准
4. 提供对应模板 `templates/systemTransition.ets` 作为参考

**枚举值速查：**

| 枚举值 | 说明 | @since |
|---|---|---|
| DEFAULT | 默认系统转场动画 | 14 |
| NONE | 无系统转场动画 | 14 |
| TITLE | 标题栏系统转场动画 | 14 |
| CONTENT | 内容区系统转场动画 | 14 |
| FADE | 渐变类型 | 15 |
| EXPLODE | 中心缩放类型 | 15 |
| SLIDE_RIGHT | 右侧平移类型 | 15 |
| SLIDE_BOTTOM | 底部平移类型 | 15 |

详细 API 签名请阅读 `references/navigation-transition-api.md` 的 systemTransition 章节。

### 2. customTransition 自定义转场（AC-3.1 / AC-3.2）

当分流为页面级 customTransition 时：

**无交互诉求（AC-3.1）：**

1. 生成返回 `NavDestinationTransition` 数组的框架代码
2. 代理函数签名为 `(operation: NavigationOperation, isEnter: boolean) => Array<NavDestinationTransition> | undefined`
3. 提供对应模板 `templates/customTransition.ets` 作为参考

**含交互诉求（AC-3.2）：**

1. 显式提示「customTransition 不可交互，customTransition 是页面级转场，无法在转场过程中响应交互」
2. 引导开发者使用整体可交互转场接口 `customNavContentTransition`（指向下方第 3 节）
3. 不静默生成不可交互方案
4. 提供对应模板 `templates/customNavContentTransition.ets` 作为参考

详细 API 签名请阅读 `references/navigation-transition-api.md` 的 customTransition 章节。

### 3. customNavContentTransition 整体可交互转场（AC-4.1）

当分流为整体 customNavContentTransition 时：

1. 生成 `NavigationAnimatedTransition` 框架代码
2. 框架包含 `transition` 回调（接收 `NavigationTransitionProxy` 参数，proxy 含 `from`/`to` 页面信息）
3. 给出 transition 注册建议：
   - **方式1 — 全局注册**：在 Navigation 组件上直接配置 `customNavContentTransition` 回调，所有 NavDestination 页面共用。适合统一转场效果
   - **方式2 — 单例可访问**：用单例工具类管理各页面动画回调（`onReady` 注册、`aboutToDisappear` 注销），Navigation 级回调中查找分发。适合不同页面不同动画
   - **方式3 — 手势驱动可交互**：`isInteractive: true` 时，`transition` 回调将 `proxy` 存入单例（不播 animateTo），由 NavDestination 页面的 `PanGesture` 驱动转场进度。`onActionStart` 触发 push/pop，`onActionUpdate` 调用 `proxy.updateTransition(progress)`，`onActionEnd` 根据 progress 阈值调用 `proxy.finishTransition()` 或 `proxy.cancelTransition()`。适合手势返回、拖拽切换等场景
   - 取舍：方式1 简洁但灵活性低；方式2 灵活但需管理生命周期；方式3 实现 `isInteractive: true` 的核心交互能力，必须配合方式2 的单例使用
4. 提供对应模板 `templates/customNavContentTransition.ets` 作为参考（含方式1/2/3 完整代码）

> **手势驱动关键提醒：** `isInteractive: true` 时 `transition` 回调 **不可** 用 `animateTo` 播放完整动画（否则手势无法逐帧驱动）。正确做法是将 `transitionProxy` 存入单例，由 NavDestination 页面的 `PanGesture.onActionUpdate` 调用 `proxy.updateTransition(progress)` 逐帧更新进度。

> **优先级说明：** 同时设置 `customNavContentTransition`（Navigation 级）和 `customTransition`（NavDestination 级）时，Navigation 级优先。

详细 API 签名请阅读 `references/navigation-transition-api.md` 的 customNavContentTransition 章节。

### 4. disableAnimation 禁用转场（AC-5.1 / AC-5.2）

当分流为禁用 disableAnimation 时：

**单页禁用（AC-5.1）：**

1. 输出 NavDestination `disableAnimation` 单页禁用配置指导
2. 作用域为单页（NavDestination），与全局禁用明确区分
3. 通过 `NavPathStack.disableAnimation(true)` 控制

**全局禁用（AC-5.2）：**

1. 输出 Navigation `disableAnimation` 全局禁用配置指导
2. 作用域为全局（Navigation），影响所有页面跳转
3. 通过 `NavPathStack.disableAnimation(true)` 控制

> **单次禁用替代方案：** 如果只需要单次跳转禁用动画，可在 `pushPath`/`pop` 等方法中传 `animated: false` 参数，无需全局禁用。

详细 API 签名请阅读 `references/navigation-transition-api.md` 的 disableAnimation 章节。

## 工作流程

当开发者请求配置转场动画时，按以下流程工作：

1. **收集输入** — 获取文件路径和转场需求描述
2. **异常检查** — 验证文件存在性、组件存在性、需求相关性
3. **场景分流** — 按三级决策树判定四类分流
4. **输出方案** — 根据分流结果调度对应能力段，输出配置方案/框架代码/配置指导
5. **交互引导** — customTransition 含交互诉求时显式提示并引导

## 参考资源

| 资源 | 路径 | 说明 |
|---|---|---|
| API 参考 | `references/navigation-transition-api.md` | 四类 API 的完整签名、枚举值与官方指南条目 |
| systemTransition 模板 | `templates/systemTransition.ets` | `.systemTransition(枚举)` 配置方案模板 |
| customTransition 模板 | `templates/customTransition.ets` | 返回 `NavDestinationTransition` 数组的自定义转场框架模板 |
| customNavContentTransition 模板 | `templates/customNavContentTransition.ets` | `NavigationAnimatedTransition` 整体可交互转场框架模板 |
| disableAnimation 模板 | `templates/disableAnimation.ets` | 单页/全局 `disableAnimation` 配置模板 |
