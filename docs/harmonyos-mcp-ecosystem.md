# 鸿蒙（HarmonyOS）开发 MCP 生态

> 适用前提：给鸿蒙应用开发接 AI agent 工具链时，要回答「有哪些 MCP、模拟器能不能用 MCP 驱动、该装哪条线」。
> 本文所有版本号 / 下载量 / star 数 / 工具清单均为 2026-10-16 实测（npm registry、gh API、官方 README、
> 本机 DevEco Studio 26 二进制与 stdio 握手），非训练记忆；华为工具链迭代快，引用前请复核「来源」。
> 引用块内为官方文档**逐字原文**。

## 核心结论

1. **官方路线已 CLI 化**：华为 2026 HDC 发布 `@deveco/deveco-cli`（内置 ohpm / hvigor / hdc / emulator / hilog），
   MCP 只是它的一个子命令（`devecocli serve mcp`，15,099 下载/月）；社区曾最流行的第三方封装
   `deveco-toolbox`（146★）因此归档让位。
2. **模拟器管理只有官方 `@deveco-codegenie/mcp` 一条现实路径，且必须点名 0.2.6 线**——
   dist-tags 里 `stable`=1.1.11 是精简线（无模拟器工具组），`latest`=`beta`=0.2.6 才是功能全的线（15 工具）。
3. **模拟器工具组要显式激活**：`ADDITIONAL_TOOL_GROUPS=emulator_manager,ui_integration_test`，
   否则 `emulator_image_manager` / `emulator_instance_manager` / `verify_ui` 根本不出现在工具列表里。
4. **社区生态在主流注册表里几乎是空白**：`punkpeye/awesome-mcp-servers` 与 `modelcontextprotocol/servers`
   对 harmony/鸿蒙/ohos/arkts/deveco/hdc **全部零命中**；`mobile-next/mobile-mcp`（9.5k★）未支持鸿蒙
   （仅 2026-10-12 一条 open issue）。发现渠道实际是 npm + GitHub + 中文社区。
5. **三个已废弃/陷阱不要碰**：PyPI `harmonyos-mcp`（2KB 空壳，与 npm 同名包无关）、`deveco-toolbox`（已 archived）、
   `@midscene/harmony-mcp`（官方宣布退役，要 MCP 只能钉 1.9.8）。
6. **兜底路径不依赖任何 MCP**：DevEco Studio 自带的 `Emulator` 二进制本身就是完整控制面
   （`-start/-stop/-instance` + `-screenshot/-uiLayout/-click/-slide/-fill`），配 `hdc` 与设备侧 `uitest`
   即可全流程自动化；DevEco Studio 还自带 JetBrains MCP Server 插件（见 §4.2）。

## 一、官方件

### 1.1 @deveco/deveco-cli —— `serve mcp`（官方主推路线）

- 包内 README 原文：> `DevEco CLI` 将 `DevEco Studio` 工具链统一封装为一个 `CLI`，内置 `ohpm`、`hvigor`、`hdc`、`emulator`、`hilog`，同时集成 HarmonyOS 技能安装、项目脚手架、本地 HarmonyOS 文档检索和 `MCP` 服务。
- MCP 形态：`devecocli serve mcp` 起 stdio server（服务器自名 `devecocli-mcp-server`），
  工具面偏代码理解——`check`（ArkTS/C++ 静态分析）、`check_cpp_files`，以及 LSP 语义类
  `definition` / `declaration` / `hover` / `references` / `implementation`；
  构建 / 装机 / 模拟器 / 日志留在 CLI 子命令层。
- 官方两条硬提示（原文）：> **注意：不要把 `serve lsp` 与 `devecocli serve mcp` 同时接入同一个智能体。** 两者会各自拉起一份 ace-server/clangd 实例，内存翻倍。请在直连 LSP 与 MCP 中二选一，**推荐 MCP**——接入更简单，且自带初始化。
- 前置要求：**DevEco Studio ≥ 6.0.0、Node ≥ 22**；npm 包 MIT，1.3.5，近 30 天 15,099 下载（鸿蒙类最高）；
  wrapper 包仅 2.8KB，真实现在平台子包 `@deveco/deveco-cli-common`（macOS/Linux/Windows）与
  `@deveco/deveco-cli-openharmony-arm64`（供 OpenHarmony 设备侧运行）。
- 主仓：gitcode.com/openharmony-sig/deveco-cli（官方 SIG 组织）。

### 1.2 @deveco-codegenie/mcp —— 唯一带模拟器管理的 MCP

CodeGenie 产线发布的 MCP server（**注意：无公开仓库、无 License 声明**，参数细节以实测 schema 为准）。

**通道陷阱（本文最重要的一条）**：dist-tags 指向两条形态不同的线，工具面实测对比：

| 通道 | 版本 | 发布 | 工具数 | 模拟器工具组 | knowledge_search / project_sync / hilog |
| --- | --- | --- | --- | --- | --- |
| `stable` | 1.1.11 | 2026-06-30 | 7（含 ui 校验组 10） | ❌ | ❌ |
| `latest` = `beta` | 0.2.6 | 2026-06-02 | 10（含两组 15） | ✅ | ✅ |

两边 README 同名同结构（registry 的 readme 字段只反映 latest），**只能靠实测工具列表区分**。
安装必须点名版本：`npm i -g @deveco-codegenie/mcp@0.2.6`，不要写 `@stable`。

**0.2.6 + 两个工具组实测的 15 个工具**：`emulator_image_manager`、`emulator_instance_manager`、
`verify_ui`、`get_ui_verification_log`、`save_ui_screenshot`、`start_app`、`build_project`、
`get_app_ui_tree`、`perform_ui_action`、`check_ets_files`、`check_cpp_files`、`init_project_path`、
`harmonyos_knowledge_search`、`project_sync`、`get_hilog_or_faultlog_recent`。

**两个模拟器工具的参数（实测 inputSchema）**：

- `emulator_image_manager`（镜像管理）：`action` = `list` / `download` / `delete` / `acceptLicense`；
  `os_version` 形如 `"HarmonyOS 6.0.1(21)"`（download/delete 必填）；可选 `device_type`、`downloaded`、`http_proxy`。
- `emulator_instance_manager`（实例管理）：`action` = `create` / `start` / `stop` / `delete` / `list` /
  `collectLogs` / `screenProfileList`；`create` 必填 `device_type`（phone、foldable、tablet、2in1、wearable、tv）
  与 `os_version`，可选 `screen_profile`（如 `"Mate 70"`，先从 `screenProfileList` 查）、
  `memory` 2–32GB、`storage` 2–1023GB；`name` 只允许字母/空格/数字/下划线；`collectLogs` 需 `log_base_path`。
  注意 README 里写的工具名 `emulator_management` 是旧名，**真实工具名是 `emulator_instance_manager`**。

**环境变量**：

| 变量 | 说明 |
| --- | --- |
| `DEVECO_PATH` | DevEco Studio 安装根目录（macOS 示例 `/Applications/DevEco-Studio.app/Contents`），优先级最高，未设则自动扫描常见路径 |
| `PROJECT_PATH` | 工程根路径；也可不设——服务会走 MCP `roots/list` 协议，或由 agent 调用 `init_project_path` 工具按项目设置 |
| `ADDITIONAL_TOOL_GROUPS` | 显式激活额外工具组，如 `emulator_manager,ui_integration_test` |

**`verify_ui` 的额外依赖**：自然语言 UI 校验需要视觉模型（需支持 Function Call），
配 `UI_VERIFY_BASE_URL` / `UI_VERIFY_API_KEY` / `UI_VERIFY_MODEL_NAME` 才能用；
官方说明其操作面目前仅点击/滑动/按键、基于截图判断。🌟 端点选 opencode Go 时的会话头墙
（强制 `x-opencode-session`，原生二进制发不了自定义头）与本地注入代理配方见
[opencode-zen-gateway-session-header.md](opencode-zen-gateway-session-header.md)。

**`start_app` 的关键行为**：设备列表包含已安装但未运行的模拟器，选中会自动启动——不接管
模拟器生命周期也能跑起应用。

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

### 4.1 接入（本仓库已接 `mcp/zcode-mcp.json`）

```bash
npm i -g @deveco-codegenie/mcp@0.2.6   # 必须点名 0.2.6；@stable 是精简线
```

```json
"deveco-codegenie": {
  "command": "/opt/homebrew/bin/codegenie-mcp-server",
  "args": [],
  "env": {
    "DEVECO_PATH": "/Applications/DevEco-Studio.app/Contents",
    "ADDITIONAL_TOOL_GROUPS": "emulator_manager,ui_integration_test"
  }
}
```

验证方法（免开 agent）：对 server 做 stdio 握手（`initialize` → `notifications/initialized` → `tools/list`），
应列出 15 个工具；最小真实调用 `emulator_instance_manager {"action":"list"}` 应返回本机实例列表。
`verify_ui` 需要额外视觉模型密钥（见 §1.2），密钥不入库。

### 4.2 零依赖兜底：DevEco 自带控制面

- **`Emulator` 二进制**（`Contents/tools/emulator/Emulator`）：`-start/-stop/-list/-create/-delete`（镜像）、
  `-instance <name>` 下的 `-screenshot/-screenshotPath/-uiLayout/-click/-slide/-fill/-power/-volume/-rotation`、
  `-hdcPort/-hvd/-logZip`——模拟器启停、截图、UI 布局、点击滑动的原子命令全在。
- **`hdc`**（`Contents/sdk/default/openharmony/toolchains/hdc`，默认不在 PATH）：装机、shell、hilog、文件传输。
- **设备侧 `uitest` / `aa`**：`screenCap -p`、`dumpLayout`、`uiInput click/inputText/...`、`aa start`，模拟器与真机通用。
- **DevEco Studio 自带 JetBrains MCP Server 插件**（`Contents/plugins/mcpserver/lib/mcpserver.jar`，
  插件 id `com.intellij.mcpServer`）：可把 IDE 的构建 / run 配置暴露给外部 agent；
  CodeGenie 插件自身也是 MCP 客户端，可挂上述任一 MCP。
- 已知模拟器坑：首次冷启动可能 >60s；只接受 debug 签名 HAP；`uitest dumpLayout` 会隐藏软键盘正下方节点；
  `hdc list targets` 状态列会把部分已连接设备误报 `Offline`，判定可用性别只信状态列。

## 来源

| 内容 | 来源 |
| --- | --- |
| deveco-cli 包与 `serve mcp` / 前置要求 / lsp 与 mcp 二选一 | https://www.npmjs.com/package/@deveco/deveco-cli （包内 README）；https://gitcode.com/openharmony-sig/deveco-cli |
| codegenie mcp 通道差异与工具清单 | https://registry.npmjs.org/@deveco-codegenie/mcp （dist-tags 与 README）；本机 stdio 握手 tools/list 实测（server `rmcp 0.12.0`，1.1.11 与 0.2.6 各跑一遍） |
| 两个模拟器工具参数 | 实测 `tools/list` 返回的 inputSchema（0.2.6） |
| npm 下载量与版本时间 | https://api.npmjs.org/downloads/point/last-month/...（@deveco/deveco-cli 15,099；@deveco-codegenie/mcp 476；agent-device 1,030,550） |
| 仓库 star / 活跃度 / 归档状态 | gh api repos/callstack/agent-device、Eilgnaw/harmonyos-mcp、open-deveco/deveco-toolbox、XixianLiang/HarmonyOS-mcp-server、AlexGladkov/claude-in-mobile、mobile-next/mobile-mcp、Deslord319/harmonyos-dev-mcp、web-infra-dev/midscene（2026-10-16） |
| Midscene MCP 退役声明 | https://midscenejs.com/mcp |
| 注册表收录情况 | punkpeye/awesome-mcp-servers 与 modelcontextprotocol/servers 的 README grep；mcp.so / smithery.ai / glama.ai 检索（2026-10-16） |
| 本机兜底控制面 | DevEco Studio 26.0.0.851：`Emulator --help`、`hdc -h`、设备侧 `uitest help` / `aa help`、`Contents/plugins/mcpserver/` 实测 |
