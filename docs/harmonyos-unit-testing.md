# HarmonyOS 单元测试（Hypium/arkxtest）框架要点与踩坑

> 适用前提：HarmonyOS / OpenHarmony ArkTS 应用（Stage 模型），回答「鸿蒙有没有单元测试框架、
> 怎么在命令行跑、能测什么、有什么坑」。结论核实自官方文档、《鸿蒙生态测试白皮书》与开源仓库
> 实文件（2026-10 复核）。

## 核心结论

1. **鸿蒙有官方单元测试框架：Hypium**（arkxtest 体系 = JsUnit 单元测试 + UiTest UI 测试 +
   PerfTest 白盒性能测试，PerfTest API 20+）。《鸿蒙生态测试白皮书》测试能力章节明确推荐
   Hypium 作为自动化测试框架；DevEco Studio / hvigor 落地为两套执行形态：**Local Test**
   （原 LocalUnit，本地无设备）与 **Instrument Test**（上设备）。
2. **Local Test 只能测纯逻辑**：官方明示不支持 @ohos.* 系统 API、C/C++ 方法（00523001）、
   Sendable；系统依赖只能靠 `src/mock/mock-config.json5` 替身（API 11+ Stage 模型）。
   → 可测面 = 纯函数/纯数据层；带系统能力的层靠上设备测试或真机脚本。
3. **命令行可跑**：`hvigorw test`（本地）/ `hvigorw onDeviceTest`（设备）；
   `hvigorw test` **不支持 Linux**（CI 用 macOS/Windows runner）；脚本必须在工程根目录执行，
   否则静默不执行（exit 0 无产物）。
4. **Mock 双机制，生态样例稀疏**：hypium MockKit 只能 mock 应用内自定义对象（官方明示不支持
   系统 API）；mock-config.json5 可替身 @ohos.* 与本地模块，但 GitHub 抽查大厂仓多为空脚手架
   模板——机制能跑，别把它当架构依赖。
5. ArkTS 约束同样作用于测试代码：describe/it 名必须是字符串字面量且全套件不可重复；
   断言对象要显式 interface（禁 any/解构等仓库规则照常生效）。

## arkxtest 四件套（官方索引页）

官方《自动化测试框架使用指导》本身只是索引，arkxtest 体系分四块：

| 能力 | 官方指南 | 本仓库对应 |
| --- | --- | --- |
| 单元测试 | `unittest-guidelines` | 本文 |
| UI 测试 | `uitest-guidelines` | `harmonyos-app-testing-fullchain.md` §3 |
| 白盒性能测试 | `perftest-guideline` | 本文（`@ohos.test.PerfTest`，API 20+） |
| 辅助测试工具 | `testhelper-guidelines` | 官方指南直查 |

入口：[自动化测试框架使用指导](https://developer.huawei.com/consumer/cn/doc/doccenter-testing/arkxtest-guidelines)。

## 双层执行体系

| | Local Test（LocalUnit） | Instrument Test |
|---|---|---|
| 目录 | `<module>/src/test/` | `<module>/src/ohosTest/ets/test/` |
| 设备 | 不需要 | 需真机/模拟器 + 签名 hap |
| 能测 | 纯 ArkTS 逻辑（禁 @ohos/C++/Sendable） | 系统能力、UI（UiTest）、C++（含 ASan） |
| 命令 | `hvigorw test -p module=entry [-p coverage=true]` | `hvigorw onDeviceTest -p module=entry [-p ohos-debug-asan=false]` |
| 结果落点 | `<module>/.test/default/outputs/test/reports` | `.../outputs/ohosTest/reports` |

- 依赖放 devDependencies：`"@ohos/hypium"`（官方文档示例 `1.0.25`，Local/Instrument 要求 1.0.25+；实际版本以 ohpm 为准；只参与测试态不进包）
- 文件名必须 `*.test.ets`，且必须在 `List.test.ets` 注册，否则用例不执行（00522001/2/5）
- Instrument 如需权限，要在 `src/ohosTest/module.json5` 单独配一份
- 设备侧等价命令：`hdc shell aa test -b <bundle> -m <module> -s unittest OpenHarmonyTestRunner
  -s class Suite#case -s timeout 15000`（需先手工装 app hap + ohosTest hap，未签名报 00507001）
- `@ohos.test.PerfTest`（API 20+）可在单测框架内对指定代码段采集耗时/CPU/内存/时延/帧率

## Mock 两套机制

| 机制 | 能替什么 | 限制 |
|---|---|---|
| hypium MockKit（mockFunc/mockPrivateFunc/mockProperty/when/verify/ArgumentMatchers） | 应用内自定义对象/函数/属性 | 官方明示不支持系统 API；verify 只做参数 toString() 全等，复杂对象不可靠 |
| `src/mock/mock-config.json5` + `import mock` | @ohos.* 系统模块、外部 HAR、本地模块 | 仅 API 11+ Stage；本地模块 key 只收 `ets/xxx` 相对路径且必须带后缀；生态可用样例极少 |

## ArkTS / 测试代码专属约束与高频坑

- describe/it 名称必须字符串字面量（用变量报 00521003~00521005），全套件不可重复（00521006/7）
- Local Test 超时不可配（Instrument 可改），默认 **5000ms**（官方 `-s timeout` 默认值；示例常用 15000）
- 测试里 `getContext()` 不可用 → 用 `AbilityDelegator.getAppContext`
- Sendable 相关代码不进 Local Test（官方 concurrency-faq 明示）
- 升级 DevEco 后老工程测试失败 → 同步 hypium 版本与
  `src/ohosTest/ets/testrunner/OpenHarmonyTestRunner.ets` 模板（faqs-app-test-2）
- 集成态 HSP 测试卡 running → 需 DevEco 6.0.1.260+
- 测试文件引用不存在的模块会让执行静默卡死
- DevEco CodeGenie「AI 生成单元测试」不支持 ArkUI 组件/生命周期/@Extend/@Styles/@Builder/private 方法
- 🌟 华为开发者文档站是 SPA：webReader/WebFetch 直接抓只返回「文档中心」外壳；
  正文用本机 `devecocli docs search`（本地 docs.zip）或搜索引擎摘要获取

## 社群现实（选型预期管理）

- arkxtest 官方仓：gitee.com/openharmony/testfwk_arkxtest（jsunit + uitest + hamock 目录）
- RNOH（华为官方 RN on OpenHarmony）：`LocalUnit.test.ets` 至今是官方模板未动，纯逻辑测试
  改用 Jest → 大项目对 hypium 本地单测接受度有限，纯 TS 逻辑可考虑 Node 侧测试
- GSYGithubAppOH：Provider 注入 FakeHttp/FakeRdb 做无设备分层测试；其 `src/test` List 转发
  ohosTest 套件复用 `hvigorw test` 的技巧【存疑：未经本机复现】
- C++ 单测路线：gtest 可执行文件 + `hdc file send` 到 /data/local/tmp 跑 + llvm-cov 覆盖率
  （京东 JDImage 方案，仅模拟器可用）
- 官方白皮书的测试分层：单元测试 → 集成测试 → UI 测试 → 云测

## 对无测试项目的最小起步路径

1. `entry/oh-package.json5` devDependencies 加 `@ohos/hypium`，建 `src/test/List.test.ets` +
   首个 `.test.ets`，`hvigorw test -p module=entry` 打通（无设备、无模拟器）
2. 只测零依赖纯函数（解析/编解码/比较器/映射表），先 20~30 条，不追覆盖率
3. 带 @ohos/hilog/Context 的逻辑先抽纯函数或接口注入 Fake；mock-config 只在确需替身时用
4. CI 只挂 macOS runner 跑 `hvigorw test`；Linux 只做静态检查
5. 系统能力/worker/原生层继续走真机脚本验证，明确不纳入本地单测目标

## 参考链接

- 白皮书《鸿蒙生态测试能力全景》：
  [核心测试能力概述](https://developer.huawei.com/consumer/cn/doc/guidebook/hoetwp-capability-info-0000002594762520)、
  [白盒测试 II](https://developer.huawei.com/consumer/cn/doc/guidebook/hoetwp-capability-whitebox2-0000002625362023)、
  [白盒测试](https://developer.huawei.com/consumer/cn/doc/guidebook/hoetwp-capability-whitebox-0000002594922434)
- 官方指南（developer.huawei.com/consumer/cn/doc/harmonyos-guides/ 前缀）：
  `ide-local-test`、`ide-instrument-test`、`ide-test-mock`、`unittest-guidelines`、
  `ide-local-test-errorcode`、`ide-hvigor-task-process`、`concurrency-faq`
- FAQ：`faqs-app-test-2/19/23/26/34/35/37/39/40`
- arkxtest：<https://gitee.com/openharmony/testfwk_arkxtest>
- GSYGithubAppOH：<https://github.com/CarGuo/GSYGithubAppOH>
- RNOH：<https://gitee.com/openharmony-sig/ohos_react_native>
- 京东 C++ 单测与覆盖率方案：<https://juejin.cn/post/7393966638944141351>
