# 自绘组件与虚拟节点（accessibilityVirtualNode，API 11+）

## 适用（F 类诉求）

Canvas/自绘内容**整块区域绘制**，没有单个节点可以承载语义，读屏完全读不到（如折线图、仪表盘、棋盘）。

## 方案

用 `accessibilityVirtualNode` 在自绘组件上挂**虚拟子节点**承载无障碍语义；辅助工具读取的是
**虚拟节点的语义**，而不是实际绘制内容。

```ts
@Builder
customAccessibilityNode() {
  Column() {
    Text('当前数据趋势：上升趋势，峰值 92')   // 语义节点，按需拆分粒度
      .accessibilityText('折线图：最近 7 天数据，趋势上升')
  }
}

Canvas(this.context)
  .onReady(() => {
    // ...原有绘制逻辑，保持不变
  })
  .accessibilityVirtualNode(() => {
    this.customAccessibilityNode();
  })
```

## 约束（源码级 + SDK 实测）

- value **直传 @Builder 回调函数**——不要包成 `{ builder: ... }` 对象，对象包裹会编译报错
  `'builder' does not exist in type '() => any'`（DevEco 260 API 26 SDK 首编实测，2026-10 评测 vod-3）；
- 虚拟节点内的组件按基础属性规则适配（无文本组件加 accessibilityText 等）；
- 下限 API 11：build-profile 三字段任一 < 11 → 阻断并给提升建议（如
  `compatibleSdkVersion: 10 → 11`），不生成无法编译的代码；字段缺失 → 请求补充，不臆测。

## 粒度建议

| 自绘内容 | 虚拟节点组织 |
|----------|--------------|
| 单一整体（装饰图） | 1 个虚拟节点 + 1 条语义文本 |
| 有结构的数据（折线图） | 总览节点（趋势/极值）+ 可选分节点（各数据段） |
| 可交互区域（棋盘） | 按交互区域拆分节点，节点内可加自定义动作（accessibilityCustomActions） |

来源：注册 `frameworks/bridge/declarative_frontend/jsview/js_view_abstract.cpp:10453`；
解析 `js_accessibility.cpp:175-193`；下限 API 官方文档（中可信）。
