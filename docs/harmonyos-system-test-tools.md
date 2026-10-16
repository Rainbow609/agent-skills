# 鸿蒙零客户端测试工具箱：WuKong 稳定性压测 + SP_daemon 性能采集

> 适用前提：不装 DevEco Testing 客户端、只在设备 shell 里就能做的稳定性压测与性能/时延采集。
> 两件工具均为**系统自带**（API 9+ 预置），`hdc shell` 直接执行，零安装零账号。
> 核实自官方知识库《wukong稳定性工具使用指导》《HiSmartPerf_Device性能使用指导》
> （devecocli docs，2026-10-16）。客户端版专属能力见 `harmonyos-deveco-testing-platform.md`。

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

### 基础采集（秒级 / 启停式）

```bash
SP_daemon -N 20 -PKG <bundle> -c -g -f -t -p -r -net -snapshot -d -threads
#          │次数(1次/秒) │包名可选     │CPU GPU FPS 温度 功耗 内存 网络 截图 DDR 线程数
SP_daemon -start -c -g -f -r     # 启停式：先 start（可带采集项），操作设备，再 stop
SP_daemon -stop                  # 产物 /data/local/tmp/smartperf/1/t_index_info.csv
SP_daemon -clear                 # 清残留 daemon 进程（pidof SP_daemon 检查）
```

秒级模式结果默认落 `/data/local/tmp/data.csv`；`hdc file recv` 拉回。`-f` FPS 必须带 `-PKG`。

### 🌟 场景化采集（一条命令出四指标，结果直接打印不落 csv）

| 命令 | 场景 | 输出指标 |
| --- | --- | --- |
| `SP_daemon -editor timeDelay` | 页面切换（先执行，等 1-2s 再手动点按钮跳转） | ResponseTime / CompleteTime / HitchTimeRate(卡顿率 ms/s) / MAX_RENDER_SEQ_MISSED_FRAMES，同时抓 trace 到 `data/local/tmp/sp_trace_delay.ftrace` |
| `SP_daemon -editor slideList` | 页面滑动（先执行，等 1-2s 再手动滑一次） | FPS / ResponseTime / HitchTimeRate / 最大连续丢帧，trace 落 `sp_trace_fps.ftrace` |

🌟 口径注意：时延按**系统打点上报**计（点击事件上报 → 首帧上屏），与端到端用户感知有差异；滑动场景只支持滑一次、不支持 Web 组件；切换卡顿率仅支持 ArkUI router/navigation/tabs/swiper，滑动卡顿率仅支持 List/grid/scroll/waterflow。

### 实用单命令

`-screen`（分辨率+刷新率）、`-deviceinfo`（SOC/GPU 频点、daemon 版本）、`-profilerfps N`（连续 N 秒当前界面 FPS，加 `-sections M` 分 1-10 段）、`-recordcapacity`（电量差值，落 powerLeftRecord.csv）、`-server`（socket 监听启停）。

### 与客户端版的能力边界

SP_daemon/WuKong 出**原始数据**；指标判定（极优/较好/一般体验三档标准）、报告对比、自动分析、IDE 体检文件导出是 DevEco Testing 客户端（性能基础质量测试/场景化性能测试）的能力。排查定位用零客户端工具箱，出质量结论用客户端。

## 官方文档（devecocli docs 检索 ID）

- `开发指南/专项测试/命令行工具/wukong稳定性工具使用指导/wukong-guidelines`
- `开发指南/专项测试/命令行工具/HiSmartPerf_Device性能使用指导/smartperf-guidelines`
