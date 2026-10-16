# DevEco Testing 平台服务全景、命令行执行与 hypium-perf 性能脚本

> 适用前提：回答「DevEco Testing 平台能做什么、怎么用命令行跑性能/稳定性/预检测试、
> 自定义性能脚本（hypium-perf）怎么写」。安装与环境配置见 `harmonyos-deveco-testing-hypium-setup.md`。
> 核实自官方知识库《命令行执行测试》《性能测试》《自定义性能脚本测试（基于Python）》
> 《HarmonyOS 开发者测试服务概述》（devecocli docs，2026-10-16），并经本机原型实测。

## 平台服务全景（客户端五大测试服务 + 工具）

DevEco Testing 客户端（Windows/Mac，需华为账号登录；首次启动须联网，可开「登录状态保活」7 天免登）
把测试能力做成服务卡片，一键执行。从 5.1.5.200 起只支持 HarmonyOS NEXT 设备。

| 服务 | 干什么 | 关键参数 |
| --- | --- | --- |
| 场景化性能测试 | 跑开发者自写的 hypium-perf Python 脚本，采集响应时延/完成时延/丢帧卡顿/音视频/黑白块 | executeRounds 1-10、caseList、检测标准三档（极优/较好/一般体验）、系统指标（CPU/内存必选） |
| 性能基础质量测试 | 智能遍历算法自动操作应用（ArkUI/RN/Flutter≥3.7.12），整包性能评估 | startTimes 1-10（冷启次数）、traversalTimes 10-120 分钟 |
| 稳定性基础质量测试 | 长时随机遍历稳定性测试（10-60000 分钟），支持 asan/线程检测/黑名单/deeplink | testDuration、threadDetect、asanEnable |
| 内存泄漏测试 | 长时遍历 + 内存采集（10-10080 分钟） | testDuration |
| 应用上架预检（本地） | 按应用市场上架标准一键检兼容/性能/稳定性/UX/功耗，提升过审率 | softwareCatagory 三级应用类别、app_path |

实用工具：设备投屏、UIViewer（控件透视）、应用图谱管理、性能报告自动分析/对比。
报告可导出 IDE 体检文件导入 DevEco Studio AppAnalyzer 诊断（DevEco Studio 6.0.0 Beta3+）。
指标口径（性能基础质量测试）：点击响应时延=离手→界面变化；完成时延=界面变化→占位符加载完成；
卡顿率=累计丢帧时间/动效时长；视频卡顿=卡顿时长>100ms 记 1 次。

🌟 **被测设备预置要求**（快速上手文档，客户端服务通用）：HarmonyOS 5.0+；取消锁屏密码
（自动化靠上滑解锁）；应用图标放桌面可见（会翻页查找但**不进文件夹**）；预授权权限、
用户协议、账号登录；网络通畅、非高温非低电量（推荐 >80%）。客户端识别不到设备时，
把客户端自带 hdc 配进 PATH。磁盘 <30GB 先清理。

## DevEcoTestingConsole 命令行执行测试（CI 可用）

客户端自带控制台脚本，**每台 PC 并发任务 ≤4，性能测试任务同时只能 1 个**（内存消耗大）。

```bash
# Mac：客户端包内 java.jdk 的 bin 目录下执行（初次执行先 chmod +x）
/Applications/DevEco_Testing_for_App.app/Contents/PlugIns/java.jdk/Contents/Home/bin/DevEcoTestingConsole.sh \
  -params <参数json路径>            # json 用 UTF-8 无 BOM；路径勿含中文/空格/特殊字符
DevEcoTestingConsole.sh -taskIds "<id>"    # 查任务状态（逗号分隔可批量）
DevEcoTestingConsole.sh -stopTask "<id>"   # 停任务
DevEcoTestingConsole.sh -params <json> -update true   # 服务卡片更新
DevEcoTestingConsole.sh -cleanupPolicy 30d # 报告清理：N.d 天数 / N.t 个数，默认不清理
```

- 参数 json 结构：`taskParams` 内 `solutionName`（服务名）+ 各服务专属参数 + `sn`（设备号数组）+ `taskName`。
  五大服务的完整参数表见官方《命令行执行测试》，例如场景化性能测试必填
  `executeRounds/manualScriptPath/caseList/perf/system/std/saveAllImages/generateIdeFile/sn/taskName`。
- 任务产物：结束日志 `[command task status] taskPath: …` → `<taskPath>/export/` 下有
  `report.html` 与机器可读的 **`2d_report_data.json`**（isTaskPass / resultSummary / resultDetails）——
  CI 判定直接解析这个 json。
- 🌟 高频报错：`Connection refused`=客户端没开；`Could not create the Java Virtual Machine`=启动目录不对；
  `DT.1001xx` 设备类 / `DT.1002xx` 任务类 / `DT.1003xx` 参数类 / `DT.1005xx` 证书过期。
- 🌟 **多 hdc 冲突坑**：环境里有多个 hdc server 会 file send/recv 失败——保证只有一个 hdc 进程（`hdc kill`）。
- 客户端自带的 hdc 在 `<客户端解压路径>/DevEco Testing/app/resources/bin`。

## hypium-perf 自定义性能脚本（场景化性能测试的脚本侧）

依赖安装（与 hypium 本体分开，从客户端「场景化性能测试」卡片获取安装包，**版本与 hypium 配套**）：

```bash
pip install hypium-<版本>.tar.gz
pip install hypium-perf-<版本>.tar.gz
pip install perf_analyzer-*.whl perf_collector-*.whl perf_common-*.whl perf_resource-*.whl
# 🌟 paddlepaddle 装失败时，先装目录里自带的 paddlepaddle whl 再装其余包
```

三层结构（工程模板从客户端「创建工程模板」生成，PyCharm 直接调试）：

| 层 | 基类 | 放哪 | 规则 |
| --- | --- | --- | --- |
| 场景用例（执行入口） | `PerfBaseCase` | `testcases/` | 文件名=类名=case_id；同名 json 配套（DeviceTest driver + py_file）；步骤数建议 <30 |
| 原子用例 | `ModelBase` | `models/`（按 APP 分目录） | 可复用；`@ModelBase.scene_recover` 装饰 execute |
| 测试步骤 | `create_tag(...)` | — | **三原则：用 `_perf` 系接口、必须带场景 tag、一步一 tag 不共用** |

场景 tag 类型 `SceneType`：`COLD_START`（前需杀后台）/ `HOT_START`（前需拉起置后台）/
`WITH_PAGE_SWITCH` / `NO_PAGE_SWITCH`（滑动与无页面切换不测完成时延）/ `PLAY_VIDEO` / `WATCH`。

常用 `_perf` 接口（driver 为 `IDriverPerf`）：`touch_perf` / `long_touch_perf` / `double_touch_perf` /
`swipe_perf`（不精准滑动，distance 1-100） / `slide_perf`（精准滑动）/ `drag_perf` / `swipe_to_back_perf` /
`swipe_to_home_perf` / `watch_perf`（视频观看+卡顿检测，按 30S 分段）/ `start_application_perf`
（桌面滑找 APP 启动，6.0+）。不需要指标采集的步骤用普通接口（如 `driver.touch`）。

本地调试：main.py 里 `cmd = 'run -l <场景用例名> -ta pass_through:' + task_id` 后
`from xdevice.__main__ import main_process; main_process(cmd)`；多用例用 `;` 分割或 action_testsuite.json 配 py_file 列表。
隐私界面（银行/密码）无法录屏测试。

## Hypium（Python）用例工程：结构、执行与报告

基础指南（区别于上面的 perf 脚本体系）的用例工程：模板从 PyCharm 插件创建或官方
HypiumProjectTemplate.zip，结构 `aw/`（自定义模块）+ `config/user_config.xml` + `resource/` +
`testcases/`（用例 py + 同名 json）+ `main.py`（入口）。

- 用例两模式：**单用例** `TestCase`（生命周期 setup/process/teardown，步骤用 `Step()` 标注）；
  **测试套** `TestSuite`（setup/teardown 包多个用例，json driver 用 `DeviceTestSuite`）。
- `user_config.xml` 关键项：`<info ip port sn>`（可多设备）、`devicelog`（用例后**自动拉取
  hilog** 与指定目录）、`taskargs`：`repeat` 重复次数 / **`screenshot` 操作后自动截图 /
  `screenrecorder` 步骤自动录屏**（默认均 false）/ `pass_through` 透传参数。
- 执行：跑 `main.py`，或 xdevice 命令 `run -l <用例>[;用例2] -sn <sn> -rp <报告路径>
  -ta screenshot:true`；报告默认落**项目根 `reports/`** 时间戳子目录（gitignore 记得盖）。
- API 面：BY 选择器（text/type/key + `MatchPattern`，含 before/after/in/within 包名）、
  图像识别 `matchTemplate`+sift、窗口 `find_window`、多指 `gesture`、鼠标/键码、
  `install/uninstall`、文件 push/recv、输入框输入/清空、断言 `host.check_*` /
  `check_component_exist` / `assert_picture_*` / 控件属性断言。
- 🌟 **遥测开关**：`python -m hypium telemetry disable`（-enable 恢复）——官方收集设备型号/
  系统版本/包名/特性触发次数；POC 时见到的 telemetry ValueError 刷屏即来自它，可关。

## 🌟 本机原型实测（2026-10-16，manbo-reader 工程）

基线 hypium（非 perf）已在真机+模拟器双验证，证明「pip 装框架 → 脚本驱动设备」整条路可行：

| 项 | 结论 |
| --- | --- |
| Python 版本 | 官方推荐 3.10，**实测 Homebrew Python 3.13.0 + 公共 PyPI hypium 6.1.0.210 完全可用**（3.15 未测） |
| 设备 | 模拟器（ROM emulator 7.0.0.107）与真机 MatePad Edge（QXS-W10P 7.0.0.109）**均全链路通过**：连接/start_app/stop_app/swipe/capture_screen/find_component/go_home |
| agent 部署 | 🌟 免安装 agent：首连自动 push `uitest_agent_v1.2.2.so` 到 `/data/local/tmp/` 并协商版本（真机从无到有自动部署成功） |
| 版本配套修正 | setup 文档「≥6.1 不配套断连」的**实测边界**：7.0 ROM + hypium 6.1.0.210 跨线可用（uitest agent 自动协商）；该铁律更可能针对 UiViewer 投屏配套而非脚本驱动 |
| 坑① | 正确导入是 `from hypium.uidriver.device_connector import connect_device`（`hypium.action.device.device_connector` 不存在）；用法 `UiDriver(connect_device(device_sn="..."))`，**hdc 必须在 PATH** |
| 坑② | 存截图文件用 `capture_screen(path)`；`take_screenshot()` 只是模拟按键截屏（无返回路径） |
| 坑③ | `find_component` 找不到返回 **None**（不抛异常），断言需自查 |
| 坑④ | xdevice 6.0.7.210 的 telemetry 有 datetime 时区 bug，日志刷 ValueError 警告（无害噪声）；运行时在 **CWD 生成 `reports/`** 目录（.gitignore 需覆盖） |

 hypium-perf 本体与 DevEcoTestingConsole 依赖 DevEco Testing 客户端（安装包从客户端服务卡片获取），
未入本机原型范围；装好客户端后按上文两节操作即可。**稳定性压测与性能/时延采集不需要等客户端**：
系统自带的 WuKong 与 SP_daemon 场景化采集零安装可用，见 `harmonyos-system-test-tools.md`。

## 官方文档（devecocli docs search 可检索到全文）

- 命令行执行测试：`开发指南/专项测试/DevEco_Testing/命令行执行测试/command-testing`
- 性能测试（服务口径）：`开发指南/专项测试/DevEco_Testing/性能测试/performance-testing`
- 自定义性能脚本测试（基于Python）：`开发指南/单元测试和UI测试/自定义性能脚本测试_基于Python/hypium-perf-python-guidelines`
- 应用UI测试（基于Python，用例工程/API 全集）：`开发指南/单元测试和UI测试/应用UI测试_基于Python/hypium-python-guidelines`
- 测试服务总览：`开发指南/HarmonyOS_开发者测试服务概述/app-testing-overview`
- 快速上手（设备预置/环境要求）：`开发指南/专项测试/DevEco_Testing/快速上手/get-familiar`
- 🌟 `docs read` 需要**完整 documentId**（用 `docs search --format json` 拿 `documentId` 字段，路径分段与网页 URL 不同）
