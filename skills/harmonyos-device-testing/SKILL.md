---
name: harmonyos-device-testing
description: HarmonyOS/鸿蒙应用真机与模拟器自动化测试最佳实践：hdc/uitest 命令语义、Swiper 滑动手势坑、模拟器生命周期、E2E 流水线配方、无截图压测三源（dumpLayout/hilog/SP_daemon）、真机性能与功耗采集（SP_daemon/hitrace 掉帧分析、卡顿率口径、耗电排查）。当需要用 hdc shell uitest 驱动 UI、做模拟器回归、做不依赖截图的压测验证、排查"注入滑动不生效"、或测试掉帧/卡顿/耗电问题时使用。
---

# HarmonyOS 设备自动化测试（hdc + uitest）

适用：DevEco Studio 6.x / API 23-26 模拟器（HVD）与真机。来源：OpenHarmony 官方 arkxtest 文档、DevEco 模拟器自动化 playbook（linhay/harmony-next.skills）、manbo-reader 实战复盘（2026-10）。

## 0. 路径与环境（macOS）

- Emulator CLI：`/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator`
- hdc：`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`（不在 PATH）
- HVD root：`$HOME/.Huawei/Emulator/deployed`；镜像：`$HOME/Library/Huawei/Sdk`
- 模拟器上线后 target 为 `127.0.0.1:5555`；多设备一律显式 `-t <target>`（真机无线调试形如 `192.168.x.x:port`，不要误选）
- 构建命令与签名坑见项目 AGENTS.md（hvigorw 内置版、build-profile.json5 skip-worktree）

## 1. 模拟器生命周期

```bash
Emulator -list                                   # 列出 HVD
Emulator -start "Pura 90 Pro" &                  # 启动（detached）
# 就绪判定：hdc list targets 出现 TCP Connected 后，再等 boot completed
hdc -t <target> shell param get bootevent.boot.completed   # true 才算就绪
Emulator -stop "Pura 90 Pro"                     # 停止（幂等，复查 pgrep）
```

- 启动完整模板（playbook 版）：`-hvd <名> -path <HVD root> -t <trace名> -imageRoot <sdk>`；裸 `-start` 曾可用，若启动后弹"请登录华为账号"模态框＝启动路径不完整的症状，不要引导用户登录，先补全参数。
- 冷启动 25-60s；每条命令都要设超时；`hilog` 不带 `-z/-x` 会挂住终端。
- 应用启动：`hdc -t <t> shell aa start -b <bundle> -a EntryAbility`；停止：`aa force-stop <bundle>`；覆盖装：`hdc -t <t> install -r <hap>`（保留数据）。
- 前台是什么：`hdc shell aa dump -l`；应用信息：`bm dump -n <bundle>`。

## 2. uitest CLI（uiInput 注入语义）

`hdc shell uitest uiInput <op>`，速度单位 px/s，**取值 200-40000，默认 600**：

| 操作 | 语法 | 备注 |
|---|---|---|
| 单击 | `click x y` | |
| 双击 | `doubleClick x y` | |
| 长按 | `longClick x y` | |
| 慢滑 | `swipe x1 y1 x2 y2 [speed]` | 匀速拖动 |
| 快滑 | `fling x1 y1 x2 y2 [speed] [stepLength]` | 有惯性；stepLength 推荐缺省（默认=滑动距离/50） |
| 拖拽 | `drag x1 y1 x2 y2 [speed]` | |
| 定向快滑 | `dircFling [0左/1右/2上/3下] [speed] [stepLength]` | 屏幕级滑动，无需坐标 |
| 输入 | `inputText x y text` | 文本需 shell 转义 |
| 按键 | `keyEvent Home|Back|<keycode>` | |

布局/截屏：

```bash
hdc shell uitest dumpLayout -p /data/local/tmp/d.json   # 控件树（含 bounds/text/id）
hdc shell uitest screenCap -p /data/local/tmp/s.jpeg    # 或 snapshot_display -f ...
hdc file recv /data/local/tmp/x .tmp/x                   # 取回（-t <target>）
```

**🌟 坐标来自 dumpLayout 节点 bounds（中心点），不要盲写死坐标**；每步操作后重新 dump/screenshot 验证。真机分辨率 ≠ 截图缩放尺寸，dump 的 bounds 是像素坐标。

## 3. 🌟 滑动不生效排查清单（Swiper/翻页类组件）

实测坑（manbo-reader kit 阅读器，Pura 90 Pro 模拟器，2026-10）：

1. **拖动距离 < 屏宽 ~50% 且速度慢 ⇒ Swiper 弹回原页**。600px 拖动在 1256px 宽屏＝47.8%，不翻页。**翻页滑动至少拖过 60% 屏宽，或用 fling（高速度带惯性）**：`uiInput fling 1150 1300 100 1300 4000`。
2. 短距慢速可能被判成点击——点击落在翻页热区时会表现为"翻了一页"而非滑动。
3. 组件侧 Swiper 的 `disableSwipe(!active || phase!=='ready' || inputLocked)`：确认被测页面 phase/输入锁状态；`PanGesture(distance: 10000)`（未缩放时禁用 pan）意味着自定义 pan 不参与翻页，翻页全靠原生 Swiper。
4. 横滑无效时先试**点按翻页热区**（阅读器左右 1/3 区），区分"手势注入问题"与"会话/渲染问题"。
5. hdc 服务异常先 `hdc kill -r`；`list targets` 为空时检查模拟器是否真上线。

## 4. E2E 流水线配方（无测试套件项目）

1. `install -r` 覆盖装（保留书架/设置数据）→ `aa start` → 轮询前台 `aa dump -l`。
2. 每个验证步骤：dumpLayout 拿元素 → uiInput 驱动 → snapshot/截图取证 → 断言文本/bounds（python 解析 d.json）。
3. 等待网络加载类页面给足 sleep（2-4s）；换话/切章节后截两张（间隔 2s）防误判加载中。
4. 日志取证：`hdc shell "hilog -x | grep -E '<TAG>'"`（-x 打完即退）。
5. 崩溃检查：`hdc shell "ls /data/log/faultlog/faultlogger | tail"`（jscrash-<bundle>-…）。
6. 键盘弹窗类系统引导（如"小艺对话"）会挡坐标——dumpLayout 确认后先点掉。

## 5. Plan B：进程内 arkxtest（hypium/UiTest）

更稳的进阶路线（控件级定位，无需坐标运算，用例失败自动截图+dumpLayout，hypium ≥1.0.28）：

- 写 `entry/src/ohosTest/ets/test/*.test.ets`：`import { abilityDelegatorRegistry, driver, ON, Component } from '@kit.TestKit'`；`const driver = driver.create()`；`driver.findComponent(ON.id('xxx')).click()`、`driver.swipe(x1,y1,x2,y2)`、`driver.fling({from},{to},speed)`、`driver.assertComponentExist(ON.text('x'))`。
- 运行：`hdc shell aa test -b <bundle> -m <module_test> -s unittest OpenHarmonyTestRunner -s class <Suite> -s timeout 15000`；或 hvigor `test@Task`。
- ⚠️ 需要新建 ohosTest 模块/目录（本项目当前无测试套件，属结构性新增，先征得用户同意）。
- UiTest 使能：OpenHarmony 4.0+/API 10+ 默认使能，无需 testmode 参数。

## 6. 性能与功耗采集（真机 CLI：掉帧/耗电排查）

🌟 DevEco Profiler / AppAnalyzer / ArkUI Inspector / SmartPerf-Host 均为 GUI 专属、无官方 CLI——纯命令行下用设备侧同源数据（SP_daemon + hitrace + hidumper）替代，并在汇报中明示缺口。性能/功耗数据必须真机：模拟器不支持 OpenGL ES 3.1/3.2 且性能不代表真机。

**指标口径（官方定义，2026-10 检索自开发者文档 faqs-scenario-based-performance-test-10/12、bpta-zhenlv）**

- 丢帧：单帧丢帧时长 = 实际上屏时间 − 期望上屏时间；上屏时间看 trace 图形子系统 **present 线程**泳道结束点。帧持续 33ms（应 16.6ms）＝丢 1 帧
- 卡顿率 = 动效区间累计丢帧时长 ÷ 动效时长，单位 **ms/s**；与丢帧次数是两套检测机制，都要看
- 连续丢帧 >3 帧用户可明显感知；故障二分：**AppDeadlineMissed**（应用侧超 Vsync 周期，逻辑低效）/ **RenderDeadlineMissed**（RenderService/GPU 侧超时，界面复杂或 GPU 负载高）
- Vsync 周期：60Hz=16.67ms、90Hz=11.1ms、120Hz=8.33ms——先确认设备实际刷新率再下结论

**SP_daemon（设备预置，API 9+，CLI 采集首选）**

```bash
hdc -t <t> shell "SP_daemon -PKG <bundle> -f -c -g -r -t -p -N 30 -OUT /data/local/tmp/sp.csv -print"
hdc -t <t> file recv /data/local/tmp/sp.csv .
```

| 参数 | 采集项 |
|---|---|
| `-f` | FPS + **fps jitters**（掉帧核心指标）+ refreshrate |
| `-c` / `-g` | CPU 大小核频点+占用 / GPU 频率+负载 |
| `-r` / `-t` | 进程物理内存 / 电量+温度 |
| `-p` | 电池功耗+电压（部分设备不支持） |
| `-profilerfps -sections` | 每帧上屏时间戳（卡顿率原始数据） |
| `-threads -PKG <b>` | 线程级 CPU 占用 |

**hitrace 帧分析五步法**

```bash
hdc -t <t> shell "hitrace -b 102400 ohos graphic ace app sched freq -t 30 -o /data/local/tmp/x.htrace"
# 30s 窗口内用 uitest uiInput fling 驱动掉帧场景，结束后 file recv 取回
```

trace 关键字速查（直接搜）：
`H:ReceiveVsync`（RS 收 vsync）/ `H:MarshRSTransactionData`（应用发绘制指令，测发送间隔）/ `H:RSModifier::Draw` / `H:RSModifierManager Draw num` / `H:FlushDirtyNodeUpdate` / `H:JSAnimateTo` / `H:FrameNode[组件][id]::RenderTask`（单组件绘制周期）/ `H:PreferredFrameRate`（确认刷新率）

定界→归因：
1. render_service 的 `H:ReceiveVsync` 处理耗时未超 vsync 周期 ⇒ RS 无辜，问题在应用侧；
2. 应用主线程两次 `H:MarshRSTransactionData` 间隔 ≫ vsync 周期时按线程状态归因：
   - 主线程大多 **sleeping** ⇒ 送帧少：搜 `FrameNode[..]::RenderTask` 看动画组件的绘制周期；
   - 卡在 **Napi complete / await 回调** ⇒ 回调后业务逻辑耗时；
   - 持续 **running** 且 `RSModifier::Draw` 超周期 ⇒ 每帧属性变更触发绘制太重（Canvas 场景动画高发）。
3. 优化后同场景复测对比卡顿率与 jitters。

**耗电排查**

- CPU 序列采样：循环 `hidumper --cpuusage <pid>`；内存 `hidumper --mem <pid>`；
- 退后台静默 60s 再采样：揪常驻定时器/心跳（预期：退后台后应用 CPU 归零）；
- 代码侧嫌疑清单：挂钟 `setInterval` 驱动动画（应换 vsync 帧循环并核对 start/stop 配对）、120Hz 上每帧都出内容（旧 60Hz 定时器半速出帧，迁 vsync 后 GPU 占用翻倍属预期行为，掉帧看 jitters 而非帧数）、高频回调内打日志/分配、PixelMap 未释放、keepScreenOn 滥用。

## 7. 🌟 无截图压测三源配方（功能/性能/崩溃验证可 100% 不依赖截图）

实测结论（manbo-reader 书架压测，Pura 90 Pro 模拟器，2026-10，两轮）：功能/性能/崩溃三类验证**可 100% 无截图完成**，用以下三源交叉：

| 验证项 | 来源 |
|---|---|
| 元素存在/文本/计数/选中态/**滚动位移（bounds 变化）** | `uitest dumpLayout` 控件树 JSON（带 bounds） |
| 压测期行为计数（重建/请求/解码闸门峰值/抑制类归零） | hilog：应用 debug 构建的**每秒聚合埋点行**（manbo＝domain `0x0000` tag `PerfProbe`；先读应用侧埋点源拿准确 key） |
| CPU/内存 | SP_daemon CSV（`ProcCpuUsage`/`pss`；**模拟器 fps 恒 0 无帧数据**——帧级仍走 §6 真机口径） |
| 崩溃 | faultlogger 目录差分 + **APP_CRASH 下次启动回投**（压测后重启一次 app 回捞）+ hilog E/F 过滤 |

**驱动坑（§3 延伸）**：sub-List（zIndex 覆盖在 Swiper 之上）的 ListItem 区域会**吞左向手势**——同页右滑可翻、chip 点击全通，属注入受限而非产品回归；降级方案＝**chip 点击风暴**替代滑动风暴，仍可驱动 sub-Swiper 双页装配并逐轮 dump 验证。

**仍需截图/像素源的场景**（如实缺口，勿偷用截图补验）：封面位图内容正确性（错图/花屏——解码计数不证内容）、帧率/掉帧（模拟器无数据）、动画中间态/过渡视觉、canvas 渲染文本（如阅读器页码，UI 树无该文本节点）。

**实测基准（manbo 书架风暴参考）**：4887 本 / 32 轮 fling 下——`decode.active.peak=3`（闸门内）、`queue.peak=11`、`assembly.stale/fallback=0`、页与卡片零重建、CPU 中位 1.72%、PSS 中位 469.9MB 无泄漏、崩溃 0。产物落 `.tmp/<场景名>/`。

## 8. 相关资源

- arkxtest：github.com/openharmony/testfwk_arkxtest（JsUnit/UiTest/PerfTest + 中文使用指导）
- 鸿蒙 HDC 命令合集：github.com/codematrixer/awesome-hdc
- DevEco 模拟器自动化 playbook / API 离线参考：**已装 `~/.agents/skills/harmony-next`**（linhay/harmony-next.skills v1.3.37，经 gh-proxy.com 镜像克隆；含 scripts/hvd_manager.py 模拟器预检启动、device_ui_action.py UI 动作封装）
- 华为侧 agent 技能集合：atomgit.com/HarmonyOS_Skills/harmonyos-agent-skills
