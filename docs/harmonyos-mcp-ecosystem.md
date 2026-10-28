# 鸿蒙（HarmonyOS）开发 MCP 生态

> 适用前提：给鸿蒙应用开发接 AI agent 工具链时，要回答「有哪些 MCP、模拟器能不能用 MCP 驱动、该装哪条线」。
> 本文所有版本号 / 下载量 / star 数 / 工具清单均为 2026-10-16 实测（npm registry、gh API、官方 README、
> 本机 DevEco Studio 26 二进制与 stdio 握手），非训练记忆；华为工具链迭代快，引用前请复核「来源」。
> 引用块内为官方文档**逐字原文**。
> 2026-10-20 增补：官方 CLT 26.0.0.851 的 `Emulator`/`hdc` 路径与本机 PATH 配置已补入 §4.1。

## 核心结论

1. **官方路线已 CLI 化**：华为 2026 HDC 发布 `@deveco/deveco-cli`（内置 ohpm / hvigor / hdc / emulator / hilog），
   MCP 只是它的一个子命令（`devecocli serve mcp`，15,099 下载/月）；社区曾最流行的第三方封装
   `deveco-toolbox`（146★）因此归档让位。
2. **模拟器 / 设备自动化以 CLI 为准、不引入 MCP**：`devecocli`（内置 emulator / hdc / hilog）+ 官方 CLT 或
   DevEco 自带的 `Emulator` 二进制 + 设备侧 `uitest` 即全流程可用（见 §4.1）。本机曾评估的 codegenie MCP 已于
   2026-10-19 移除（修复方案经测试判定不可用），其工具组 / 环境变量 / 工具清单细节不再适用，勿再引用。
3. **社区生态在主流注册表里几乎是空白**：`punkpeye/awesome-mcp-servers` 与 `modelcontextprotocol/servers`
   对 harmony/鸿蒙/ohos/arkts/deveco/hdc **全部零命中**；`mobile-next/mobile-mcp`（9.5k★）未支持鸿蒙
   （仅 2026-10-12 一条 open issue）。发现渠道实际是 npm + GitHub + 中文社区。
4. **三个已废弃/陷阱不要碰**：PyPI `harmonyos-mcp`（2KB 空壳，与 npm 同名包无关）、`deveco-toolbox`（已 archived）、
   `@midscene/harmony-mcp`（官方宣布退役，要 MCP 只能钉 1.9.8）。
5. **兜底路径不依赖任何 MCP**：官方 CLT 或 DevEco Studio 自带的 `Emulator` 二进制本身就是完整控制面
   （`-start/-stop/-instance` + `-screenshot/-uiLayout/-click/-slide/-fill`），配 `hdc` 与设备侧 `uitest`
   即可全流程自动化；DevEco Studio 还自带 JetBrains MCP Server 插件（见 §4.1）。

## 一、官方件

### 1.1 @deveco/deveco-cli —— `serve mcp`（官方主推路线）

- 包内 README 原文：> `DevEco CLI` 将 `DevEco Studio` 工具链统一封装为一个 `CLI`，内置 `ohpm`、`hvigor`、`hdc`、`emulator`、`hilog`，同时集成 HarmonyOS 技能安装、项目脚手架、本地 HarmonyOS 文档检索和 `MCP` 服务。
- MCP 形态：`devecocli serve mcp` 起 stdio server（服务器自名 `devecocli-mcp-server`），
  工具面偏代码理解。官方文档列 9 个：`check`（静态分析）/ `hover` / `definition` / `declaration` /
  `references` / `implementation` / `workspaceSymbol` / `documentSymbol` / `callHierarchy`；
  本机 `tools/list` 另有 `restart`（共 10 个）。构建 / 装机 / 模拟器 / 日志留在 CLI 子命令层。
- 经验提示：不要把 `serve lsp` 与 `devecocli serve mcp` 同时接入同一个智能体——两者会各自拉起一份 ace-server/clangd 实例，内存翻倍；请在直连 LSP 与 MCP 中二选一，推荐 MCP。
- 前置要求：**DevEco Studio 26.0.0 Release+、DevEco CLI 1.3.0+、Node ≥ 22**；
  npm 包 MIT，截至 2026-10-28 最新 **1.3.9**（2026-10-16 快照为 1.3.5，近 30 天 15,099 下载）；
  真实现在平台子包 `@deveco/deveco-cli-common`（macOS/Linux/Windows）与
  `@deveco/deveco-cli-openharmony-arm64`（供 OpenHarmony 设备侧运行）。
- 主仓：gitcode.com/openharmony-sig/deveco-cli（官方 SIG 组织）。

### 1.2 Hypium 设备测试 MCP —— 白皮书已挂清单，截至 2026-10-16 未公开分发

- 出处：鸿蒙生态测试白皮书「功能场景测试 → Hypium设备测试MCP工具」章节
  （`guidebook/hoetwp-capability-functiontest3-0000002594762528`，章节更新 2026-06-12），
  定位 = 标准 MCP 协议封装 Hypium 设备测试能力，供 AI Agent 驱动真机/模拟器执行测试。
- 工具面（白皮书列 30 个，按模块）：basic（start_app/stop_app/double_click）、screen（unlock_screen/
  screen_on/rotate_screen）、app_manager（install_app/uninstall_app/get_current_app）、toast
  （start_listen_toast/get_toast）、general_gesture（pinch_in/pinch_out/rotate_gesture）、system_gesture
  （open_notification_center/enter_recent_task/drag_to_xiaoyi）、observation（screenshot 仅 jpg/layout/
  find_elements）、plugins（start_data_collect/stop_data_collect/generate_report）、clipboard
  （write/read/clear_clipboard）、settings（set_view_mode）、shell（execute_shell_command/pull_file/push_file）。
  🌟 捏合/旋转/Toast/剪贴板/深浅色是 `devecocli ui` 当前缺的能力（现有 layout/window/screenshot/click/
  doubleclick/longclick/swipe/fling/drag/dircfling/text）——Hypium 补齐精细手势与设备状态操作。
- 🌟 **获取现状（2026-10-16 实测）：未公开分发**。证据链：DevEco Testing Hypium 26.0.0.500 Release
  公共包（2026-08-29 发布，晚于白皮书章节更新）解剖三组件均无 MCP server——Python 框架 wheels 无
  server 模块、HypiumAssist PyCharm 插件 jar 无 mcp 类且不含工具名字符串、hypium-driver tgz 无 MCP 依赖；
  npm 候选包名（hypium-mcp/@deveco/hypium-mcp 等）全 404；`devecocli serve mcp` 是代码理解服务
  （check/LSP 共 10 工具）；DevEco Testing 26.0.0 版本说明无 MCP 字样。判断：白皮书先于公开发布，
  预计随 DevEco Testing 云端渠道或后续版本放出——接入前先复核本节证据。
- 已可得的底座：**hypium-driver**（npmjs 公共版 6.1.210；26.0.0.500 安装包内附新版离线 tgz，
  `npm i -g ./hypium-driver-26.0.0500.tgz`）。要求 Node ≥20；`UiDriver.connect({ deviceSn })` 连设备
  （不传 SN 默认取 `hdc list targets` 首个）；API 模块 app_manager/screen/system/storage/uinput/hilog/
  netcopilot + uitest（uidriver/by/uicomponent/uitree/uiwindow）+ turbo AI 代理（qwen_vl/ui_tars/
  gui_agent）+ scrcpy gRPC 投屏；完整接口见包内 `api_reference.md`（112KB）。自建薄 MCP server 的
  映射基底即此库，是否立项属中等工程需单独定案。
- 🌟 下载中心直链配方（通用）：华为下载中心页面 DOM 无 href，版本卡点击触发
  `svc-drcn.developer.huawei.com/svc/community/common/v1/delegate` XHR（svc=
  `PartnerCommunityService/v1/developer/downloadCenter/getToolVersionDownloadUrl`，reqJson 带
  sdkId/versionId/packageId），响应含 dbankcdn 带签名直链（7200 秒时效）——浏览器钩 XHR 即可拿到。

## 二、社区方案（模拟器 / 设备自动化）

| 方案 | 定位 | 关键事实（2026-10-16 实测） |
| --- | --- | --- |
| `callstack/agent-device` | 跨平台移动自动化 MCP（iOS/Android/鸿蒙/…） | ★5,028，MIT，npm 0.21.x，月下载 103 万；鸿蒙走 HDC + ArkUI `uitest`，官方自述鸿蒙覆盖为 "subset of commands"；**不启停模拟器** |
| `AlexGladkov/claude-in-mobile` + `@mcp-devices/plugin-harmony` | 插件化设备自动化 MCP | 仓库 ★377（另含 Android/iOS/Desktop 模块，仓库描述未提鸿蒙但插件包与文档都在）；插件 npm 4.4.1 MIT；鸿蒙走 HDC + ArkXTest（tree/find/find_tap/wait + logs）；**不启停模拟器** |
| `Eilgnaw/harmonyos-mcp` | 鸿蒙专用，第三方工具面最全 | ★23，MIT，npm 0.3.0；封装 DevEco `Emulator` 启停（`emu_list/emu_start/emu_stop`）+ `build_install_launch` + `wait_for_ui` / `wait_for_log`；**2026-05-11 后停更** |
| `Deslord319/harmonyos-dev-mcp` | 纯 Python（PyPI） | ★12，**无 License**；18 工具（build/install/click/swipe/input/354 KEYCODE/find_elements/logs_query），无模拟器生命周期、无模拟器字样 |
| `LeonTing1010/hap-deploy-cli`（haplane） | HAP 签名 → 装机专精 | npm 0.4.1 MIT；13 个 MCP 工具，封装 `hvigorw` + `hap-sign-tool` + `hdc`，带 `--dry-run`；主仓在 Gitee |
| `ui-verification-mcp` | 自然语言 UI 校验 | npm 0.0.19 MIT，2026-10-15 仍在更新；单工具 `verifyUI`，需自配视觉模型 |
| `megaacheyounes/ohos-mcp-unofficial` | 英文文档检索 | ★3，MIT；索引 5,000+ 篇 OpenHarmony/HarmonyOS 英文文档，npx 零安装 |
| `FadingLight9291117/mcp-harmonyos` | 工程/设备只读侦查 | ★2，MIT，npm 1.1.0；无 UI 操作与日志 |

注册表覆盖：官方 MCP Registry 仅 1 条 harmonyos 记录（上表末条）；mcp.so 仅 1 条（XixianLiang）；
glama.ai 收录最多（十余条）；smithery.ai 零结果；awesome 列表与官方 servers 仓库零命中。

## 三、避坑清单（全部实测）

- **PyPI `harmonyos-mcp` 是 2KB 空壳**：wheel 仅 2,068 字节，METADATA 除 Name/Version 外全空；
  两个"工具"返回硬编码字符串（`get_config_env_pwsh` 返回一段 PowerShell 文本、`get_build_cmd_prefix`
  直接 `return 'hvigorw'`）。与 npm 上的 `harmonyos-mcp`（Eilgnaw 项目）**毫无关系**，同名陷阱。
- **`open-deveco/deveco-toolbox` 已归档**（★146，曾是最热第三方鸿蒙 MCP）。README 原文：> 在2026年的HDC大会上，华为官方正式发布了DevEco CLI（鸿蒙能力命令行工具）。经过我们的试用，相较于 MCP 方案，命令行方式在 Agent 场景下更具优势，且官方工具已覆盖我们现有工具，包括LSP静态语法检查在内的绝大部分能力。… 鉴于此，我们决定后续不再对该 MCP 工具进行深度功能迭代
- **`@midscene/harmony-mcp` 官方退役**。官网原文：> **MCP integration has been retired** / **Midscene no longer ships MCP servers.** / If you still need the MCP server packages, **pin Midscene to 1.9.8**. This is the final version that includes MCP support.
  Midscene 本体（★15,293，活跃）仍支持鸿蒙自动化，但路线已改为 Skills + 平台 CLI（`@midscene/harmony`），不走 MCP。
- **`XixianLiang/HarmonyOS-mcp-server` 事实废弃**：★35（纯鸿蒙 MCP 里 star 最高、mcp.so 唯一收录），
  但最后提交 2025-08-18、release 停在 v0.1.0、无包管理器分发。
- **`bubbleptr/harmony-tools`（2025-11 停更）**及一批 0★ / 无 License / 单日提交的玩具仓库
  （`harmony-mcp-tools`、`harmonyOS_mcp_explorer`、`cross-dev-mcp` 等）不要选；
  选型最低门槛：有仓库、有 License、近 3 个月有提交。
- **通用移动 MCP 未支持鸿蒙**：`mobile-next/mobile-mcp`（★9,554）无鸿蒙支持（open issue #503）；
  `appium/appium-mcp` 搜 harmony 零结果。

## 四、落地方式

### 4.1 零依赖兜底：官方 CLT / DevEco 自带控制面

- **`Emulator` 二进制**（官方 CLT：`~/Library/Huawei/command-line-tools/bin/Emulator`；
  DevEco 内置：`/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator`）：`-start/-stop/-list`（实例生命周期）、
  `-create/-delete`（实例创建/删除）、`-imageList/-install/-uninstall`（镜像）；
  `-instance <name>` 下的 `-screenshot/-screenshotPath/-uiLayout/-click/-slide/-fill/-power/-volume/-rotation`、
  `-hdcPort/-hvd/-logZip`——模拟器启停、截图、UI 布局、点击滑动的原子命令全在。
- **`hdc`**（官方 CLT：`~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc`，本机已在 PATH；
  DevEco 内置：`Contents/sdk/default/openharmony/toolchains/hdc`）：装机、shell、hilog、文件传输。
- **设备侧 `uitest` / `aa`**：`screenCap -p`、`dumpLayout`、`uiInput click/inputText/...`、`aa start`，模拟器与真机通用。
- **DevEco Studio 自带 JetBrains MCP Server 插件**（`Contents/plugins/mcpserver/lib/mcpserver.jar`，
  插件 id `com.intellij.mcpServer`）：可把 IDE 的构建 / run 配置暴露给外部 agent。
- 已知模拟器坑：首次冷启动可能 >60s；模拟器大多不需要签名，但部分 Kit 仍需签名（官方 FAQ `faqs-simulator-4`）；`uitest dumpLayout` 会隐藏软键盘正下方节点；
  `hdc list targets` 状态列会把部分已连接设备误报 `Offline`，判定可用性别只信状态列。

## 来源

| 内容 | 来源 |
| --- | --- |
| deveco-cli 包与 `serve mcp` / 前置要求 / lsp 与 mcp 二选一 | https://www.npmjs.com/package/@deveco/deveco-cli （包内 README）；https://gitcode.com/openharmony-sig/deveco-cli |
| npm 下载量与版本时间 | https://api.npmjs.org/downloads/point/last-month/...（@deveco/deveco-cli 15,099；agent-device 1,030,550） |
| 仓库 star / 活跃度 / 归档状态 | gh api repos/callstack/agent-device、Eilgnaw/harmonyos-mcp、open-deveco/deveco-toolbox、XixianLiang/HarmonyOS-mcp-server、AlexGladkov/claude-in-mobile、mobile-next/mobile-mcp、Deslord319/harmonyos-dev-mcp、web-infra-dev/midscene（2026-10-16） |
| Midscene MCP 退役声明 | https://midscenejs.com/mcp |
| 注册表收录情况 | punkpeye/awesome-mcp-servers 与 modelcontextprotocol/servers 的 README grep；mcp.so / smithery.ai / glama.ai 检索（2026-10-16） |
| 本机兜底控制面 | CLT 26.0.0.851 / DevEco Studio 26.0.0（build 2600851）：`Emulator --help`、`hdc -h`、设备侧 `uitest help` / `aa help`、`Contents/plugins/mcpserver/` 实测 |
