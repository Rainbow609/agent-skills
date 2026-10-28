# 鸿蒙游戏性能分析与调优工具链

> 适用前提：游戏/图形类应用要定位掉帧、卡顿、功耗、GPU 过载，或在「测—析—调—验」之间选工具。
> 核实自官方《游戏性能分析与提升》与《游戏性能诊断（HiSmartPerf）》文档组原文
> （developer.huawei.com doccenter-games / AppGallery-connect-Guides，登录后逐页核对，2026-10-28）。
> 零客户端设备侧采集（SP_daemon/WuKong）见 `harmonyos-system-test-tools.md`；
> DevEco Testing 平台与命令行见 `harmonyos-deveco-testing-platform.md`。

## 1. 工具链全景

官方「游戏性能分析与提升」下挂 10 项能力：

| 能力 | 定位 | 形态 |
| --- | --- | --- |
| 游戏场景感知 | 游戏与系统交互：上报游戏信息、获取设备状态；按场景精细化调度资源 | API（Game Service Kit；旧平台 GameTurbo Engine） |
| 游戏性能诊断（HiSmartPerf） | CPU/GPU/FPS/功耗/温度采集 + trace/火焰图/GPU counter | PC 客户端 Editor + 设备侧 Device |
| 游戏性能管理（GPM） | 接入 SDK 采集运行时性能，云端分析，开发者中心看报表 | SDK + HarmonyOS 开发者中心 |
| 花瓣游戏加速器（PGA） | C# → 原生代码优化（毕昇编译器 + SIMD + 别名分析） | 编辑器插件 + SDK |
| 花瓣游戏管线（PGP） | 面向麒麟 + HarmonyOS 6.0+ 的引擎级渲染/资产管线优化 | 动态渲染 SDK 等 |
| 花瓣游戏数据驱动（PGD） | ECS 高性能实体组件框架 | C# / 团结 Editor Package |
| AILOD | AI 生成 LOD，降低模型面数 | Windows 团结 Editor 插件 + 云端 |
| 二进制优化服务 | 无源码优化 C++ 二进制（插桩 + profile 指导） | 工具包 + 优化流程 |
| 应用质量管理（APMS） | 指标大盘、告警、根因分析、质量报告 | 云端服务 |
| 技术支持 | 接入与调优支持 | 支持入口 |

## 2. HiSmartPerf：Editor + Device

### 2.1 定位与平台

- **免费**；官方能力描述覆盖 **HarmonyOS 5.0 及以上、HarmonyOS 3.1/4.0 及以下、Android、快游戏** 的性能测试与分析。
- 两大形态：
  - **HiSmartPerf-Editor**（PC）：配置采集项、采集、生成报告、解析数据、性能分析、整机测试。
  - **HiSmartPerf-Device**（设备侧）：手机/平板连接 Editor 后自动安装；采集 FPS、功耗、温度、负载等基础指标，适合快速看整体性能。
- Editor 安装：Windows 运行 `HiSmartPerf-Editor.exe`；macOS 打开 dmg 拖入 Applications，首次需在「隐私与安全性」允许。**安装路径不能有中文和空格**，否则 Device 会一直显示「正在连接采集器」。

### 2.2 准备工作

1. 实名认证的华为开发者账号。
2. 仅在本地看报告：无需创建项目/应用；要上传 HarmonyOS 开发者中心：需创建项目和应用（只用「游戏性能调优」时关闭「分析服务」）。
3. 连接手机：USB 选择「仅充电」；连接成功后设备自动安装 HiSmartPerf 应用；测功耗可切 Wi-Fi（电脑与手机同一 Wi-Fi）。
4. HarmonyOS 5.0+ 游戏需在手机上授权「读取已安装应用列表」。
5. Kirin 芯片设备长时间连不上：可能是 GPU Counter 初始化异常，重启手机再试。

### 2.3 设置采集要求

- 数据项分两组 UI：Android / HarmonyOS 3.1/4.0 及以下；HarmonyOS 5.0 及以上。
- CPU trace 采集模式（旧平台）：`stop_when_full` / `cycle` / `long_trace` / `auto_trace`；HarmonyOS 5.0+ 主要用 `long_trace` / `auto_trace`。
- 关键建议：
  - 缓存过大降低游戏可用内存；存储间隔过小会占用较多 CPU；文件过大可能打不开。
  - 抓取条件支持大卡顿/卡顿/其它帧率事件；「满足条件后抓取」抓事件后 10 秒，「循环抓取，覆盖事件前后」抓开始至事件后 5 秒并循环；单次 trace 不大于 256MB。
  - 调用栈采样默认关闭；开启后看函数耗时，需保留 symbol，Android 13+ 更稳。
  - 自定义数据项：旧平台 Atrace/Ftrace；HarmonyOS 5.0+ Hitrace。初次使用建议先用默认项。
- 抓帧：仅 **HarmonyOS 6.0+** 且 **debug 包**；查看帧文件需连接 Graphics Profiler。
- 通用设置：测试报告可自动/询问保存与上传云端。

### 2.4 采集

- 左侧「游戏性能测试」→ 选应用（识别不到时点右上角实时刷新）→「启动」→ 手动进入目标场景 → 确认「测试中」→「记录数据」。
- 可切换进程（默认 Main process）；测试中可「抓帧」；「保存数据」生成报告，「测试中」结束测试。
- 🌟 单次采集建议 **不超过 30 分钟**；生成报告时保持设备与工具连接稳定，否则可能失败。
- 实时采集可看数据变化；后台采集看不到实时变化和报告；可随时记录/保存。

### 2.5 报告与解析

- 管理报告：查看 / 分享 / 数据对比。
- 解析数据：系统数据、GPU counter、CPU trace、CPU 火焰图、数据对比。
- 性能分析：
  - **CPU Counter 统计**：仅 HarmonyOS 5.0+。
  - **CPU 火焰图**：Mac 暂不支持；仅 Android / HarmonyOS 3.1/4.0 及以下；需 Python 3.12、NDK android-ndk-r26d。
  - **CPU trace**：调度/频点/线程时间片/绘帧/perf 泳道图；`.trace` 用 trace 工具打开，`.htrace` 可直接查看。

### 2.6 整机测试

| 功能 | 能力 | 限制 |
| --- | --- | --- |
| RS 树可视化 | 看渲染树结构与节点属性 | HarmonyOS 5.0+ |
| 多应用内存 | 同时采多个应用内存 | 建议不超过 5 个应用、30 分钟 |
| 设备日志 | 系统/Crash/ANR 日志 | — |
| 设备状态监测 | 活跃应用数、Crash 应用；trace/日志/USB 断电/自动化脚本 | HarmonyOS 5.0+ |

### 2.7 成功案例（官方）

一款即将上线华为游戏中心的新游：FPS 掉帧 → GPU 频率达峰值 → GPU counter 显示 Cycle 明显升高 → 定位 **Overdraw 过高**；另一战斗场景帧率下降 → SoC 温度 **64°C** 触发温控 → 功耗 **3W**、GPU 频率长期满负荷。结论：用 FPS、GPU 频率、GPU counter、温度、功耗五类数据可把「掉帧」定位到渲染/温控/功耗根因。

### 2.8 版本要点（Windows HiSmartPerf）

| 版本 | 时间 | 要点 |
| --- | --- | --- |
| 15.5.2.301 | 2026-09-07 | 更新 CPU trace 版本 |
| 15.5.2.300 | 2026-03-24 | 修复部分场景 FPS/内存数据为空 |
| 15.4.2.301 | 2025-12-09 | 优化 HarmonyOS 设备检测 |
| 15.4.2.300 | 2025-11-18 | CPU trace 支持 HarmonyOS 6.0；Graphics Profiler 更新；Editor 下线高性能模式 |
| 15.3.2.300 | 2025-09-19 | Editor 支持测试中抓帧 |
| 15.1.2.300 | 2025-05-12 | Editor 独立采集 CPU trace/火焰图；Device 支持报告上传与暂停；Device 下线时延/帧率测试 |

### 2.9 FAQ / 坑

- 「正在连接采集器」：安装路径含中文/空格；卸载重装到纯英文无空格路径。
- USB 调试：开发者模式 → USB 调试 + 仅充电模式下允许 ADB 调试 → USB 连接选「仅充电」。
- USB 切 Wi-Fi 后设备断开：连接时不要选「文件传输」，选「仅充电」。

## 3. GPM

- SDK 接入后低功耗采集游戏运行时性能：流畅度、硬件、系统性能、场景相关指标。
- 数据经华为服务器分析，在 HarmonyOS 开发者中心以多维度可视化图表展示。
- 支持按机型/版本/场景过滤。

## 4. PGA

- 解决响应慢、动作不流畅、卡顿/功耗问题：把 **C# 代码转成更高效的本地代码**（自研毕昇编译器），并用 SIMD、别名分析优化。
- 支持的函数语言：**HPC#（High Performance C#）**；兼容 Burst 遗留项目；新项目用 `[PGACompile]` 标记待优化函数。
- 流程：准备 → 游戏接入 PGA → 执行优化 → 打包为 OpenHarmony 工程并确认生效 → 测试/验证收益（可用 HiSmartPerf 量化）。

## 5. PGP

- 面向 **麒麟芯片 + HarmonyOS 6.0+** 的引擎级管线：把芯片与系统能力固化到游戏引擎，优化渲染管线/资产管线。
- 交付形态是一组解决方案 SDK，例如**动态渲染 SDK**。
- 目标：更流畅、画面更好、功耗更低。

## 6. PGD

- **ECS（Entity Component System）** 高性能框架，数据与行为解耦。
- 核心模块：World / Entity / Component / Archetype / Tag / System / Query / CommandQueue / Relation / Lookup / Batch / Hybrid。
- 辅助工具：Relationship Window（System/Component/Entity 依赖可视化）、PGD Profiler（引擎 Profiler 的 System 维度）、ECS Converter（ECS → PGD）、PGD Editor。
- 数据组织：同组件组合的实体归入同一 Archetype，组件数据按 **SoA** 连续存储，提高 CPU 缓存命中与 SIMD 利用率。
- 语言：C#；支持团结引擎；流程：导入 Package → 用 PGD API/辅助工具开发。

## 7. AILOD

- LOD 资产生成插件：按距离切换模型细节，降低渲染开销。
- AI 自动几何简化，在保证视觉质量下降低多边形数；支持单个/批量任务。
- 端云协同：Editor 采集模型/配置并预处理，云端按目标精度与保留规则生成 LOD。
- 仅 Windows 上的团结 Editor；流程：准备 → 创建任务 → 下载结果 →（可选）相似度评测。
- 注意：蒙皮模型要在减顶点的同时尽量保持形变效果。

## 8. 二进制优化服务

- 对 **C++ 编译的二进制**（加壳/加密除外）做优化，**无需改源码**；利用时间/空间局部性 + 处理器动态运行信息。
- 流程（首次/大版本）：准备 → 二进制插桩 → 选典型场景（打斗/团战/闯关）→ 采集 profile → 执行优化 → 验证收益（HiSmartPerf-Editor 量化）。
- 小版本：直接用最近大版本 profile 执行优化 → 验证。
- 官方称实现业界首个无需源码的 **AARCH64 二进制静态插桩**。

## 9. APMS

- 全链路质量保障：故障指标 → 告警 → 分析 → 质量报告。
- 可视化多维指标大盘（稳定性/性能/功耗）；告警支持短信/邮件/Webhook；基于故障模式库做根因诊断与聚类。

## 10. 游戏场景感知

- API 让游戏与系统交互：向系统发送游戏信息；从系统获取设备状态。
- 通过感知场景/运行状态差异化调度系统资源，做更精细优化。
- 入口：Game Service Kit；HarmonyOS 3.1/4.0 及以下用 GameTurbo Engine。

## 11. 选型速查

| 目标 | 首选 |
| --- | --- |
| 快速看 FPS/功耗/温度/负载 | HiSmartPerf-Device |
| 定位掉帧/卡顿/GPU 过载/温控 | HiSmartPerf-Editor（FPS + GPU counter + CPU trace + 温度/功耗） |
| 线上持续采集、看机型/版本报表 | GPM |
| C# 游戏 CPU 优化 | PGA |
| 麒麟 + HarmonyOS 6.0+ 引擎渲染/资产管线 | PGP |
| 游戏逻辑 ECS 重构/高性能架构 | PGD |
| 3D 模型减面/LOD | AILOD |
| C++ 二进制无源码优化 | 二进制优化服务 |
| 线上质量监控/告警/根因 | APMS |
| 游戏内场景感知与资源调度 | 游戏场景感知 |

## 12. 口径与边界

- 平台支持表的勾选状态在页面中是图片/空单元格，本文只写官方能力描述明确覆盖的平台（HarmonyOS 5.0+、HarmonyOS 3.1/4.0 及以下、Android、快游戏）；iOS 在表中列出但能力描述未提，未据此下结论。
- 仅 HiSmartPerf 业务介绍明确写「免费」；GPM/PGA/PGP/PGD/AILOD/二进制优化/APMS 的收费与开通条件未在本次抓取页面中确认。
- HiSmartPerf-Device 自 15.1.2.300 起下线时延测试、帧率测试；Editor 自 15.4.2.300 起下线高性能模式。
- 部分页面是「总览 + 子页」结构；本文以总览与关键子页为准，未逐页展开所有操作细节。

## 来源

- [游戏性能分析与提升](https://developer.huawei.com/consumer/cn/doc/doccenter-games/games-improve-performance-0000002287068065)
- [游戏性能诊断（HiSmartPerf）](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/smartperf-tool-0000001873208929)
- 关键子页：业务介绍、版本更新说明、下载工具、Editor（准备工作/设置采集要求/采集性能数据/性能分析/整机测试/其他工具）、Device、成功案例、FAQ、附录；GPM/PGA/PGP/PGD/AILOD/二进制优化/APMS/游戏场景感知业务介绍。
