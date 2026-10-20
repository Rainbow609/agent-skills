# DevEco Studio 命令行工具链：Command Line Tools / hvigorw / codelinter

> 适用前提：回答「CI 或纯命令行下怎么构建、怎么跑静态检查、hvigorw 有哪些参数」。
> 核实自官方知识库《工具概述》《获取Command Line Tools》《搭建流水线》《命令行构建工具（hvigorw）》《代码检查工具（codelinter）》
> 及 codelinter FAQ（devecocli docs，2026-10-16；DevEco/CLT 定位与本机安装状态核对 2026-10-20）。

## Command Line Tools（CLT）：命令行工具全家桶

- **CLT 集合**：`codelinter`（代码检查）、`hstack`（堆栈解析）、`hvigorw`（构建）、`ohpm`（依赖管理）、`arktsdoc`（文档生成）
  + **SDK 已嵌入**（无需另配）。下载中心获取，解压后把 `command-line-tools/bin` 配进 PATH。
- 🌟 与 DevEco Studio **GUI 版内嵌工具的差别**：两者是「开发态 vs 命令行/CI 态」，不是替代关系。
  官方明确打包进 DevEco 的是 SDK、Node.js、Hvigor、OHPM、模拟器平台；`hstack` 不在里面，
  `codelinter` 是 IDE 插件而非 CLI 命令，`hvigorw`/`ohpm` 散在内部目录且没有统一 `bin`。
  要 CLI/门禁/流水线走 CLT，别从 Studio 包里凑。
- **本机安装（2026-10-20）**：官方 CLT 26.0.0.851（mac-arm64）位于
  `~/Library/Huawei/command-line-tools`，PATH 指向 `bin` 与
  `sdk/default/openharmony/toolchains`（hdc）。版本：hstack 6.1.0 / codelinter 6.0.240 /
  hvigor 6.26.8 / ohpm 26.0.0.630 / HarmonyOS SDK 26.0.0.105（API 26）/ 内置 Node 24.14.1；
  Java 仍用 DevEco 自带 JBR 25（CLT 不含 JDK；官方《搭建流水线》对 CLT 26.0.0+ 推荐 JDK 21，
  JBR 25 实测可用，但严格复现 CI 时应切 JDK 21）。
- **下载门槛**：下载中心要求华为账号登录，常见还要实名与协议；官方包约 2GB 压缩、解压后 6.5GB。
  解压后文件带 `com.apple.quarantine`，且许多文件是只读权限，直接 `xattr -dr` 会部分失败；
  需先临时 `chmod -R u+w`、清完 xattr 再恢复原权限（本机已按此处理，剩余隔离属性为 0）。
- **hstack 版本差异**：26.0.0 起为 6.1.0，支持直接传单个 crash/sourceMap/.so/nameCache 文件，
  不再强制目录；新增 `-k/--keep-raw-on-failure`。旧版 5.1.0 只接受目录。

### DevEco Studio 自带工具 vs 官方 CLT

**官方明确打包进 DevEco 的**（《下载与安装 DevEco Studio》）：
> DevEco Studio 提供开箱即用的开发体验，将 HarmonyOS SDK、Node.js、Hvigor、OHPM、模拟器平台等进行合一打包。

**官方对命令行场景的推荐**（《工具概述》）：
> 针对流水线或命令行开发场景，推荐使用 Command Line Tools，其中集合了 HarmonyOS 应用开发所用到的系列工具，包括代码检查工具 codelinter、三方包管理工具 ohpm、堆栈解析工具 hstack、命令行构建工具 hvigorw。

**官方对 CLT 的定位**（《获取 Command Line Tools》）：
> Command Line Tools 集合了 HarmonyOS 应用开发所用到的系列工具……以及 SDK 中包含的一系列工具。
> HarmonyOS SDK 已嵌入命令行工具中，无需额外下载配置。

**本机对照（2026-10-20）**：

| 能力 | DevEco Studio 内 | 官方 CLT |
| --- | --- | --- |
| HarmonyOS SDK | `Contents/sdk` | `sdk/` |
| Node.js | `Contents/tools/node` | `tool/node` |
| hvigorw | `Contents/tools/hvigor/bin/hvigorw` | `bin/hvigorw` |
| ohpm | `Contents/tools/ohpm/bin/ohpm` | `bin/ohpm` |
| codelinter | `Contents/plugins/codelinter`（IDE 插件） | `bin/codelinter` |
| hstack | **无** | `bin/hstack` |
| 模拟器 | `Contents/tools/emulator` | `bin/Emulator` |
| arktsdoc | `Contents/tools/arktsdoc` | `bin/arktsdoc` |
| JDK | 自带 JBR 25 | **不含**；26.0.0+ 官方推荐 JDK 21 |

**为什么不能只靠 DevEco**：
- 官方支持边界：CLI/流水线/门禁文档统一指向 CLT，DevEco 内部 `tools/` 不是文档承诺的 CLI 接口。
- `hstack` 只在 CLT；`codelinter` 的 CLI 入口也只在 CLT（IDE 里是插件）。
- Linux CI：DevEco 只支持 Windows/macOS，CLT 支持 Windows/Linux/macOS，构建机不需要装 GUI IDE。
- CLT 自带统一 `bin` 和包内 Node/SDK，CI 可独立锁定版本，不依赖开发机是否装 IDE。
- 官方《搭建流水线》原话：「除了使用 DevEco Studio 一键式构建应用/元服务外，还可以使用命令行工具来调用 Hvigor 任务进行构建……可用于构建 CI 流水线」。

## hvigorw 命令面（构建）

格式 `hvigorw [taskNames...] <options>`；5.18.4 起 `-v/--version/-h` 可在任意路径执行，
**其余命令须在工程根目录**。

**常用任务**：`clean` / `assembleHap` / `assembleApp` / `assembleHsp` / `assembleHar` / `collectCoverage`（覆盖率报表）。

**构建模式默认值矩阵**（缺省时）：Hap/Hsp/Har → **debug**；App → **release**。
`-p buildMode=debug|release` 显式指定；`-p debuggable=true|false` 覆盖 buildOption 同名项。

**常用扩展参数**：

| 参数 | 用途 |
| --- | --- |
| `-p product={Name}` | 指定 product（缺省 default） |
| `-p module={Module}@{Target}` | 指定模块及 target，逗号隔开多模块；**须配 `--mode module`** |
| `-p ohos-test-coverage=true` / `-p coverage=true` | 测试覆盖率插桩编译 |
| `-p parameterFile=param.json5` | oh-package 参数配置文件（多环境依赖版本切换） |
| `-p buildVersion=N` | 构建版本号（hvigorw 6.23.3+） |

**daemon**：命令行模式**推荐 `--no-daemon`**（默认开守护进程）；`--stop-daemon-all` 清所有、
`--status-daemon` 查状态；`--max-old-space-size=N` 调守护进程内存。

**构建分析**：`--analyze=normal|advanced|ultrafine`（ultrafine 从 6.0.0 起，ArkTS 阶段更细打点、
更慢）；`--config properties.hvigor.analyzeHtml=true` 在 `.hvigor/report/` 生成可视化 html。

**性能/内存**：`--optimization-strategy=performance|memory`（5.19.2+，默认 memory）；
`--parallel` / `--incremental` 默认开，`--no-*` 可关。

**查询与维护**：`tasks`（任务清单）、`taskTree`（任务依赖树）、`buildInfo [-p module=X -p buildOption -p json]`
（打印 build-profile 生效配置树，5.18.4+）、`prune`（清 30 天未用缓存）。

**其他**：`-m/--mode module|project`（任务作用域）、`--type-check`（hvigorfile.ts 类型检查，默认关）、
`--watch`（预览/热加载）、`--stacktrace`（默认关堆栈）。

## codelinter（命令行静态代码检查，CI 门禁现成件）

格式 `codelinter [options] [dir]`（dir 缺省为当前目录；可多个文件/目录）。

| 指令 | 用途 |
| --- | --- |
| `-c/--config <filepath>` | 指定规则配置文件（`code-linter.json5`）；不指定用默认规则集 |
| `--fix` | 检查同时执行 QuickFix 自动修复 |
| `-i/--incremental` | 🌟 **只检查 Git 增量文件**（新增/修改/重命名）——本地迭代与流水线提速正解 |
| `-f/--format` | `default/json/xml/html` 输出格式 |
| `-o/--output <filepath>` | 结果落文件（不再打印到命令行） |
| `-p/--product` | 多 product 工程指定生效 product |
| `-e/--exit-on` | 🌟 **指定哪些告警级别返回非零退出码**——CI 门禁判定用，见下 |

**`--exit-on` 退出码机制**：3 位二进制从高到低表示 error/warn/suggestion，命中则置 1 再转十进制
（如 `--exit-on error` 且结果有 error+warn+suggestion → `100b`=**4**；无 error → 0）。
流水线判「有 error 就失败」：`codelinter -e error`。

**JSON 结果字段**（`-f json`）：`[{filePath, messages:[{line, column, severity, message, rule}]}]`；
rule 形如 `@performance/foreach-args-check`（性能规则集）——机器解析友好。

**与 manbo 现状的关系**：`devecocli check arkts` 是 devecocli 自带 linter（140 条存量误报、
不支持配置与行内抑制）；codelinter 是官方正规件（规则集可配、可增量、可自动修复、有退出码）——
**装 CLT 后可原型验证 codelinter 对本工程的误报/覆盖情况**，作为「只扫改动文件」策略的替代或补充。
注意 codelinter 是静态规则（含性能/安全规则集），与 ArkTS 语义编译检查互补，不互替。

## 工程配置与构建实测坑（2026-10-19，新建工程 `ai-quota-harmony` 首次构建实测）

- **`compatibleSdkVersion` / `targetSdkVersion` 语法分代**：**API ≥ 26 改用点分制** `"26.0.0"`；
  旧括号写法（如 manbo 的 `"6.1.0(23)"`）**只适用 API ≤ 25**。写错直接构建失败：
  `00308018 api version parameter is illegal`（hvigor 内部校验 major 必须两位数，
  形如 `^([2-9][0-9])\.[0-9]{1,2}\.[0-9]{1,2}$`）。跨基线拷 `build-profile.json5` 时先改这行。
- **`assembleHap` 必须配 `--mode module`**：`--mode project` 下报
  `00306054 Task assembleHap not found`（project 作用域只挂 `assembleApp`）。实测 hvigor 6.26.8。
- **纯命令行最小构建配方（macOS，官方 CLT 26.0.0.851）**：
  ```bash
  export DEVECO_SDK_HOME="$HOME/Library/Huawei/command-line-tools/sdk"
  export JAVA_HOME="/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home"
  hvigorw --mode module -p product=default -p buildMode=debug assembleHap --no-daemon
  ```
  CLT 的 `bin/hvigorw` 在 `DEVECO_NODE_HOME` / `DEVECO_SDK_HOME` 未设置时会自动指向包内
  `tool/node` 与 `sdk`；`JAVA_HOME` 仍需显式给（PackageHap/签名阶段用）。
  实测增量 1–4 秒出 30 KB 的 `entry/build/default/outputs/default/entry-default-unsigned.hap`。
- **构建前必须给 `JAVA_HOME`**：`PackageHap` 阶段会报 `Unable to locate a Java Runtime`（错误码同为 `00308018`），
  指向 DevEco 自带 JBR 即可：`export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home`。
  连同 `DEVECO_SDK_HOME`，这两个 env 是纯命令行构建的最小前置（实测签名 HAP 68289 字节 vs 未签名 30573 字节）。
- **签名是命令行路线的第一道硬门槛**：未配 `signingConfigs` 时只能产出 `*-unsigned.hap`，
  装机报 `bm install` → `code:9568320 error: no signature file`。**`.p7b` profile 内嵌 bundleName，
  不能跨包名复用**（实测 manbo 的 profile 内是 `com.itling.manbo`）。新包名必须先在 DevEco 里
  `File > Project Structure > Signing Configs > Automatically generate signature`（需登录华为账号，
  首次连真机/模拟器完成设备注册），材料落 `~/.ohos/config/default_<project>_*`；
  工程里只以**绝对路径**引用，勿把证书/私钥/口令提交入库（可用 `skip-worktree` 管理本地差异）。
- **ArkTS 严格编译实测第一批坑**（新工程首构建就会撞上）：`arkts-limited-throw`（禁止 rethrow，
  要包成 `new Error`）、`Map.get()` 返回联合类型需 `instanceof` 收窄、`util.TextDecoder.decodeWithStream`
  已废弃 → 用 `decodeToString`。
- **模拟器命令行**（官方 CLT 的 `~/Library/Huawei/command-line-tools/bin/Emulator`，
  或 Studio 内置的 `/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator`）：
  `-list` / `-create` / `-start <name> -noWindow` / `-stop` / `-instance <name> -uiLayout|-click <x y>|-screenshot`——
  可全程无 GUI 驱动设备；`-imageList` 查镜像是否已下载（镜像在 `~/Library/Huawei/Sdk/system-image`）。
  实测两点：① **DevEco 自动签名的 debug profile 可直接装到模拟器**（无需再为该模拟器单独注册设备）；
  ② 模拟器 shell 无 root（uid 2000），`ifconfig eth0 down` / `svc data` 均被拒——**要造「断网」场景只能走控制中心 UI 点飞行模式**。
  ③ 要造「定点时刻」场景（服务卡片的整点翻转等）：**改时钟、不要改时区**。保持设备
  `GMT+08:00`，在设置 → 日期和时间关闭「自动设置」，把时间拨到目标点前 1–2 分钟
  （实测 17:58 → 18:00 触发）；判定若按规则集时区而刷新按设备本地时钟，改时区会让两者错开
  （曾把时区改到 GMT+3，本地 18:00 = 上海 23:00，前后都是平峰，端到端翻转观察不到）。
  测完把「自动设置」打开，系统会同步回真实时间。
  服务卡片的 `multiScheduledUpdateTime` 触发可在 `hilog -T aiquota-widget` 看到 `onUpdateForm`
  （实测 18:00:00.234/.252 两个 formId 命中）。
  ④ 多设备/多模拟器同时在线时 `hdc` 会报 `need connect-key`；所有命令显式加
  `-t 127.0.0.1:5555`（或对应 `IP:PORT`）。
- **CLT 与 DevEco 共用同一批模拟器实例**（2026-10-20 实测）：`Emulator -list` 在官方 CLT 与
  DevEco 内置入口下输出完全一致（本机 Mate 90 Pro / MatePad Pro 13 / Pura X Max）；默认实例路径
  macOS 为 `~/.Huawei/Emulator/deployed`，`-instancePath` 不指定时用 DevEco 的实例路径；
  `-imageRoot` 不指定时用 DevEco 的镜像路径。若在 Device Manager 改过 Local Emulator Location，
  CLI 需显式传 `-instancePath`；镜像改过则传 `-imageRoot`。`-delete` 删除的是共享实例，
  勿误删 DevEco 正在用的模拟器。
- **真机与模拟器**：`hdc list targets` 出 `IP:PORT` 形式即无线调试设备；本机真机
  HarmonyOS 7.0.0.109 = **API 26**，可直接验证 API 26 基线能力（沉浸光感 `uiMaterial`）；
  模拟器镜像在 `~/Library/Huawei/Sdk/system-image`（HarmonyOS-6.1.1 / 7.0.0）。

## 官方文档（devecocli docs 检索 ID）

- 官方原文（2026-10-20 复核）：
  - 下载与安装 DevEco Studio（官方打包清单）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-software-install
  - 工具概述（DevEco vs CLI 定位）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-tools-overview
  - 获取 Command Line Tools：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-commandline-get
  - 搭建流水线（CI/JDK 要求）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-command-line-building-app
  - 下载中心：https://developer.huawei.com/consumer/cn/download/command-line-tools-for-hmos
- 获取 Command Line Tools：`开发指南/获取Command_Line_Tools/ide-commandline-get`
- 命令行构建工具（hvigorw）：`开发指南/命令行构建工具_hvigorw/ide-hvigor-commandline`
- 代码检查工具（codelinter）：`开发指南/代码检查工具_codelinter/ide-command-line-codelinter`
- codelinter IDE 外使用 FAQ（含 json 样例）：`FAQ/命令行工具/使用codelinter实现IDE外静态代码分析/faqs-command-line-tool-22`
- 🌟 URL 提示：文档站网页 slug 与知识库 documentId 不一致是常态（如网页
  `ide-command-line-building-app` ↔ 知识库 `ide-hvigor-commandline`），一律以 `docs search` 结果为准。
