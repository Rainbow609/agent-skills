# 鸿蒙应用架构设计：分层架构与模块化选型

> 适用前提：新工程定架构、老工程拆模块、多设备/多团队协作时查「层怎么分、包怎么选」。
> 核实自官方最佳实践《分层架构设计》《模块化设计》原文
> （developer.huawei.com doccenter-architecture，2026-10-28 逐节复核）。
> 一多设备适配的 UI/断点配方见 `harmonyos-multi-device-oneapp.md`；包结构细节见官方
> `application-package-structure-stage`。

## 分层架构：三层与依赖方向

| 层 | 职责 | 编译产物 | 依赖规则 |
| --- | --- | --- | --- |
| 产品定制层 | 面向设备/场景的 UI、资源、配置、交互与特有功能；应用入口 | 各子目录编译为一个 **Entry 类型 HAP** | 可依赖基础特性层、公共能力层 |
| 基础特性层 | 相对独立的功能 UI 与业务逻辑，高内聚低耦合、可定制部署 | 需 Ability 承载 → **Feature HAP**；不需 Ability → **HAR 或 HSP** | 依赖公共能力层 |
| 公共能力层 | 公共 UI 组件、数据管理、外部交互、工具库 | **HAR** | 仅被上层依赖，**不允许反向依赖** |

- 逻辑模型：产品定制层是用户直接互动的入口；基础特性层按功能模块化（如底部导航每个选项一个业务模块）；公共能力层提供标准接口与协议。
- 开发模型：产品定制层可结合 UX 与业务场景，一次编译生成相同/不同的 HAP 组合；用多目标构建产物把不同设备 HAP 编成各自 `.app` 上架。
- 部署模型：`.app` 在流水线/应用市场解包为 N 个 Entry HAP + N 个 Feature HAP，按设备类型与场景分发；所依赖的 HSP 随行部署。

## 模块化设计：先定 UIAbility，再定包类型

### UIAbility 形态决定单/多 HAP

- 单 Ability：单窗口、多实例多任务、指定实例多任务都可；普通游戏建议单 HAP 承载 UIAbility。
- 多 Ability：
  - 多窗口应用，每个窗口一个功能 → 每个 UIAbility 用 **Feature HAP** 承载（如导航页与主页是两个任务）。
  - 卡片、分享等扩展功能，不作为独立任务/窗口 → 由系统 ExtensionAbility 承载，建议用 **Feature HAP** 承载该 ExtensionAbility。

### 包类型职责

| 类型 | 定位 | 关键约束 |
| --- | --- | --- |
| Entry HAP | 应用主入口 | 每个设备类型**有且仅有一个** |
| Feature HAP | 可独立安装/按需下载的功能模块，可含 UIAbility/ExtensionAbility | 多 HAP 工程中除 Entry 外均为 Feature |
| HAR | 静态共享库，编译进引用方 | 多 HAP/HSP 引用会在包内**物理多份**；可发私有 OHPM 跨应用共享 |
| HSP | 动态共享库，运行时加载 | 安装/加载有性能损耗；**应用内 HSP 与 bundleName 强耦合**，不能跨应用共享；**集成态 HSP 可在同组织多应用间共享** |

## 选型：四种常见工程模型

### 1. 共享模块（跨应用/跨团队）

某功能模块要给多个应用共用，或需要代码仓隔离：在独立工程开发 HAR，发到公司私有 OHPM 仓，再集成编译产物。能发 OHPM 的共享模块只能是 HAR。

### 2. 按需加载

月活低的功能做成按需加载，首次安装不下载，用户需要时再装。收益：减小首装包体、节省 ROM/RAM、模块边界更清晰。实现可选 **Feature HAP** 或 **HSP**；Feature HAP 可含入口 UIAbility，HSP 自 **API 14** 起可声明**非入口** UIAbility（API 18 起可声明非入口 ExtensionAbility）。

- 单 HAP 场景：只有一个 UIAbility、不用 ExtensionAbility → 优先单 HAP（Entry），按需部分选 HSP 或 HAR。
- 多 HAP 场景：多任务/多 UIAbility/ExtensionAbility → 一个 Entry + 多个 Feature，每 HAP 含一个 UIAbility 或 ExtensionAbility。

### 3. 单 HAP 工程

| 子场景 | 推荐模型 | 理由 |
| --- | --- | --- |
| 无按需加载 | 除设备相关 HAP 外全部 HAR | 无 HSP 安装/加载成本；HAR 编译进 HAP 可做类型推断与编译优化；工程简单 |
| 有按需加载，App Size 优先 | 公共依赖封装进一个 HSP「模块壳」 | HAR 静态重复存储，HSP 只存一份 |
| 有按需加载，性能优先 | 直接依赖公共 HAR | 省掉 HSP 安装/加载损耗，代价是包内重复 |

### 4. 多 HAP 工程

| 子场景 | 推荐模型 | 代价 |
| --- | --- | --- |
| 有公共能力，性能优先 | 除产品组件外全部 HAR | 多 HAP 间重复打包相同 HAR，App Size 增大 |
| 有公共能力，App Size 优先 | 公共 HAR 封装进公共 HSP「模块壳」 | 模块壳过多会影响安装速度与启动性能 |
| 无公共能力 | 参考单 HAP | 应用较少、规模较小 |

🌟 两条硬约束：

- **应用间共享的 HAR 不能依赖应用内 HSP**——HSP 与 bundleName 绑定，一旦依赖，HAR 就失去共享性。
- **模块壳不是业务模块**：只用于把 HAR 放到编译产物的合理位置，不能共享，依赖它的模块也无法跨应用共享。

## 性能坑：HSP + HAR 同时引用同一 HAR，单例失效

- HAR 是静态库：HAP 与 HSP 各编译进一份，HAR 中的模块级单例被复制。
- 官方示例：`HAR_COMMON` 里 `export let funcResult = func()`；HAP 与 HSP 同时引用后，`func` 在两个模块加载时各执行一次，冷启动变慢。
- 官方实测（100,000,000 次循环放大差异）：HSP 方案启动阶段 **3125 ms**，HAR 替代后 **853.9 ms**；官方注明不同版本/设备有差异，需实测。
- 优化建议：HSP 与 HAR 都能满足业务时，**优先把 HSP 改为 HAR**；若用的是**集成态 HSP**，可跳过该优化。
- 验证方法：用 Launch 模板对比优化前后启动阶段；区间为 `HandleLaunchAbility` 开始点到应用首次 `ReceiveVsync` 打点。

## 选型速查

| 诉求 | 选择 |
| --- | --- |
| 应用主入口 | Entry HAP（唯一） |
| 需要独立安装/按需下载且含 UIAbility | Feature HAP |
| 需要按需加载但不含 Ability | HSP（App Size 优先）或 HAR（性能优先） |
| 跨应用共享代码/资源 | HAR + 私有 OHPM |
| 多 HAP 公共依赖，包体敏感 | 公共 HSP 模块壳 |
| 多 HAP 公共依赖，启动性能敏感 | 直接依赖 HAR |
| 单 HAP 无按需 | 全 HAR |

## 官方原文

- [分层架构设计](https://developer.huawei.com/consumer/cn/doc/doccenter-architecture/bpta-layered-architecture-design)
- [模块化设计](https://developer.huawei.com/consumer/cn/doc/doccenter-architecture/bpta-modular-design)
- 包结构：[Stage 模型应用程序包结构](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/application-package-structure-stage)
