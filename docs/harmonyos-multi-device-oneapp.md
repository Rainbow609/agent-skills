# 一次开发多端部署（一多）：架构、断点与阅读类应用配方

> 适用前提：manbo 这类「手机+平板+折叠屏+PC」多端应用做适配时查配方。
> 核实自官方知识库《一次开发，多端部署概览》《多设备新闻阅读界面》（devecocli docs，2026-10-16）；
> 案例是与本仓库最接近的官方阅读类样例。

## 三层架构与部署模型

**三层工程结构**（一多标配）：

| 层 | 内容 | 编译产物 | 依赖规则 |
| --- | --- | --- | --- |
| products（产品定制层） | 按设备/场景的 UI+资源+入口 Ability | 各子目录 = Entry HAP | 不可横向调用；**每设备类型只允许一个 Entry HAP** |
| features（基础特性层） | 独立业务模块（如首页/详情） | HAR / HSP / Feature HAP | 高内聚低耦合，互相独立 |
| common（公共能力层） | 公共 UI 组件、数据管理、工具库 | **HAR** | 只被上层依赖，不可反向依赖 |

**部署模型 A/B（经验模型，非官方术语）**：同泛类设备（手机+平板+折叠屏）优先 A＝一次编译出**相同** HAP（靠一套布局自适应）；
不同泛类（加 PC/车机/穿戴）优先 B＝出**不同** HAP。实际常混合。判据：屏幕尺寸/输入方式/交互距离。
manbo 现状＝模型 A（单 entry 覆盖手机+平板，reader-kit HAR 相当于 common 层职能的外置模块）。

**SysCap（功能级一多）**：工程默认要求能力集＝多设备能力集**交集**，联想集＝**并集**；
只有要求集是设备支持集的子集才可分发安装——这是「某接口目标设备支不支持」的机制化答案，
也是防治「开发机 OK、低端设备装不上」的正解。

## 断点与响应式布局（界面级一多）

- **断点**＝按窗口特征划分的范围：横向断点 **xs/sm/md/lg/xl**（窗口宽度），纵向断点 **sm/md/lg**（高宽比）；跨断点即改布局（单列→双列→三列）。
- 🌟 **特例：Pura X 外屏**（屏幕比例特殊）官方明示**无法一套布局适配**；优先用纵向断点/栅格适配，必要时独立 HAP；
  manbo 设备清单里有 Pura X View 模拟器，适配前先按此预案。
- **交互归一**：多种输入（触控/鼠标/键盘/遥控）统一为标准化事件，调统一接口即可。

## 阅读类应用配方（官方新闻阅读案例，manbo 可直接借鉴）

**工程切分**：products 下 `default` HAP（直板机/阔折叠/双折叠/三折叠/平板共用，靠自适应+响应式）
+ `pc` HAP（布局差异大，独立入口）；features 分 `recommendation`/`newsdetail` 两个 HAR；
common 放公共组件/常量/**窗口与断点工具**。

**窗口适配**：
- 方向策略 `setPreferredOrientation(FOLLOW_DESKTOP)`——直板机随桌面（推荐仅竖屏），大屏四方向。
- 沉浸式 `setWindowLayoutFullscreen()` + 动态安全区避让（全屏/分屏/悬浮窗通用）；
  PC 自由窗口沉浸式用 `setWindowDecorVisible()` 隐藏装饰只留右上三键。
- 监听窗口尺寸变化 → 断点刷新 UI，自动覆盖全屏/分屏/悬浮窗/自由窗口。

**首页（列表型页面）**：
- 顶部页签+搜索框：`GridRow` + `GridCol` 的 `span`/`order` 按断点切换上下/左右。
- 列表分栏：`List` 的 `lanes` 按断点 1/2/3 列；大图轮播 `Swiper` 的 `displayCount` 按断点 1/2/3。
- 页签栏：HdsTabs（`barFloatingStyle` 悬浮样式+沉浸光感材质，**不支持该材质的设备自动降级**）。

**详情页（正文+评论区，与 manbo 阅读页最像）**：
- 小屏：正文与评论区纵向堆叠统一滚动；**md 及以上断点用 `SideBarContainer` 把评论区放右侧独立滚动**
  （即「边看边评」的官方做法）。
- 底部悬浮工具栏：`Stack` 悬浮；**API 26+ 用 `systemMaterial()` 沉浸光感材质，低版本
  `backgroundBlurStyle()` 背景模糊降级**——两档材质降级是标准写法（与 manbo 的
  module.json5 UIMaterial 开关、Hds 组件同源）。
- PC 端差异：工具栏改为内嵌参与布局（不悬浮遮挡），标题栏自绘避让三键区。

## 示例代码去哪找

- 案例文档内「示例代码」链接指向官方 Sample（如「多设备新闻阅读界面」）。
- 🌟 samples 官网页面是 SPA **抓不到正文**；替代通道：**Context7 索引了官方 samples 镜像**
  （`/linganmin/harmonyos_samples`，含多设备样例，High reputation）与官方文档站全文
  （`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`）；
  文档侧仍以 `devecocli docs search` 为主，Context7 作为代码级样例检索补充。
- codelinter 有配套「一次开发多端部署」规则集（`@cross-device-app-dev/*`，如
  `one-multi-breakpoint-check` 断点检查），配 CLT 可入 CI，见 `harmonyos-deveco-studio-cli.md`。

## 官方文档（devecocli docs 检索 ID）

- 一多概览：`最佳实践/一次开发_多端部署概览/bpta-multi-device-overview`
- 多设备新闻阅读界面：`最佳实践/多设备界面开发/多设备界面开发案例/多设备新闻阅读界面/multi-news-read`
- 同系列案例（音乐/股票/图片美化/社区评论/设置/购物/地图等）同目录：`最佳实践/多设备界面开发/多设备界面开发案例/`
