# ArkTS 与 ArkUI 体系速览：定位、能力分层与文档地图

> 适用前提：查「ArkTS/ArkUI 各自是什么、能力怎么分层、文档去哪找、模拟器有什么差异」。
> 核实自官方知识库《ArkTS简介》《ArkUI简介》与概念关系 FAQ（devecocli docs，2026-10-16）。
> manbo 的 ArkTS 约束（AGENTS.md 节）即「TS→ArkTS 适配规则」的项目化子集，源头见下。

## 三者关系（概念澄清）

| 层 | 是什么 | 职责 |
| --- | --- | --- |
| **ArkTS** | HarmonyOS 官方应用开发语言（TS 基础上强化静态检查） | 静态类型系统、业务逻辑与数据处理；语言底座 |
| **ArkUI** | 基于 ArkTS 的**声明式 UI 框架** | 界面描述、组件化构建、渲染优化；`@State/@Prop` 等响应式装饰器驱动 UI 自动同步 |
| HarmonyOS SDK/API | 系统服务层能力的封装 | 通过 `import` 调用系统能力 |

语言与框架是**底座与上层**的关系：ArkTS 提供类型安全与运行时，ArkUI 通过 DSL 扩展提升 UI 开发效率。
（manbo 惯例「状态管理 V1、路由 router、日志 hilog」都在 ArkUI/SDK 层的不同子系统里。）

## ArkTS 能力分层（查文档的目录结构）

| 子系统 | 内容 | 文档入口 |
| --- | --- | --- |
| 语言与适配 | TS→ArkTS 差异规则（**ArkTS ≠ TS 的权威清单**） | `typescript-to-arkts-migration-guide` |
| 基础类库 | Decimal 高精度数学、Buffer/FastBuffer、XML、多种容器库 | `arkts-utils-overview` |
| 并发 | **TaskPool 与 Worker 两种 API**；`Sendable` 对象跨并发实例引用传递 | `interthread-communication-overview` |
| 跨语言交互 | 与 TS/JS 高效互操作 | `arkts-cross-language-interaction` |
| 编译工具链 | 高级语言 → 方舟字节码 `.abc` | `compilation-tool-chain-overview` |
| 运行时 | 设备侧执行字节码（ArkCompiler） | `arkts-runtime-overview` / `arkts-runtime-faq` |

演进方向（官方口径）：并发能力增强、系统类型增强、分布式开发范式。

## ArkUI 能力分层（选型表）

- **两种范式**：声明式（ArkTS，**推荐**——渲染链路精简、内存占用更少、后续主推）/ 类 Web（HML+CSS+JS，老应用迁移用）。
  组合矩阵：Stage 模型 + 应用/服务页面 → 声明式（推荐）；FA 模型卡片 → 仅类 Web。
- **基本概念**：页面 = `NavDestination` 栈结构，由导航容器 `Navigation` 调度跳转/回退（manbo 用 router 属另一套旧路由，官方新推 Navigation）。
- **分层 API 选型**：
  1. 声明式开发（新项目首选）；
  2. 自定义能力四级——组合 / 扩展 `Modifier` / 自定义节点（`FrameNode`/`RenderNode`/`BuilderNode`）/ 自定义渲染；
  3. **NDK 构建 UI**（C/C++ 创建组件、操作 UI 树、设属性监听事件——适合已有 C/C++ 库对接，manbo 的 C++ 层可参考）。

## 🌟 模拟器差异（测试前必查）

**ArkTS 侧**：官方明示「**ArkTS 基础类库与 ArkTS 并发暂不支持模拟器**」——manbo 有 worker
（`ets/workers/`，TaskPool/Worker 属并发），模拟器上并发行为不可信，**并发相关验证走真机**。

**ArkUI 侧**（组件/能力不支持清单节选）：`@Preview` 装饰器、`EmbeddedComponent`、`toolbar`、
`@ohos.pluginComponent`、Image 的 enableAnalyzer 与图像 AI 分析、drawableDescriptor 的 HDR、
`restoreId` 等不支持模拟器；通用差异见「模拟器与真机的差异」。

## 文档地图（devecocli docs 检索用）

- ArkTS 规范章节：`开发指南/ArkTS_方舟编程语言/`（术语/简介/基础类库/跨语言交互/编译工具链/运行时/并发）
- ArkTS 学习章节：`开发指南/学习ArkTS语言/`（含 TS→ArkTS 适配指导系列）
- ArkUI 章节：`开发指南/ArkUI_方舟UI框架/`（简介/术语/UI开发_基于NDK构建UI/* 及各组件与状态管理子章节）
- FAQ 富矿：`FAQ/ArkTS语言/ArkTS线程模型和并发/*`（线程并发设计/通信/取消/内存共享）、
  `FAQ/UI框架/*`（组件用法与坑）
- 相关：多设备适配配方见 `harmonyos-multi-device-oneapp.md`；AbilityKit 框架入口见 `harmonyos-abilitykit-quickref.md`
