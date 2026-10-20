# 鸿蒙 Next：沉浸光感材质、服务卡片硬限制、ArkWeb 登录能力

> 适用前提：做 HarmonyOS 5/6（ArkUI/ArkTS）应用时要"照官方设计做"，并要落地桌面卡片与第三方登录。
> 全文依据 developer.huawei.com 设计/开发文档与官方文档仓库 `github.com/openharmony/docs` 原文（2026-10-19 复核）；
> 官方页面为动态渲染，取不到正文的以 OpenHarmony 文档仓库同源内容为准。落地案例：AI 额度查询 App 的三版设计稿。

## 核心结论

1. **"沉浸光感"是官方术语**（设计 > 应用设计 > 通用设计基础 > 视觉风格），开发侧由
   `@ohos.arkui.uiMaterial` 的 `ImmersiveMaterial` 实现，**起始版本 26.0.0**——
   HarmonyOS 5.0/6.0 基线 SDK 没有该 API，低版本只能以"模糊材质 + 沉浸式布局"等价交付。
2. **服务卡片不能联网**，数据必须由应用侧采集后写入；刷新有硬配额（定时刷新最小 30 分钟、每日 50 次）。
3. **"高峰/平峰"这类时刻切换能做到分钟级**：用多定点刷新（API 18+，最多 24 点/天）在高峰边界布点即可，
   但只在卡片可见时触发；仅靠定时刷新就只有 30 分钟粒度。
4. **内嵌浏览器（Web 组件）不是可选项而是场景依赖**：OAuth 网页流 / Cookie 登录必须内嵌或外部回跳；
   纯 API Key、device flow、华为账号则不需要。
5. **审核红线**：应用若支持第三方账号登录，**必须同时提供华为账号登录选项**（《应用审核指南》3.16）。

## 一、沉浸光感（Immersive Light）

- 官方定义（意译）：不是光影特效升级，而是从"视觉层"到"感知层"的跃迁——界面元素是具备光学扩散与
  动态透光特性的数字介质，光感穿越层级、在层级间漫溢。用户侧有强/均衡（默认）/弱三档，系统自动映射，
  开发无需分档适配。
- 材质 5 级与场景规范：顶部悬浮 `ULTRA_THIN` + 渐变模糊；底部 `THIN` + 渐变蒙层；
  任意位置弹出 `THICK`；半模态与弹窗 `ULTRA_THICK`。
- 用法（API 26.0.0 起）：
  ```ts
  import { uiMaterial } from '@ohos.arkui.uiMaterial';
  // 组件上：.systemMaterial(new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.THIN }))
  // 可选项：materialColor / colorInvert / applyShadow / interactive / lightEffect（光感交互反馈色）
  ```
- 应用级开关（仅 entry 模块生效）：`module.json5` 的 metadata
  `{ "name": "ohos.arkui.UIMaterial.state", "value": "enable" }`；可用 `getMaterialInfo()` 读取状态。
- 低版本替代：`backgroundBlurStyle` / `foregroundBlurStyle` + 半透明背板 + 沉浸式窗口布局
  （`setWindowLayoutFullScreen`、`expandSafeArea`）。

## 二、服务卡片（Form Kit）

### 刷新机制与配额（官方原文要点）

| 机制 | 能力 | 限制 |
| --- | --- | --- |
| 定时刷新 `updateDuration` | 单位是 30 分钟（值 N = 30×N 分钟） | **最短 30 分钟**；每张卡片每天最多 50 次，0 点重置；仅卡片可见时触发 |
| 下次刷新 `setFormNextRefreshTime` | "从现在起 X 分钟后刷新" | 最短 5 分钟 |
| 定点刷新 `scheduledUpdateTime` | 精确到分钟（如 `"10:30"`），每天单点 | 配了它必须把 `updateDuration` 置 0（后者优先级更高） |
| 多定点刷新 `multiScheduledUpdateTime` | API 18+，逗号分隔，**最多 24 个时间点/天** | 覆盖单定点；同样仅可见时触发 |
| 条件刷新 `conditionUpdate: ["network"]` | 无网→有网触发 | API 18 字段（三方自 26.0.0 生效）；网络断开需连续 10 分钟才算无网；WiFi/流量互切不触发 |
| 主动刷新 | `formProvider.updateForm`；API 22 起 UIAbility 可 `reloadForms` / `reloadAllForms` | 需应用在前台运行 |

**能否在高峰起止那一刻立即切换？** 可以做到**分钟级**，不是秒级事件驱动：
把高峰边界（如 `09:00,12:00,14:00,18:00`）写进多定点刷新即可；若卡片不可见，则顺延到可见时统一刷新。
30 分钟粒度下的替代：`setFormNextRefreshTime` 把下一次刷新排在边界后 + 应用前台时主动 `updateForm` +
卡片内每次渲染时**用逻辑代码现算**"当前是否高峰"（卡片能跑 ArkTS 逻辑，但**没有 `setTimeout`**，不能自行到点重绘）。

### 其它硬约束

- **卡片不能直接联网**：卡片 UI 只能导入带"卡片能力"标记的模块，`@ohos.net.http` 没有该标记；
  卡片逻辑运行在系统 FRS 公共进程 → 数据只能由应用侧采集后 `updateForm` 写入。
- 工程限制：`form_config.json` 最多 16 张卡片/应用；不支持 HSP、native so、断点调试、卡片内左右滑动控件。
- 数据量：API 20+ 共享内存刷新数据 ≤ 10 MB、图片 ≤ 20 张；API 19 及以前图片 ≤ 5 张、每张 ≤ 2 MB。
- 尺寸档位：手机桌面 1×2（微）、2×2（小）、2×4（中）、4×4（大）；手表另有 2×3、3×3；
  锁屏 1×1（圆形）、1×2。**上架建议必含 2×2**。

### 设计规范（可直接当验收标准）

- 内容距边缘安全边距 **12vp**；设计预览圆角 1×2 / 2×2 = **18vp**、2×4 / 4×4 = **22vp**；
  **交付直角矩形**，由桌面宿主裁切；锁屏卡片裁圆形/胶囊。
- 小尺寸卡片只放 **1–2 个信息点**；按钮视觉 ≥ 24vp、**热区 ≥ 40vp**；1×2 按钮推荐 32×32vp、胶囊高 36vp。
- 深色模式：不用模糊时 Light 默认 `#FFFFFF`、Dark 默认 `#2E3033`；**锁屏卡片用单色模式**（只用透明度+模糊）。
- 隐私：快照与卡片内容须一致；卡片不放广告/运营内容；待机屏保敏感卡片加蒙层（`standby.isPrivacySensitive`）。

### 服务卡片实测坑（2026-10-19 首测，2026-10-20 补充）

- **`FormBindingData` 不要传嵌套对象/JSON 字符串**：扁平原始类型（string/number/boolean）最稳。
  实测把高峰带数据序列化成 JSON 字符串后，卡片侧取不到；改为 `band1Start/band1Width/band1State…`
  这类扁平键才通。
- **`@Builder` 按值传参不会随状态更新重绘**：卡片里用 `@LocalStorageProp` 的值必须把该段 UI 内联进
  `build()`（或 `ForEach` 直接读状态）；否则数据更新了画面仍停在初始空值，表现为"某区域恒定底色、
  无任何报错"，日志里查不出来。**普通页面同样会中招**：实测设置页把
  `@State lastSuccessMs > 0 ? fmt(...) : '从未成功'` 作为参数传给按值 `@Builder`，异步加载完成后
  其它字段都更新了，唯独这一行仍是初始值「从未成功」；把该行内联进 `build()` 后恢复。诊断方法：
  在赋值后打日志确认 state 已变（state 正确 → 就是渲染/参数传递问题）。
- **2×4 卡片别把多家的名称/指标/数值塞进同一个 Row**：文本会互相挤压、重叠或截断。左右两列、
  每列「厂商名 / 主值 / 指标名」的三行布局可读性最好；数据键不用改。
- **冷启动离线要单独做结果缓存**：桌面卡片的 `snapshot.json` 只够卡片用，主界面若把 `lastGood`
  只放内存，杀进程后离线打开就是一片「网络不可达」。成功刷新后把 `QueryResult` 落盘
  （无 Key/无原始响应），bootstrap 先读缓存再刷新；头部「已获取」只在成功时更新，失败刷新不覆盖。
- **整点翻转的验收：改时钟、不改时区**：峰谷判定按**规则集时区**（如 Asia/Shanghai），系统
  `multiScheduledUpdateTime` 按**设备本地时钟**；改时区会让两者错开。正确做法是保持设备 UTC+8，
  在设置里关闭「自动设置」把时钟拨到 17:58，等系统定时器到 18:00 观察，测后打开自动设置同步回真实时间。
  实测：17:58 卡片「高峰期 · 1 家」→ 18:00:00.234/.252 两个 formId 收到 `onUpdateForm` →
  18:00:55 卡片翻为「平峰 · 1 家时段未知」，数据获取时间不变（证明是卡片侧重判）。

## 三、ArkWeb（内嵌浏览器）做第三方登录

- 加载第三方登录页用 `Web` 组件，必须声明 `ohos.permission.INTERNET`；内核为 Chromium M132（OpenHarmony 6.0）。
- Cookie：`WebCookieManager`（`configCookieSync` / `fetchCookieSync` / `saveCookieAsync` / `existCookie` /
  `clearAllCookiesSync` …，API 23 另有 `fetchAllCookies`）；**每 30 秒周期性写盘**，可用 `saveCookieAsync` 强制；
  注意 PC/2in1 与 Tablet **不持久化 session cookie**。
- 自定义 scheme 回调：`SchemeHandler`（`onRequestStart`/`onRequestStop`），自定义协议须在
  **Web 内核初始化前**用 `customizeSchemes` 注册（**最多 10 个**），再 `setWebSchemeHandler`。
  页面级拦截用 `onLoadIntercept`（加载前阻止）/ `onInterceptRequest`（不能取 POST 数据）。
- 多实例：官方原文"移动设备上，应用的 Web 实例数量超过 10 个时，系统会主动回收后台页面数据"（软上限）。
- **审核要求（原文）**：《应用审核指南》3.16"若应用支持用户使用第三方账号登录，则该应用需提供华为账号登录选项。"
  配套：需提交有效测试账号（1.21）；集成第三方登录 SDK 需在隐私政策逐一明示（7.2）。
  未检索到"禁止应用内网页登录第三方账号"的条款——限制点在"必须同时给华为账号入口"。
- 不内嵌的替代路径：
  - **App Linking**（https + `domainVerify` 域名校验，App 未装则打开网页）或 **Deep Linking**（自定义 scheme，
    不能以 `ohos` 开头）；可用 `canOpenLink` 预判，`querySchemes` 上限 API 20 及以前 50 个、API 21+ 200 个。
  - **OAuth device flow**：REST + INTERNET 权限即可，应用内展示 code 并轮询，不需要 Web。

### 结论：哪些场景必须内嵌浏览器

| 场景 | 是否必须内嵌 | 依据 |
| --- | --- | --- |
| OAuth 网页流、且只回调 `localhost` 或不可控域名（Codex/ChatGPT 类） | **必须**（否则外部浏览器回跳接不回来） | 回调形态决定 |
| 登录后要读浏览器 Cookie 才能拿数据（Ollama Web 登录等） | **必须** | 数据只在 Cookie 会话里 |
| 提供 device code / 可回调自定义 scheme 或 App Linking 域名 | 不必 | 系统浏览器 + 回跳即可 |
| 只用 API Key（DeepSeek / OpenRouter / SiliconFlow / MiniMax / Kimi / GLM 余额类） | 不必 | 直接请求 |
| 采用华为账号（Account Kit 一键登录/扫码） | 不必 | 系统能力 |

## 四、设计稿/实现的 3 条硬约束

1. 卡片内容距边缘 12vp、圆角按宿主裁切（设计预览 18/22vp，交付直角）；
2. 小尺寸卡片只放 1–2 个信息点，按钮热区 ≥ 40vp；
3. 深浅色都要出图（Light `#FFFFFF` / Dark `#2E3033` 为默认底），锁屏卡片走单色。

## 来源

| 内容 | 来源 |
| --- | --- |
| 沉浸光感设计章节 | https://developer.huawei.com/consumer/cn/doc/design-guides/immersivelight-0000002612101053 |
| uiMaterial API 参考 | https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkts-apis-uimaterial.md |
| 卡片刷新机制 | https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/form/arkts-ui-widget-passive-refresh.md |
| 卡片约束/尺寸配置 | .../form/arkts-form-overview.md、.../form/arkts-ui-widget-configuration.md |
| 卡片数据量 | .../reference/apis-form-kit/js-apis-app-form-formBindingData.md |
| 卡片设计规范 | https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/system-features-service-widget-0000002087671904 |
| ArkWeb 概览/Cookie/scheme | .../web/web-component-overview.md、web-cookie-and-data-storage-mgmt.md、web-scheme-handler.md |
| 应用审核 3.16 | https://developer.huawei.com/consumer/cn/doc/app/50104 |
| App Linking / Deep Linking | .../application-models/app-linking-startup.md、deep-linking-startup.md |
