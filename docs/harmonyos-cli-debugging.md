# 鸿蒙 CLI 调试命令速查：hdc 工具族、崩溃取证与官方文档地图

> 适用前提：不进 DevEco Studio GUI，纯命令行调试真机/模拟器上的 HarmonyOS 应用
> （日常联调、崩溃取证、性能定界、CI 回归）。
> 核实自官方 Debugging Commands 文档组（command-line-tools-overview 总览页 + 各工具页，
> developer.huawei.com，2026-10-20），devicedebug / lldb 两条承重结论另经 OpenHarmony docs
> GitHub raw md 直读复核。
> 分工：构建/签名/hvigorw/codelinter/Emulator 见 `harmonyos-deveco-studio-cli.md`；
> WuKong 压测与 SP_daemon 采集见 `harmonyos-system-test-tools.md`；DevEco Testing 客户端见
> `harmonyos-deveco-testing-platform.md`；uitest 驱动与 hitrace 帧分析五步法见
> `skills/harmonyos-device-testing/`（本仓库技能，实战复盘版）。

## 结论：没有「CLI 调试白皮书」，权威入口是调试命令文档组

- 官方**不存在**名为《应用调试白皮书》《命令行调试白皮书》的文档（2026-10-20 中英检索，置信度中高）。
  正式白皮书均非调试主题：《鸿蒙生态应用开发白皮书》（V2.0 于 2022 HDC 发布、现有 V3.0，生态全景）、
  《HarmonyOS NEXT 安全技术白皮书》（安全）——检索确认存在，但都不是调试操作手册。
- 🌟 最接近「官方系统性调试指南」的是 **Debugging Commands 文档组**（华为开发者官网，EN 站标题
  "Command Line Tools - Debugging Commands"）。注意总览页表格只列 **hdc / aa / bm / hilog /
  打包工具 / 解包工具** 六项；hidumper / hitrace / hiperf 是同文档树下的**独立工具页**，别从总览页找全。
- 纯 CLI 可覆盖全链路：构建 → 签名 → 装包 → 拉起 → 日志 → 崩溃取证 → 性能采集 → 自动化回归；
  唯一硬缺口是**断点级调试**——仍以 DevEco Studio 为主（LLDB 是其默认调试器）；
  OpenHarmony 侧 LLDB 文档标题即标注「仅对系统应用开放」，三方应用 native 断点走 IDE。
- 🌟 抓取技巧：华为文档站是 SPA，curl/无头抓取常得空正文（需浏览器或渲染型抓取）；
  OpenHarmony docs 在 GitHub 是明文 md（`zh-cn/application-dev/dfx|tools/`），raw 直读最可靠。

## 工具全景（2026-10-20 经官方页核对）

| 工具 | 用途 | 典型命令 |
| --- | --- | --- |
| hdc | 设备连接/装包/文件/端口转发 | `hdc list targets -v`；`hdc install -r x.hap`；`hdc file recv <远端> <本地>` |
| hilog | 日志过滤/落盘 | `hdc shell hilog -T <tag> -x`；持久化 `hilog -w start -f applog -l 2M -n 100` |
| aa | 拉起/停止、跑测试、调试态 | `aa start -b <bundle> -a EntryAbility`；`aa test ...`；`aa appdebug -b <bundle> -p` |
| bm | 包管理/应用信息 | `bm dump -n <bundle>` |
| hidumper | CPU/内存/服务状态 | `hidumper -ls`；`hidumper --cpuusage <pid>`；`hidumper --mem <pid>` |
| hitrace | 系统/应用 trace 采集 | `hitrace -l` 列分类；`hitrace -b 204800 app graphic -t 10 -o /data/local/tmp/a.ftrace` |
| hiperf | CPU 热点/火焰图 | `hiperf record --app <bundle> -d 10 -o /data/local/tmp/perf.data`；`hiperf report -i <data> --limit-percent 1` |
| devicedebug | 向 debug 应用进程发信号 | `hdc shell devicedebug kill -<1-64> <pid>`；**仅 debug 类型进程**（非 debug 报 `is not debuggable app`） |
| hstack | Native 崩溃栈解析（仅 CLT 有） | BuildID+符号解析 cppcrash；6.1.0 起支持单文件直传（版本差异见 deveco-studio-cli 篇） |
| hvigorw / ohpm | 构建/依赖 | 见 `harmonyos-deveco-studio-cli.md`，不在此重复 |

## 场景配方

### 日常联调

- 前置：设备开开发者选项 + USB/无线调试（官方 ide-developer-mode）；无线 `hdc tconn <IP>:<port>`。
  🌟 多设备一律显式 `-t <target>`；hdc 服务异常先 `hdc kill -r`。
- 装包：HAP 必须已签名（命令行签名材料与门槛见 `harmonyos-deveco-studio-cli.md`）；
  `hdc install -r <hap>` 覆盖安装保留数据。
- 拉起/停止：`aa start -b <bundle> -a <Ability>`（目标 Ability `exported != false`）；
  `aa force-stop <bundle>`；前台是什么 `aa dump -l`；应用信息 `bm dump -n <bundle>`。
- 日志：`hilog -T <tag> -L <level> -D <domain>` 精确过滤，忌全量刷屏；🌟 默认**不落盘**，
  留存先 `hilog -w start`；交互 shell 不带 `-x`/`-z` 会挂住终端（打完即退用 `-x`）。
- 调试等待态：`aa appdebug -b <bundle> -p`（挂起等调试器）、`aa attach` / `aa detach`；
  真正断点交 IDE。

### 崩溃取证（jscrash / cppcrash / appfreeze）

- 统一路径 `/data/log/faultlog/faultlogger`：`hdc file recv /data/log/faultlog/faultlogger ./faultlog`；
  appfreeze 增强日志在 `/data/log/faultlog/freeze_ext`。
- 先看 `Reason` / `Error name` / `Stacktrace` 三字段；跨语言（ArkTS↔Native）看 `HybridStack`；
  异步链路看 `SubmitterStacktrace`。
- 🌟 Release JS 栈需 Source Map 还原：用 CLT 的 `hstack`。
- 字段最细的定义在 OpenHarmony dfx 三篇 guidelines（GitHub raw 直读）：`jscrash-guidelines` /
  `cppcrash-guidelines` / `appfreeze-guidelines`。

### 卡顿与性能定界

- trace：`hitrace -l` 选分类；帧分析五步法、trace 关键字速查（`H:ReceiveVsync` /
  `H:MarshRSTransactionData` / `FrameNode[..]::RenderTask` 等）与卡顿率口径（ms/s）见
  `skills/harmonyos-device-testing/` §6，不在此复制。
- CPU 热点：`hiperf record --app <bundle>`（一般需 debug 签名；release profileable 支持**存疑**，
  按系统版本实测）。
- 内存：`hidumper --mem <pid>`（PSS）/ `--mem-smaps`；JS 堆 `hidumper --mem-jsheap <pid> --raw`
  （需 debug 签名且亮屏）。
- 启动耗时：`aa start ... -W`（API 20+，仅统计显式启动）。
- 秒级 FPS/CPU/功耗采集与场景化卡顿率走 SP_daemon（`harmonyos-system-test-tools.md`）。

### CI / 自动化回归

- 构建机装官方 CLT（hvigorw/ohpm/hdc/hstack 统一 `bin`；Linux 建议 JDK 21/16GB 内存/100GB 磁盘），
  流水线与签名配方见 `harmonyos-deveco-studio-cli.md`。
- 设备侧测试执行两条路：`hdc shell aa test -b <bundle> -m <module> -s unittest
  OpenHarmonyTestRunner -s class <Suite> -s timeout 15000`，或 hvigor `test@Task`
  （arkxtest/hypium 写法见 `skills/harmonyos-device-testing/` §5 与 `harmonyos-unit-testing.md`）。
- 收尾取证：faultlogger 目录差分 + hilog 过滤；无截图压测三源配方见
  `skills/harmonyos-device-testing/` §7。

## 官方文档地图（2026-10-20 复核）

Debugging Commands 文档组（developer.huawei.com，中英同 slug；SPA 站需浏览器打开）：
- 总览：https://developer.huawei.com/consumer/en/doc/harmonyos-guides/command-line-tools-overview
- 各工具页：`.../doc/harmonyos-guides/<名称>`——`hdc` / `hilog` / `aa-tool` / `bm-tool` /
  `hidumper` / `hitrace` / `hiperf`
- 调试总览（断点以 IDE 为主）：https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-debug-device
- 前置（开发者模式/USB/无线调试）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-developer-mode

配套（本库已有专篇）：hvigorw `.../ide-hvigor-commandline`、流水线 `.../ide-command-line-building-app`、
Performance Analysis Kit `.../performance-analysis-kit-overview`。

OpenHarmony docs（GitHub `openharmony/docs` master，raw md 直读最可靠）：
- `zh-cn/application-dev/dfx/`：hdc / hilog / hidumper / hitrace / hiperf +
  jscrash / cppcrash / appfreeze 三篇 guidelines
- `zh-cn/application-dev/tools/`：aa-tool / bm-tool / devicedebug-tool /
  lldb-tool-sys（仅系统应用）/ command-line-tools-overview
