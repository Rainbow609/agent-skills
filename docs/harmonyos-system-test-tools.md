# 鸿蒙零客户端测试工具箱：WuKong 稳定性压测 + SP_daemon 性能采集

> 适用前提：不装 DevEco Testing 客户端、只在设备 shell 里就能做的稳定性压测与性能/时延采集。
> 两件工具均为**系统自带**（API 9+ 预置），`hdc shell` 直接执行，零安装零账号。
> 核实自官方知识库《wukong稳定性工具使用指导》《HiSmartPerf_Device性能使用指导》
> （devecocli docs，2026-10-16；SP_daemon 参数/字段/约束 2026-10-28 按官方 markdown 原文逐节复核）。
> 客户端版专属能力见 `harmonyos-deveco-testing-platform.md`。

## WuKong 稳定性压测（hdc shell 内执行）

Monkey 式随机事件注入 + 异常捕获 + 自动报告。三种模式：

| 模式 | 命令 | 用途 |
| --- | --- | --- |
| 随机测试 | `wukong exec [参数]` | 整机/指定应用随机注入（拉起应用/触摸/滑动/键盘/旋转等按比例混合） |
| 专项测试 | `wukong special [参数]` | 指定应用**控件顺序遍历+截图**（`-C <bundle> -p`）、休眠唤醒（`-k`）、**录制回放**（`-r`/`-R`） |
| 专注测试 | `wukong focus [参数]` | 只对指定控件类型（`-f <type,...>`）反复注入（`-n` 每控件次数） |

常用参数（随机/专注通用）：

```bash
wukong appinfo                                  # 列出可拉起的 bundleName/abilityName
wukong exec -s 10 -i 1000 -a 0.28 -t 0.72 -c 100
#            │种子 │间隔ms │拉起28% │触摸72% │次数100（与 -T 分钟数二选一）
#  -b/-p 允许/禁止应用名单  -d 禁止页面名单  -e/-E 允许/禁止 ability
#  -B 黑白屏检测  -I 截图  -U/-x 指定 URI 拉起  -y/-Y 屏蔽控件类型/CompId
#  事件比例参数（和 ≤1）：-t touch -a appswitch -S swap -C component(默认70%) -k keyboard -r rotate ...
```

- 🌟 **随机种子可复现**：同 `-s` 种子生成相同事件序列——复现崩溃后固定种子回归。
- API 23 新增：`-K` 指关节、`-f` 多指（1-4 指及比例）、`-P` 捏合、`-D` 滑动方向比例、`-F` 分屏/浮窗、`-W` 浏览器操作等。
- 报告：`/data/local/tmp/wukong/report/<时间戳>/`（`wukong_report.csv` 汇总 + `exception/` 故障 + `screenshot/` + `wukong.log`），`hdc file recv` 拉回。
- 故障日志落 `/data/log/faultlog/faultlogger/`；报告含事件注入统计、Ability 覆盖率、故障类型统计（CPP_CRASH/JS_CRASH/SYS_FREEZE/APP_FREEZE）。
- 🌟 坑①：`failed to connect to AAMS`＝AAMS 被 hypium/UiViewer 等占用（**同一时间只能一个程序连接**）——杀占用进程或重启设备。
- 坑②：`Errorcode 4005/4007`＝屏幕显示区域变化致无障碍取页失败，不影响流程，无需处理。

## SP_daemon 性能采集（hdc shell 内执行，HiSmartPerf Device daemon 端）

### 前置与约束

- daemon 端从 **API 9** 起预置；执行需连接**硬件设备**（模拟器性能/功耗数据不代表真机）。
- 有屏、无屏设备都支持；只有 hap 端（可视化悬浮窗）要求有屏，且从 **API 20** 起支持自动拉起 daemon。
- 执行前完成 hdc 配置并进入 shell：`hdc shell`。
- 进程管理：

```bash
SP_daemon                       # 手动拉起 daemon 进程
ps -ef | grep SP_daemon         # 检查进程（也可 pidof SP_daemon）
SP_daemon -clear                # 清除所有 SP_daemon 进程
```

hap 自动拉起时进程形如 `SP_daemon -deviceServer:<id>`（testserver 用户），属正常现象，勿当残留进程清理。

指标口径：CPU＝每秒读大中小核频点与各核使用率；GPU＝每秒读频点与负载；FPS＝每秒刷新次数；TEMP＝GPU/系统芯片温度；RAM＝应用进程实际物理内存；snapshot＝每 2 秒截屏。

### 参数总表

| 参数 | 说明 | 依赖/默认 |
| --- | --- | --- |
| `-N` | 采集次数，一秒一次 | 默认 0，范围 [1, 2147483647] |
| `-PKG` | 应用包名 | 与 `-PID` 二选一（按应用采集时） |
| `-PID` | 进程 ID 或线程 ID | 与 `-PKG` 二选一 |
| `-threads` | 采集应用子线程数量 | 必须配 `-PKG` 或 `-PID`；需进入被测应用 |
| `-c` | CPU 大中小核频点 + 各核使用率 | 带 `-PKG/-PID` 时同时采整机与应用，否则只采整机 |
| `-ci` | CPU 指令数（`hw-instructions`/`hw-cpu-cycles`） | 带包名时额外输出 `cycles per instruction` |
| `-g` | GPU 频点 + 负载 | |
| `-f` | 应用 FPS + `fpsJitters` + 刷新率 | 必须配 `-PKG`（或 `-VIEW`）；需进入应用滑动/切换 |
| `-profilerfps <N>` | 当前界面 FPS + 时间戳 | N＝次数；可配 `-sections` |
| `-sections <M>` | 分段采集 | 配 `-profilerfps`，M∈[1,10] |
| `-t` | 电量 + 温度（`Battery`/`cluster0`/`gpu`/`soc_thermal`/`shell_*`/`system_h` 等） | |
| `-p` | 电流 + 电压（`currentNow`/`voltageNow`） | 部分设备不支持 |
| `-r` | 内存 | 带 `-PKG/-PID` 时同时采整机与进程；需应用进程已拉起 |
| `-snapshot` | 屏幕截图 | 2 秒一张 → `data/local/tmp/capture` |
| `-net` | 上下行速率 | |
| `-d` | DDR 频率 | |
| `-VIEW <图层名>` | 按指定图层采 FPS | 需先取图层名；不能与 `-PKG -f` 同用 |
| `-OUT <路径>` | 指定 CSV 输出路径 | 默认 `data/local/tmp/data.csv` |
| `-start` | 开始启停式采集 | 后可跟基础采集参数 |
| `-stop` | 结束采集并生成报告 | 产物 `data/local/tmp/smartperf/1/t_index_info.csv` |
| `-print` | 启停模式每秒打印一次 | 需另开命令框执行 `-stop` |
| `-screen` | 屏幕分辨率 + 刷新率 | 需单独执行 |
| `-deviceinfo` | 设备信息（CPU 簇频点、GPU 频点、`daemonPerfVersion` 等） | 需单独执行 |
| `-server` | 启动 socket 监听 start/stop | 需单独执行 |
| `-ohtestfps <N>` | validator 用 FPS 采集 | 需单独执行，可设次数 |
| `-recordcapacity` | 当前电量 → `powerLeftRecord.csv` | 需单独执行 |
| `-editor` | 场景化采集标识 | 后接 `timeDelay`/`slideList`/`responseTime`/`completeTime`/`fpsohtest` |
| `--version` / `--help` | 版本 / 帮助 | |

`-editor responseTime|completeTime <PKG> <应用名>` 与 `-editor fpsohtest` 是 validator 专用入口，官方仅给 help 示例，无指标说明。

> 官方基础采集表把 `-PID` 标为「必选」，但文档自带示例 `SP_daemon -N 2 -c` 不带 PID 也能执行——按「`-PKG` / `-PID` 二选一、都不带则只采整机」理解，该「必选」视为表格笔误。

### 基础采集（秒级 / 启停式）

```bash
SP_daemon -N 20 -PKG <bundle> -c -g -f -t -p -r -net -snapshot -d -threads
#          │次数(1次/秒) │包名         │CPU GPU FPS 温度 功耗 内存 网络 截图 DDR 线程数
SP_daemon -N 20 -PID <pid> -c -g -f -r -threads    # 无包名/多进程场景按 PID
SP_daemon -N 20 -PKG <bundle> -f -OUT /data/local/tmp/sp.csv   # 自定义 CSV 路径
SP_daemon -N 10 -VIEW DisplayNode -f               # 按图层采 FPS
SP_daemon -N 1 -ci                                 # CPU 指令数/cycles
SP_daemon -start -c -g -f -r     # 启停式：先 start（可带采集项），操作设备，再 stop
SP_daemon -stop                  # 产物 /data/local/tmp/smartperf/1/t_index_info.csv
SP_daemon -clear                 # 清残留 daemon 进程（pidof SP_daemon 检查）
```

秒级模式结果默认落 `/data/local/tmp/data.csv`，`-OUT` 可改路径，`hdc file recv` 拉回。`-f` 必须带 `-PKG`。

采集前置与互斥：

- `-threads` 需进入被测应用；`-c`/`-r` 带 `-PKG/-PID` 需应用进程已拉起。
- `-f` 需进入应用并滑动/切换页面，否则采不到帧。
- `-VIEW` 需在对应图层上操作，且不能与 `-PKG -f` 同用。
- 启停 + `-print` 时，`-stop` 需重新打开命令框执行。
- `-snapshot` 固定 2 秒一张，导出：`hdc file recv data/local/tmp/capture/<file>.png <本地路径>`。

### CSV 字段与单位（`data.csv`）

单位约定：内存 KB、温度 °C、频率 Hz（官方表把 `gpuFrequency` 误标为 %）、电流 mA、电压 μV。官方表列名与实测输出存在大小写/拼写差异，以设备实际表头为准（见文末「口径坑」）。

**CPU / 进程 CPU**

| 字段 | 说明 |
| --- | --- |
| `cpuN_Frequency` | 第 N 核频点（Hz） |
| `cpuN_Usage` / `cpuNidleUsage` / `cpuNioWaitUsage` / `cpuNirqUsage` / `cpuNniceUsage` / `cpuNsoftIrqUsage` / `cpuNsystemUsage` / `cpuNuserUsage` | 第 N 核使用率及各状态占比（%） |
| `Totalcpu*`（`Usage`/`idleUsage`/`ioWaitUsage`/`irqUsage`/`niceUsage`/`softIrqUsage`/`systemUsage`/`userUsage`） | 整机 CPU 汇总（%） |
| `ProcId` / `ProcAppName` | 进程 ID / 包名 |
| `ProcCpuLoad` / `ProcCpuUsage` / `ProcUCpuUsage` / `ProcSCpuUsage` | 进程 CPU 负载、使用率、用户态、内核态（%） |
| `hw-cpu-cycles` / `hw-instructions` / `cycles per instruction` | CPU 周期数 / 指令数 / 每指令周期（`-ci`） |
| `threadsNum` / `tids` | 线程数与线程 ID 列表（`-threads`） |

**GPU / FPS / 刷新率**

| 字段 | 说明 |
| --- | --- |
| `gpuFrequency` / `gpuLoad` | GPU 频点（Hz）/ 负载（%） |
| `fps` | 每秒帧数 |
| `fpsJitters` | 每帧绘制间隔（ns，`;;` 分隔；掉帧核心指标） |
| `refreshrate` | 屏幕刷新率（Hz） |

**功耗 / 网络 / DDR**

| 字段 | 说明 |
| --- | --- |
| `currentNow` / `voltageNow` | 电流（mA）/ 电压（μV） |
| `networkDown` / `networkUp` | 下行 / 上行速率（byte/s） |
| `ddrFrequency` | DDR 频率（Hz） |

**温度**

| 字段 | 说明 |
| --- | --- |
| `shell_front` / `shell_frame` / `shell_back` | 前壳 / 边框 / 后壳温度（°C） |
| `soc_thermal` / `system_h` | 系统芯片 / 系统温度（°C） |
| `cluster0` / `gpu` / `npu_thermal` | CPU / GPU / NPU 温度（°C） |
| `Battery` | 电池温度（°C） |

**内存**

| 字段 | 说明 |
| --- | --- |
| `memAvailable` / `memFree` / `memTotal` | 整机可用 / 空闲 / 总内存（KB） |
| `pss` / `swap` / `swapPss` | 进程实际使用 / 交换内存 / swap PSS（KB；官方表称 `swapTotal`） |
| `sharedClean` / `sharedDirty` / `privateClean` / `privateDirty` | 共享未改写 / 共享已改写 / 私有未改写 / 私有已改写页面（KB） |
| `heapSize` / `heapAlloc` / `heapFree` | 堆大小 / 可分配 / 剩余（KB） |
| `gpuPss` / `graphicPss` / `arktsHeapPss` / `nativeHeapPss` / `stackPss` | GPU / 图形 / ArkTS / Native / 栈内存（KB） |
| 上述内存字段的 `child*` 变体 | 子进程对应内存（`-PKG` 多进程时） |
| `timestamp` | 采集时间戳 |

实测输出还包含官方 CSV 表未列出的字段：`ChildProcCpuLoad`/`ChildProcCpuUsage`/`ChildProcId`/`ChildProcSCpuUsage`/`ChildProcUCpuUsage`（子进程 CPU）、`cpuN_curFrequency`、`capture`（截图路径）。

> **口径坑**：官方表与实际输出至少四处不一致——① `cpuUasge` 拼写（实际为 `cpuN_Usage`）；② 官方表 `Childpss`/`HeapSize`/`timeStamp` 首字母大写，实测多为 `childPss`/`heapSize`/`timestamp`；③ `swapTotal` 在示例中输出为 `swap`；④ 子进程 ArkTS 内存示例里 `childArktsHeapPss` 与 `childCarktsHeapPss` 两种拼写都出现过。解析前先看拉回文件的首行表头，不照抄官方表。

### 🌟 场景化采集（一条命令出四指标，结果直接打印不落 csv）

| 命令 | 场景 | 输出指标 |
| --- | --- | --- |
| `SP_daemon -editor timeDelay` | 页面切换（先执行，等 1-2s 再手动点按钮跳转） | ResponseTime / CompleteTime / HitchTimeRate(卡顿率 ms/s) / MAX_RENDER_SEQ_MISSED_FRAMES，同时抓 trace 到 `data/local/tmp/sp_trace_delay.ftrace` |
| `SP_daemon -editor slideList` | 页面滑动（先执行，等 1-2s 再手动滑一次） | FPS / ResponseTime / HitchTimeRate / 最大连续丢帧，trace 落 `sp_trace_fps.ftrace` |

🌟 口径注意：时延按**系统打点上报**计（点击事件上报 → 系统响应首帧上屏；完成时延为切换后页面首帧上屏），与端到端用户感知有差异；滑动场景只支持滑一次、不支持 Web 组件；切换卡顿率仅支持 ArkUI router/navigation/tabs/swiper，滑动卡顿率仅支持 List/grid/scroll/waterflow。卡顿率＝动效区间累计丢帧时长(ms) ÷ 动效时长(s)。

### 其他采集（单独执行，不写 data.csv）

| 命令 | 用途 |
| --- | --- |
| `SP_daemon -screen` | 屏幕分辨率 + 刷新率 |
| `SP_daemon -deviceinfo` | 设备信息（CPU 簇频点、GPU 频点、`daemonPerfVersion` 等） |
| `SP_daemon -profilerfps N [-sections M]` | 当前界面 FPS，M 分 1-10 段 |
| `SP_daemon -recordcapacity` | 当前电量 → `/data/local/tmp/powerLeftRecord.csv` |
| `SP_daemon -server` | socket 监听 start/stop，拉起 daemon |
| `SP_daemon -clear` | 清除所有 SP_daemon 进程 |
| `SP_daemon -ohtestfps N` | validator 用 FPS 采集 |
| `SP_daemon -editor responseTime / completeTime <PKG> <应用名>` | validator 用响应 / 完成时延 |
| `SP_daemon -editor fpsohtest` | validator 用 FPS |
| `SP_daemon --version` / `--help` | 版本 / 帮助 |

> 除 `-recordcapacity` 写 `powerLeftRecord.csv` 外，其他采集结果只在命令框显示。`-recordcapacity` 官方正文与示例是「当前电量」（`recordTime`/`recordPower`），仅 help 文本写 "battery level difference"——按当前电量理解，差值需自行两次采样。

### 与客户端版的能力边界

SP_daemon/WuKong 出**原始数据**；指标判定（极优/较好/一般体验三档标准）、报告对比、自动分析、IDE 体检文件导出是 DevEco Testing 客户端（性能基础质量测试/场景化性能测试）的能力。排查定位用零客户端工具箱，出质量结论用客户端。

## 官方文档（devecocli docs 检索 ID）

- `开发指南/专项测试/命令行工具/wukong稳定性工具使用指导/wukong-guidelines`
- `开发指南/专项测试/命令行工具/HiSmartPerf_Device性能使用指导/smartperf-guidelines`
