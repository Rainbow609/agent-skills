# 鸿蒙应用测试全链路：单元测试、UI 测试、云测与分布式验证

> 适用前提：HarmonyOS / OpenHarmony ArkTS 应用（Stage 模型），回答「测试体系怎么分层、
> 单元/UI 测试代码怎么写、模拟器/真机/云测怎么选、分布式场景怎么测」。
> 核实自知乎文章《鸿蒙应用测试实战：从模拟器到云测，把 Bug 扼杀在上线前》
> （<https://zhuanlan.zhihu.com/p/2020224874367448088>）、《鸿蒙生态测试白皮书》
> （2026-06-12 更新）、官方指南/API 与 `devecocli docs` 离线文档库（2026-10-27 复核）。

## 0. 先看结论：文章哪些能信，哪些不能照抄

文章的**测试分层思路和场景判断大体成立**：单测守纯逻辑、UI 测试覆盖交互、真机补模拟器差异、
云测补机型覆盖、分布式必须多真机。但它的**框架名、导入路径和 API 示例有多处硬错误**，
代码示例不能直接运行；另有若干结论属于个人经验或因果误判，官方文档并不支持。

| # | 文章断言 | 判定 | 官方口径 / 修正 |
| --- | --- | --- | --- |
| 1 | 鸿蒙单测基于 `@ohos.test.ohos` | ❌ 错 | 官方单测框架是 **JsUnit**，包名 **`@ohos/hypium`**，从 `@ohos/hypium` 导入 `describe/it/expect` |
| 2 | UI 测试基于 `@ohos.test.uitest` | ❌ 错 | 官方 UI 测试框架是 **UITest**，模块名 `@ohos.UiTest`；新代码从 **`@kit.TestKit`** 导入 `Driver/ON/Component` |
| 3 | `Component.TEXT_INPUT`、`findComponent(Component.TEXT_INPUT, 'account')` | ❌ 错 | 官方是 `ON.type('TextInput')`、`ON.id('account')`、`ON.text('...')` 等匹配器，`findComponent(ON...)` 只接收一个 `On` 参数 |
| 4 | `getAttribute('text')` 取文本 | ❌ 错 | 官方接口是 `Component.getText()` |
| 5 | 用 `console.assert` 做测试断言 | ⚠️ 不规范 | `console.assert` 不会让 Hypium 用例失败；应用 `expect(...).assertEqual(...)` 或 `driver.assertComponentExist(...)` |
| 6 | 核心逻辑一定要写单元测试 | ✅ 对 | 白皮书把单元测试列为「白盒/灰盒测试的基础环节」 |
| 7 | UI 测试要给关键控件设置明确 `id` | ✅ 对 | 官方支持 `ON.id('login_btn')`；ArkUI 侧用 `id('login_btn')` 属性 |
| 8 | 模拟器替代不了真机 | ✅ 对 | 官方明示模拟器与真机在 Kit 能力、显示效果、签名要求上存在差异 |
| 9 | 云测试上传「未签名 HAP」 | ⚠️ 存疑 | 白皮书只说「上传应用程序包」，未提未签名；官方 FAQ 明确未签名包安装时需配置签名信息。建议直接上传已签名包，具体以云测页面校验为准 |
| 10 | 云测覆盖「上百款真实设备」、优先 Top 50 机型 | ⚠️ 未证实 | 白皮书只写「大量的手机、折叠屏和热门平板」；Top 50 是经验建议，不是官方规则 |
| 11 | 分布式同步延迟是 `SUBSCRIBE_TYPE_ALL` 合并推送导致，改 `LOCAL` + 手动刷新 | ❌ 因果错 | 官方明示跨设备同步**只支持最终一致性**；`ALL` = 本地 + 远端，`LOCAL` 只订阅本地变更。改 `LOCAL` 会丢失远端通知，手动刷新只是补偿，不是修复 |
| 12 | 模拟器不支持分布式调试，必须真机 | ✅ 基本对 | 官方 FAQ：**HarmonyOS 5 及以上应用/元服务仅支持单机调试场景**；云调试的多设备能力是兼容性查看，不等同于分布式协同调试 |
| 13 | HarmonyOS 6.0 与 5.0 分布式协议不兼容 | ⚠️ 存疑 | 未找到官方「协议不兼容」表述；应查 `compatibleSdkVersion`、设备 API level 与具体 Kit 能力差异 |
| 14 | 真机「星盾安全架构」严格校验权限 | ⚠️ 术语不准 | 「星盾」是安全能力品牌/套件（含 Device Security Kit），“权限弹窗校验”属于系统权限模型，不能混为一谈 |
| 15 | DevEco Testing 性能模块检测内存泄漏 | ⚠️ 部分对 | 内存泄漏是独立服务卡片「内存泄漏测试」；性能基础质量/场景化性能负责启动、帧率、时延、CPU/内存等 |
| 16 | 发布前用云测跑 Monkey | ✅ 方向对 | 云测「稳定性测试」包含长时间遍历与随机测试（约 2H）；系统侧零客户端方案是 WuKong |
| 17 | 接入 AGC 崩溃监控 | ⚠️ 名称过时 | 崩溃服务已合并至 **APMS（应用性能管理服务）** |
| 18 | 测试左移 + 右移四阶段 | ✅ 方向对 | 白皮书五层能力：单元 → 功能场景 → 体验专项（本地/云端）→ 线上众测 → 线上运维 |

## 1. 官方测试分层（白皮书口径）

《鸿蒙生态测试白皮书》把质量保障拆成 **5 类能力**（体验专项再分本地/云端），
比文章的「开发/集成/预发布/上线」四段更细：

| 层级 | 官方能力 | 主要工具/入口 | 解决什么问题 |
| --- | --- | --- | --- |
| 1 | 单元测试能力 | DevEco Studio 单测框架（Local/Instrument） | 函数、类、模块、接口的独立验证 |
| 2 | 功能场景测试能力 | Hypium 自动化测试框架（ArkTS/Python） | 业务功能全场景回归 |
| 3 | 体验专项测试（本地） | DevEco Testing 客户端 | 性能、稳定性、内存泄漏、功耗、UX、上架预检 |
| 4 | 体验专项测试（云端） | AGC **云测试** / **云调试** | 机型不足、特定机型/版本问题复现 |
| 5 | 线上众测 | App Test 邀请测试 | 灰度用户真实场景验证 |
| 6 | 线上运维 | **APMS** | 现网崩溃、性能瓶颈的「识别-分析-修复-验证」闭环 |

对应到文章的流程：

- 开发阶段 = 第 1 层 + 第 2 层的少量冒烟；
- 集成阶段 = 第 2 层 + 第 4 层云测；
- 预发布阶段 = 第 3 层 + 第 4 层 + 分布式多真机；
- 上线之后 = 第 5/6 层（App Test + APMS）。

## 2. 单元测试：`@ohos/hypium`，不是 `@ohos.test.ohos`

### 2.1 框架、目录与执行形态

- 框架：**JsUnit**，以 ohpm 包 `@ohos/hypium` 发布；在模块 `oh-package.json5` 的
  `devDependencies` 中声明，只进测试态、不进包。
- 测试代码同样受 ArkTS 约束：`describe/it` 名称必须是字符串字面量，全套件不可重复。
- 两套执行形态（官方口径）：

| | Local Test | Instrument Test |
| --- | --- | --- |
| 目录 | `<module>/src/test/` | `<module>/src/ohosTest/ets/test/` |
| 设备 | 不需要 | 真机/模拟器 + 签名 HAP |
| 能测 | 纯 ArkTS 逻辑；**不支持** C/C++ 方法与系统 API | 系统能力、UI、C++、ASan |
| 命令 | `hvigorw test -p module=entry` | `hvigorw onDeviceTest -p module=entry` |
| 结果 | `<module>/.test/default/outputs/test/reports` | `.../outputs/ohosTest/reports` |

### 2.2 可运行样例（修正文章的时间格式化用例）

文章里的 `DateUtil` 思路没问题，但测试导入路径错误；此外 `getHours()/getMinutes()` 不会补零，
文章只测 `14:30` 覆盖不到 `09:05` 这类边界。修正后的最小用例：

```ts
// entry/src/main/ets/utils/DateUtil.ets
export class DateUtil {
  static formatTime(timestamp: number): string {
    const d = new Date(timestamp);
    const hh = String(d.getHours()).padStart(2, '0');
    const mm = String(d.getMinutes()).padStart(2, '0');
    return `${hh}:${mm}`;
  }
}
```

```ts
// entry/src/test/DateUtil.test.ets
import { describe, expect, it, TestType, Size, Level } from '@ohos/hypium';
import { DateUtil } from '../main/ets/utils/DateUtil';

export default function dateUtilTest() {
  describe('DateUtil', () => {
    it('formatTime_pads_hour_and_minute',
      TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
        const ts = new Date(2025, 2, 25, 9, 5).getTime();
        expect(DateUtil.formatTime(ts)).assertEqual('09:05');
      });
  });
}
```

注意：

- Instrument/UI 测试文件必须以 `*.test.ets` 结尾；Local Test 也建议遵循同一命名，
  并在同目录 `List.test.ets` 中注册，否则用例可能不会执行。
- `new Date(2025, 2, 25, ...)` 的月份是 **0 基**（2 = 3 月），这是 JS 语义，不是鸿蒙特例。
- 该用例是纯逻辑，放 `src/test` 走 Local Test；一旦函数内部调用 `@ohos.*` 系统 API，
  Local Test 会直接不支持，需要改用 Instrument Test 或注入 Fake。

### 2.3 命令行

```bash
# Local Test：工程根目录执行；不支持 Linux
hvigorw test -p module=entry -p coverage=true

# Instrument Test：需连接设备
hvigorw onDeviceTest -p module=entry -p coverage=true -p ohos-debug-asan=false

# 设备侧等价命令（需先安装 app hap 与 ohosTest hap）
hdc shell aa test -b <bundleName> -m <moduleName> \
  -s unittest OpenHarmonyTestRunner -s class <Suite>#<case> -s timeout 15000
```

首次在 HarmonyOS 设备上跑 UI/Instrument 测试，官方要求先使能 UITest 能力：

```bash
hdc -n shell param set persist.ace.testmode.enabled 1
```

### 2.4 高频坑

- `hvigorw test` 必须在工程根目录执行；在别处执行可能 exit 0 但无产物。
- Local Test 不支持 `@ohos.*`、C/C++、Sendable；系统依赖用 `src/mock/mock-config.json5` 替身。
- 升级 DevEco 后老工程测试失败，先同步 hypium 版本与 `OpenHarmonyTestRunner.ets` 模板。
- Instrument Test 的权限要在 `src/ohosTest/module.json5` 单独配一份。

## 3. UI 测试：`@kit.TestKit` / `@ohos.UiTest`

### 3.1 框架与导入

- UITest 提供控件查找、点击/滑动/输入、外设模拟、控件树/截图/录制等能力；
  支持 ArkTS API 与命令行两种方式。
- UI 测试脚本**建立在单元测试框架之上**：`describe/it` 仍来自 `@ohos/hypium`，
  UI 能力来自 `@kit.TestKit`（底层模块 `@ohos.UiTest`）。
- 测试文件放 `src/ohosTest/ets/test/`，必须在设备上跑，且首次需使能 UITest（见 2.3）。

### 3.2 可运行样例（登录页）

```ts
import { describe, it, expect, TestType, Size, Level } from '@ohos/hypium';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';

const delegator = abilityDelegatorRegistry.getAbilityDelegator();

export default function loginUiTest() {
  describe('LoginUiTest', () => {
    it('login_success', TestType.FUNCTION | Size.MEDIUMTEST | Level.LEVEL3,
      async () => {
        const driver = Driver.create();
        const bundleName = abilityDelegatorRegistry.getArguments().bundleName;
        const want: Want = { bundleName, abilityName: 'EntryAbility' };
        await delegator.startAbility(want);
        await driver.waitForIdle(4000, 5000);

        // 前提：组件上设置了 id('account') / id('password') / id('login_btn')
        const account = await driver.findComponent(ON.id('account'));
        await account.inputText('testuser');

        const pwd = await driver.findComponent(ON.id('password'));
        await pwd.inputText('123456');

        const login = await driver.findComponent(ON.id('login_btn'));
        await login.click();

        await driver.waitForComponent(ON.text('欢迎回来'), 3000);
        await driver.assertComponentExist(ON.text('欢迎回来'));
      });
  });
}
```

### 3.3 文章 API 与官方 API 对照

| 文章写法 | 官方写法 | 说明 |
| --- | --- | --- |
| `import { Driver, Component, TextInput, Button, Text } from '@ohos.test.uitest'` | `import { Driver, Component, ON } from '@kit.TestKit'` | `TextInput/Button/Text` 不是这样导入的控件类；用 `ON.type('TextInput')` |
| `driver.findComponent(Component.TEXT_INPUT, 'account')` | `driver.findComponent(ON.id('account'))` 或 `ON.type('TextInput')` | `findComponent` 只接收一个 `On` 匹配器 |
| `driver.waitForComponent(Component.TEXT, 'welcome_msg', 3000)` | `driver.waitForComponent(ON.text('欢迎回来'), 3000)` | 匹配器 + 超时，两个参数 |
| `welcomeText.getAttribute('text')` | `await welcomeText.getText()` | 官方文本读取接口是 `getText()` |
| `console.assert(textAttr === '欢迎回来', '登录失败')` | `expect(await welcomeText.getText()).assertEqual('欢迎回来')` | `console.assert` 不会让 Hypium 用例失败 |

其他官方可用的匹配器与动作：`ON.text()`、`ON.type()`、`ON.id()`、
`ON.isBefore()/isAfter()/within()`、`driver.findComponents()`、`driver.swipe()/fling()/drag()`、
`Component.pinchOut()`、`Component.inputText()`、`driver.pressBack()`、
`driver.screenCapture(savePath, rect?)`。`ON.key()`（底层 `By.key`）从 API 9 起已废弃，改用 `ON.id()`。

### 3.4 高频坑

- 不给关键控件设 `id`，只能靠文本/类型匹配；文本一改测试就碎。
- 操作后只 `waitForComponent` 不够，页面动画/异步加载场景应配合 `waitForIdle()`。
- `console.assert`、`console.log` 都只是日志，不会让用例失败；断言必须用 `expect` 或 `assertComponentExist`。
- UI 测试必须在 `ohosTest` 目录、必须上设备；Local Test 跑不了 `Driver`。
- 首次跑 UITest 未执行 `param set persist.ace.testmode.enabled 1`，会出现初始化失败。

## 4. 真机、模拟器与云测：边界与选型

### 4.1 三者差异

官方 FAQ 的差异口径：

- 相比预览器，模拟器与真机的编译方式更严格，但模拟器仍存在 **Kit 能力差异**；
  模拟器不支持的能力（如部分安全 Kit、钱包、应用市场/浏览器等）需要真机或云调试。
- 模拟器在大多数情况下推包调试**不需要签名**；真机安装链路需要签名。
- 模拟器不能完全模拟特定设备的独有特性、屏幕亮度和色域；折叠屏、手表等形态仍应真机验证。
- **HarmonyOS 5 及以上应用/元服务仅支持单机调试场景**：申请单台设备调试，不支持跨设备协同调试。

因此文章「模拟器永远替代不了真机」的结论成立，但原因不止权限弹窗，还包括 Kit 能力、
签名链路、设备形态和单机调试限制。

### 4.2 云测试 vs 云调试

白皮书把云端体验专项测试拆成两种能力：

| | 云测试 | 云调试 |
| --- | --- | --- |
| 形态 | 自动化测试任务 | 远程真机手动调试 |
| 能力 | 兼容性、稳定性、性能、功耗、UX 五项检测 | 投屏、安装、操作、日志/截图；支持一帧多屏的多设备兼容性查看 |
| 场景 | 上架前批量验证、自定义测试 | 机型不足、特定机型/版本问题复现 |
| 结果 | 详细测试报告，**与上架检测互信** | 开发者自己看设备与日志 |

云测试的五大检测能力（白皮书原文口径）：

- **兼容性**：手机、折叠屏、热门平板上的首次安装、再次安装、卸载、启动异常；
  检测崩溃、无响应、闪退、运行错误、账号异常、黑白屏、无法回退等。
- **稳定性**：约 2 小时，长时间遍历 + 随机测试；检测崩溃、冻屏、内存泄漏、进程/线程限制、
  文件资源限制等。
- **性能**：真机采集冷启动时延、音视频操作时延、帧率、内存、CPU 等。
- **功耗**：前台/后台资源占用的关键功耗指标。
- **UX**：基础体验、系统特性适配、视觉风格、动效、大屏体验等。

云测试支持两种场景：**上架测试**（按应用市场审核准入规范做全量预检）与
**自定义测试**（自选范围与时长）。此外还有 AGC 软件包管理入口和 IDE 打 release 包后的
云测试入口；报告可在 AGC 云测试、软件包管理、IDE AppAnalyzer 查看。

### 4.3 流程与包要求

官方流程：选择测试场景与范围 → 上传应用程序包 → 选择云侧设备 → 执行 → 查看报告。

文章写「上传未签名 HAP」，官方白皮书没有这个表述；官方 FAQ 反而明确
「未签名的包在安装时需要配置签名信息」。因此：

- 优先上传**已签名**的 HAP/APP（调试或发布签名按云测页面要求选择）；
- 不要把「未签名」当成云测的通行做法；若页面接受未签名包，也应以页面实际校验和
  官方云测文档为准（本条标「存疑」）。

### 4.4 选型建议

- 日常开发：模拟器 + 一两台主流真机；涉及 Kit 能力、折叠屏、手表、权限、签名时上真机。
- 提测/上架前：DevEco Testing 本地「上架预检」跑兼容/性能/稳定/UX/功耗；
  再用 AGC 云测试做多机型批量验证。
- 机型选择：官方只承诺「大量手机、折叠屏、热门平板」；「Top 50 市场占有率」是经验策略，
  不是官方规则。可按目标用户分布自选，但不要把它写成平台保证。

## 5. 分布式测试：最终一致性，不是「订阅类型选错」

### 5.1 官方同步语义

- 跨设备数据同步（分布式功能）是把数据库数据同步到可信组网内的其他设备；
  官方明示：**同应用跨设备数据同步仅支持最终一致性**。
- 最终一致性意味着：写入成功后，其他设备可能暂时读不到新值，但在某个时间窗口后达到一致；
  应用不能假设「写完立刻在另一台设备可见」。
- 分布式数据对象还要求：同一应用、可信组网、设备在线、相同 `sessionId`，且一个同步关系中
  一台设备只能有一个对象加入；数据同步由系统自动完成。
- 设备发现与认证由底层通信组件完成；跨设备业务只在认证后的设备之间进行。

### 5.2 对文章「订阅类型」结论的纠错

官方 `SubscribeType` 语义：

| 枚举 | 含义 |
| --- | --- |
| `SUBSCRIBE_TYPE_LOCAL` | 只订阅本地数据变更 |
| `SUBSCRIBE_TYPE_REMOTE` | 只订阅远端数据变更 |
| `SUBSCRIBE_TYPE_ALL` | 同时订阅本地和远端数据变更 |

官方键值型数据库跨设备同步示例用的就是 `SUBSCRIBE_TYPE_ALL`。文章说「ALL 在数据量大时
会合并推送导致延迟，换成 LOCAL + 手动刷新」——官方文档没有「合并推送」这一机制说明；
真正的根因是**最终一致性**。换成 `LOCAL` 只会让本设备收不到远端变更通知，属于用轮询/手动刷新
掩盖问题，不是修复。正确做法：

1. 接受最终一致性，UI 上给出同步中/刷新入口；
2. 需要远端通知就订阅 `REMOTE` 或 `ALL`；
3. 对冲突敏感的数据设计版本号/时间戳/最后写入胜出等策略；
4. 需要强一致的场景不要用跨设备数据库硬扛，改用端云同步或服务端权威源。

### 5.3 分布式测试矩阵

至少覆盖：

- 设备发现：可信组网、账号登录状态、蓝牙/Wi-Fi 开关、设备上下线；
- 连接与断连：组网中断、设备离线、重新上线后的恢复；
- 数据同步：单写、双写、冲突、删除、批量数据、弱网/高延迟；
- 权限与账号：未登录、切换账号、权限拒绝；
- 版本兼容：不同 API level、不同系统版本、`compatibleSdkVersion` 边界；
- 形态适配：手机 + 平板 + 手表/2in1 的布局与交互差异。

测试设备：**必须多台真机**。模拟器无法覆盖跨设备协同；云调试的「一帧多屏」是多设备兼容性查看，
不是分布式协同调试。文章这一点判断正确。

## 6. 性能与稳定性

- DevEco Testing 客户端（本地）提供：性能基础质量测试、场景化性能测试、稳定性基础质量测试、
  内存泄漏测试、应用上架预检（本地）。详见 `harmonyos-deveco-testing-platform.md`。
- 不装客户端时的零依赖方案：`hdc shell` 里的 **WuKong**（随机/专项/专注压测）与
  **SP_daemon**（CPU/GPU/FPS/温度/功耗/内存采集）。详见 `harmonyos-system-test-tools.md`。
- 云测的稳定性测试约 2 小时，包含长时间遍历与随机测试；性能测试在真机采集启动、时延、帧率、
  内存、CPU 等指标。
- 内存泄漏排查：DevEco Testing 内存泄漏服务或 DevEco Studio 内存快照；常见根因是监听器/
  定时器/回调未注销。文章这条经验成立。
- 线上运维：AGC **APMS**（崩溃服务已合并至 APMS）提供现网崩溃与性能数据；
  不要再按旧文档找独立的「崩溃服务」入口。

## 7. 测试左移 / 右移的官方映射

| 阶段 | 文章做法 | 官方能力 | 建议补充 |
| --- | --- | --- | --- |
| 编码 | 单元测试 + 模拟器自测 | 单元测试（Local/Instrument） | 纯逻辑进 Local Test，系统能力进 Instrument Test |
| 集成 | UI 自动化 + 云测兼容性 | 功能场景测试 + 云测试 | UI 测试用 `ON.id` 稳定定位；云测前先跑本地上架预检 |
| 预发布 | 分布式真机 + 性能/稳定性 | 体验专项（本地/云端） | 分布式必须多真机；性能/稳定性/内存泄漏分项跑 |
| 上线后 | AGC 崩溃监控 | App Test + APMS | 灰度邀请测试 + APMS 现网指标闭环 |

## 8. 最小落地清单

1. 在模块 `oh-package.json5` 的 `devDependencies` 加 `@ohos/hypium`。
2. 建 `src/test/List.test.ets` + 首个 `*.test.ets`，用 `hvigorw test -p module=entry` 打通。
3. 纯函数/解析/编解码先写 20~30 条；不追覆盖率数字。
4. UI 关键控件加 `id()`；在 `src/ohosTest/ets/test/` 建首个 UI 用例，设备上跑
   `hvigorw onDeviceTest -p module=entry`。
5. CI 只把 Local Test 挂 macOS/Windows runner（Linux 不支持 `hvigorw test`）；
   Instrument/UI 测试放到有设备的流水线。
6. 上架前：DevEco Testing 上架预检 + AGC 云测试；分布式功能单独排多真机回归。
7. 上线后：接 APMS，按崩溃率/性能指标做回归验证。

## 9. 存疑与未证实

以下结论没有在官方白皮书/指南/API 中找到直接依据，使用时需回一手来源或实测：

- 云测试是否接受未签名 HAP（官方只说上传应用程序包；真机安装链路要求签名）。
- 云测设备数量「上百款」、选择「Top 50 市场占有率机型」是否为平台规则。
- HarmonyOS 6.0 与 5.0「分布式协议不兼容」的具体版本边界。
- 「模拟器权限弹窗比真机宽松」的具体行为差异（官方只说明 Kit 能力/显示/签名差异）。
- `SUBSCRIBE_TYPE_ALL` 在数据量大时「合并推送」的机制（官方文档未描述）。
- 「单元测试提前拦住 30% 低级错误」的比例（个人经验，无官方统计）。
- 「星盾安全架构严格校验权限」的因果表述（星盾是安全能力品牌，权限校验属于系统权限模型）。

## 参考

**文章**

- 知乎：《鸿蒙应用测试实战：从模拟器到云测，把 Bug 扼杀在上线前》
  <https://zhuanlan.zhihu.com/p/2020224874367448088>

**白皮书**

- 核心测试能力概述：
  <https://developer.huawei.com/consumer/cn/doc/guidebook/hoetwp-capability-info-0000002594762520>
- 体验专项测试（云端）：
  <https://developer.huawei.com/consumer/cn/doc/guidebook/hoetwp-capability-cloudexptest-0000002625281899>
- 云测试：
  <https://developer.huawei.com/consumer/cn/doc/guidebook/hoetwp-capability-cloudexptest1-0000002625362033>
- 云调试：
  <https://developer.huawei.com/consumer/cn/doc/guidebook/hoetwp-capability-cloudexptest2-0000002594762536>

**官方指南 / API**

- 单元测试框架使用指导：
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/unittest-guidelines>
- UI 测试框架使用指导：
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/uitest-guidelines>
- 自动化测试框架开发实践：
  <https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-automated-testing-frameworks>
- Test Kit 简介：
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/test-kit-overview>
- `@ohos.UiTest` API：
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-uitest>
- `@ohos.data.distributedKVStore` API（含 `SubscribeType`）：
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-distributedkvstore>
- 同应用跨设备数据同步概述：
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/sync-app-data-across-devices-overview>
- 键值型数据库跨设备数据同步：
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-sync-of-kv-store>

**本地离线文档（devecocli docs）**

- `开发指南/开发自测试/测试框架/代码测试/Local_Test/ide-local-test`
- `开发指南/开发自测试/测试框架/代码测试/Instrument_Test/ide-instrument-test`
- `FAQ/模拟器/模拟器_真机_预览器调试具有哪些差异/faqs-simulator-5`
- `FAQ/程序包结构/sign包和unsign包产物之间是否有差异/faqs-package-structure-68`
- `FAQ/应用测试/使用命令行执行单元测试脚本常见问题和解决方案/faqs-app-test-26`

**仓库内相关文档**

- `harmonyos-unit-testing.md`（Hypium/arkxtest 细节与踩坑）
- `harmonyos-deveco-testing-platform.md`（DevEco Testing 平台与 Console）
- `harmonyos-system-test-tools.md`（WuKong / SP_daemon 零客户端方案）
- `harmonyos-deveco-studio-cli.md`（hvigorw / codelinter / CLT）
- `harmonyos-cli-debugging.md`（hdc / hilog / aa / hidumper 等）
