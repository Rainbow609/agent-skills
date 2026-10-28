# DevEco Testing 平台服务全景、命令行执行与 hypium-perf 性能脚本

> 适用前提：回答「DevEco Testing 平台能做什么、怎么用命令行跑性能/稳定性/预检测试、
> 自定义性能脚本（hypium-perf）怎么写」。安装与环境配置见 `harmonyos-deveco-testing-hypium-setup.md`。
> 核实自官方知识库《命令行执行测试》《性能测试》《自定义性能脚本测试（基于Python）》
> 《HarmonyOS 开发者测试服务概述》（devecocli docs，2026-10-16；命令行章节 2026-10-20 复核；
> 两篇 Python 指南的 API/参数 2026-10-28 按 doccenter-testing 原文复核），
> 并经本机原型实测；Console 章节的 26.0.0.500 行为为 2026-10-20 实机验证。

## 平台服务全景（命令行覆盖的 5 类服务 + 工具；客户端另有探索/回归/性能指标监控等卡片）

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
指标口径（性能基础质量测试）：点击响应时延=点击离手→界面变化；点击完成时延=点击离手→转场页面所有占位符加载完成；加载完成时延=应用首页铺满全屏→首页所有占位符加载完成；卡顿率=累计丢帧时间/动效时长；视频卡顿=卡顿时长>100ms 记 1 次。

🌟 **被测设备预置要求**（快速上手文档，客户端服务通用）：HarmonyOS 5.0+；取消锁屏密码
（自动化靠上滑解锁）；应用图标放桌面可见（会翻页查找但**不进文件夹**）；预授权权限、
用户协议、账号登录；网络通畅、非高温非低电量（推荐 >80%）。客户端识别不到设备时，
把客户端自带 hdc 配进 PATH。磁盘 <30GB 先清理。

## DevEcoTestingConsole 命令行执行测试（CI 可用）

> 2026-10-20 更新：本机已装客户端 **26.0.0.500**，以下命令、参数与行为均经官方文档 + 本机实测双重核对。

**本质是客户端的命令行外壳**：`DevEcoTestingConsole.sh/.bat` 启动 Java `ConsoleLauncher`，把参数发给
正在运行的客户端执行（日志里的 `Server response: Echo: ...` 就是这条本地链路）。因此**客户端必须常驻
且已登录**（设置 → 基本设置 → 开启「登录状态保活」），Console 不能脱离客户端独立跑；官方只提供
Windows/macOS，没有 Linux 无头版。

### 命令

| 命令 | 作用 | 实测/注意 |
| --- | --- | --- |
| `-params <json>` | 创建并执行测试任务 | JSON 用 UTF-8 无 BOM；路径勿含中文/空格/特殊字符 |
| `-taskIds "<id[,id]>"` | 查询任务状态 | 返回 `{"taskId":"...","state":"running"}`；逗号分隔可批量 |
| `-stopTask "<id[,id]>"` | 停止任务 | 对不存在的 ID 也回 `stop task success`，停完用 `-taskIds` 复核 |
| `-update true/false` | 更新测试服务 | 未下载时即使 `false` 也会下载；已下载时 `true` 才更新 |
| `-cleanupPolicy none\|Nd\|Nt` | 报告保留策略 | **需与 `-params` 同传**；单独执行报 `DT.100304`；天数/个数 1-100000 |
| `-help` | 帮助 | 实测只列 `-params`，其余命令可用但未进帮助 |

```bash
# Mac：客户端包内 java.jdk 的 bin 目录下执行（脚本默认可能无执行位，用 sh 或 chmod +x）
/Applications/DevEco_Testing_for_App.app/Contents/PlugIns/java.jdk/Contents/Home/bin/DevEcoTestingConsole.sh \
  -params <参数json路径>
DevEcoTestingConsole.sh -taskIds "id1,id2"                 # 批量查状态
DevEcoTestingConsole.sh -stopTask "id1"                    # 停任务
DevEcoTestingConsole.sh -params <json> -update true        # 更新服务卡片
DevEcoTestingConsole.sh -params <json> -cleanupPolicy 30d  # 任务后保留 30 天报告
```

### 支持的服务与参数要点

命令行当前覆盖 5 类服务（不是客户端全部卡片）：场景化性能、性能基础质量、稳定性基础质量、
内存泄漏、上架预检（本地）。

| 服务 | `solutionName` | 必填核心字段 | 关键范围 |
| --- | --- | --- | --- |
| 场景化性能 | `场景化性能测试` | `executeRounds`、`manualScriptPath`、`caseList`、`std`、`watchingKpi.perf/system`、`sn`、`taskName` | 轮次 1-10；`caseList` 至少 1 条 |
| 性能基础质量 | `性能基础质量测试` | `package.name` 或 `installAppPath`、`startTimes`、`traversalTimes`、`std`、`watchingKpi`、`traversalSceneType:"scene"`、`traversalAction:"basic"`、`sn`、`taskName` | 启动 1-10 次；遍历 10-120 分钟 |
| 稳定性基础质量 | `稳定性基础质量测试` | `package.name`、`testDuration`、`sn`、`taskName` | 10-60000 分钟；已安装应用时 `uninstallApp:"false"` |
| 内存泄漏 | `内存泄漏测试` | `package.name`、`testDuration`、`sn`、`taskName` | 10-10080 分钟 |
| 上架预检（本地） | `应用上架预检（本地）` | `sn`（≤3 台）、`isUploadApp`、`packageName`、`softwareCatagory`、`app_path`、`taskName` | 综合预检仅 hap；自定义 hap/zip |

- 所有参数包在顶层 `taskParams`；`sn` 是数组（即使单台）。
- **`package.name` vs `packageName`**：前四类用 `package.name`，上架预检用 `packageName`。
- **`isUploadApp` 名字反直觉**：`"true"` = 综合预检，`"false"` = 自定义预检（此时才需要 `customTest`）。
- **性能指标嵌在 `watchingKpi` 下**（`perf` / `system`），`std` 在示例中是数组，不要按参数表平铺。
- **类型不统一**：布尔/数字在不同服务示例里有时是字符串（`"true"` / `"10"`），有时是原生类型；
  直接复用官方示例类型，否则容易触发 `DT.100304` / `DT.100350` 系列校验错误。
- 上架预检的 `app_path` 必须与待测应用同版本；`app.history.package.path` 可传历史上架包；
  `softwareCatagory` 需填三级应用类别。

### 并发与边界

- 每台 PC 同时任务 **≤4**（`DT.100201`）；性能类（上架预检 / 场景化性能 / 性能基础质量）
  同时只能 **1 个**（`DT.100202`）。
- 上架预检最多 **3 台**设备（`DT.100321`）；每个 JSON 对应一个服务，新任务建议开新命令行窗口。
- 客户端非正常退出后，已下发的任务在设备上可能继续执行。
- 磁盘 <10GB 直接拒绝（`DT.100601`）；环境只能有一个 hdc server（Docker 内也要 `hdc kill`）。

### 输出与 CI 判定

结束日志：

```text
[command task status] taskPath: <任务数据目录>
[command task status]（taskName）... task state is finish/failed/stop/timeout
[command task status] task completed or task stop
```

产物在 `<taskPath>/export/`：`report.html` 与机器可读的 `2d_report_data.json`。报告骨架：

```json
{
  "isTaskPass": false,
  "generalData": {
    "taskInfo": {"taskId": "...", "taskName": "...", "taskPath": "...", "taskParams": {}},
    "appInfo": {"bundleName": "...", "versionName": "...", "apiLevel": "..."}
  },
  "expandData": [
    {
      "serviceType": "compatibility|power|stability|ux|performance|performanceScript",
      "resultSummary": {
        "satisfaction": "92%",
        "problems": [],
        "executeInfos": [],
        "rulesResult": {"total": 34, "pass": 12, "failed": 1, "warning": 0,
                        "not_involved": 10, "device_required": 7, "exception": 0, "conditional": 4}
      },
      "resultDetails": []
    }
  ]
}
```

- 上架预检通常有 5 个 `expandData`：`compatibility` / `power` / `stability` / `ux` / `performance`。
- 场景化性能样例不一定有 `isTaskPass`，需结合 `resultSummary` / `resultDetails` 判断。
- 🌟 **错误时进程退出码仍为 0**（实测 `DT.100304` / `DT.100306` 均 exit 0）——CI 必须解析 stdout
  里的 `error_code` 或最终报告，不能只看 exit code。

### 错误码速查

| 错误码段 | 类别 | 常见原因 |
| --- | --- | --- |
| `DT.1001xx` | 设备 | SN 为空/非法、设备正在执行任务、应用不存在 |
| `DT.1002xx` | 任务 | 超过 4 个任务、已有性能任务、预执行失败 |
| `DT.1003xx` | 参数 | 包名/时间/路径非法、JSON 解析失败 |
| `DT.1004xx` | 服务 | 服务不存在、更新失败 |
| `DT.1005xx` | 鉴权 | 证书缺失/过期/鉴权失败 |
| `DT.1006xx` | 环境 | 磁盘 <10GB |
| `DT.1007xx` | 网络 | 网络异常 |
| `DT.1008xx` | 未知 | 未知异常 |
| `DT.1009xx` | 登录 | 用户未登录 |

高频具体项：`DT.100201` 任务超 4 个、`DT.100202` 已有性能任务、`DT.100321` 上架预检超 3 台、
`DT.100340` 黑名单关键字超 30 个、`DT.100341` deeplink 非法、`DT.100344` 稳定性时长非法、
`DT.100352` 性能遍历时长非法、`DT.100357` caseList 为空、`DT.100601` 磁盘不足、`DT.100901` 未登录。

### 本机实测补充（2026-10-20，26.0.0.500）

- 客户端已装于 `/Applications/DevEco_Testing_for_App.app`，版本 26.0.0.500；Console 脚本位于
  `Contents/PlugIns/java.jdk/Contents/Home/bin/DevEcoTestingConsole.sh`。
- 脚本默认无执行位（644），直接运行 `permission denied`；用 `sh <脚本>` 或 `chmod +x`。
- `-help` 只列 `-params`；`-taskIds` 查真实任务返回 `state=running`。
- `-stopTask` 对不存在的任务 ID 也返回 `stop task success`——不要把它当停止成功的唯一证据。
- `-cleanupPolicy none` 单独执行返回 `DT.100304`；与 `-params` 同传时通过参数解析。
- `-params` 指向不存在的 JSON 返回 `DT.100306 this json file has exception`。
- 以上验证使用不存在的任务 ID / 不存在的 JSON，未触碰正在运行的真实任务。

### 客户端自带 hdc

`<客户端解压路径>/DevEco Testing/app/resources/bin`；识别不到设备时把它配进 PATH。

## hypium-perf 自定义性能脚本（场景化性能测试的脚本侧）

依赖安装（与 hypium 本体分开，从客户端「场景化性能测试」卡片获取安装包，**版本与 hypium 配套**）。
环境要求：Windows 10/11 64 位或 macOS 13+；内存建议 16GB+（可用 >8GB）；可用磁盘 100GB+。

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

`create_tag` 常用参数（前两个必填）：

| 参数 | 作用 |
| --- | --- |
| `step_name` / `scene_type` | 步骤名 / SceneType |
| `wait_time` | 增加采集时长，避免动效没采全 |
| `is_watch` | WATCH 场景观看 30s |
| `is_seek` | 标记进度条操作 |
| `is_short_video` | 短视频（时长 <5 分钟） |
| `need_wait_scene` | False 时跳过预置等待 |
| `ad_monitor` | COLD_START 场景检测广告 |
| `cold_start_wait_time` / `pop_up_window_enable` | 仅 COLD_START：额外等待 / 弹窗检测 |

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
  图像识别 `check_image_exist`（template/sift）、窗口 `find_window`、多指 `gesture`、鼠标/键码、
  `install_app/uninstall_app`、文件 push/recv、输入框输入/清空、断言 `host.check_*` /
  `check_component_exist` / `check_image_exist` / 控件属性断言。
- 🌟 **遥测开关**：`python -m hypium telemetry disable`（-enable 恢复）——官方收集设备型号/
  系统版本/包名/特性触发次数；POC 时见到的 telemetry ValueError 刷屏即来自它，可关。

### Python Hypium API 速查（官方 2026-10-28 复核）

设备相关四类：`UiDriver`（入口）/ `BY`（选择器）/ `IUiComponent`（控件对象）/ `UiWindow`（窗口对象）；
设备无关两类：`host`（值断言、PC shell）/ `CV`（图像）。常量 `KeyCode` / `UiParam` / `MatchPattern`，
类型 `Point` / `Rect`。

- 定位优先级：控件属性（text/key/type/id，含前缀、before/after、inside、包名）> 图片匹配 > 比例坐标。
- 断言：`host.check_equal` / `check_greater`；`driver.check_component_exist(component, wait_time, scroll_target)`；
  `check_component(component, id/text/key/type/enabled/focused/clickable/scrollable/checked/checkable)`；
  `check_image_exist(image_path_pc, similarity=0.95, timeout=3, mode=template|sift, min_match_point=16)`；
  `check_window(WindowFilter(...), title, bundle_name)`。
- 图片模板匹配要求模板图与屏幕截图中目标分辨率一致；sift 对分辨率/旋转更宽容，但难处理纯色、无线条图片。
- 日志 `Step` / `CheckPoint` / `MESSAGE` 会进测试报告；资源路径 `file_util.get_resource_path("x", isdir=False)`。
- 用例 `.py` 不能直接运行，必须由框架按同名 JSON 加载执行。

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

hypium-perf 本体依赖 DevEco Testing 客户端（安装包从客户端服务卡片获取）。**DevEco Testing 客户端已于
2026-10-20 确认本机安装（26.0.0.500），DevEcoTestingConsole 命令链路已实测**；hypium-perf 脚本侧
仍以官方配套版本为准。**稳定性压测与性能/时延采集不需要等客户端**：系统自带的 WuKong 与 SP_daemon
场景化采集零安装可用，见 `harmonyos-system-test-tools.md`。

## 官方文档（devecocli docs search 可检索到全文）

- 命令行执行测试：`开发指南/专项测试/DevEco_Testing/命令行执行测试/command-testing`
- 性能测试（服务口径）：`开发指南/专项测试/DevEco_Testing/性能测试/performance-testing`
- 自定义性能脚本测试（基于Python）：`开发指南/单元测试和UI测试/自定义性能脚本测试_基于Python/hypium-perf-python-guidelines`
- 应用UI测试（基于Python，用例工程/API 全集）：`开发指南/单元测试和UI测试/应用UI测试_基于Python/hypium-python-guidelines`
- 网页原文：[应用UI测试（基于Python）](https://developer.huawei.com/consumer/cn/doc/doccenter-testing/hypium-python-guidelines)、[自定义性能脚本测试（基于Python）](https://developer.huawei.com/consumer/cn/doc/doccenter-testing/hypium-perf-python-guidelines)
- 测试服务总览：`开发指南/HarmonyOS_开发者测试服务概述/app-testing-overview`
- 快速上手（设备预置/环境要求）：`开发指南/专项测试/DevEco_Testing/快速上手/get-familiar`
- 🌟 `docs read` 需要**完整 documentId**（用 `docs search --format json` 拿 `documentId` 字段，路径分段与网页 URL 不同）
