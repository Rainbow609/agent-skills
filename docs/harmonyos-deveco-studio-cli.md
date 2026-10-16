# DevEco Studio 命令行工具链：Command Line Tools / hvigorw / codelinter

> 适用前提：回答「CI 或纯命令行下怎么构建、怎么跑静态检查、hvigorw 有哪些参数」。
> 核实自官方知识库《获取Command Line Tools》《命令行构建工具（hvigorw）》《代码检查工具（codelinter）》
> 及 codelinter FAQ（devecocli docs，2026-10-16）。

## Command Line Tools（CLT）：命令行工具全家桶

- **CLT 集合**：`codelinter`（代码检查）、`hstack`（堆栈解析）、`hvigorw`（构建）、`ohpm`（依赖管理）
  + **SDK 已嵌入**（无需另配）。下载中心获取，解压后把 `command-line-tools/bin` 配进 PATH。
- 🌟 与 DevEco Studio **GUI 版内嵌工具的差别**：Studio 里各工具散在 `Contents/tools/` 与
  `Contents/plugins/`（如 `plugins/codelinter/`），**内嵌版不保证可直接命令行调用**
  （macOS 实测 `plugins/codelinter/run` 无执行权限）；要 CLI 走 CLT，别从 Studio 包里凑。
- 本机既有做法（manbo）：hvigorw/ohpm 直接调 `/Applications/DevEco-Studio.app/Contents/tools/...`
  的内置版即可用（hvigorw 有包装脚本形态）；codelinter 至今未装——CLT 是它的来路。

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

## 官方文档（devecocli docs 检索 ID）

- 获取 Command Line Tools：`开发指南/获取Command_Line_Tools/ide-commandline-get`
- 命令行构建工具（hvigorw）：`开发指南/命令行构建工具_hvigorw/ide-hvigor-commandline`
- 代码检查工具（codelinter）：`开发指南/代码检查工具_codelinter/ide-command-line-codelinter`
- codelinter IDE 外使用 FAQ（含 json 样例）：`FAQ/命令行工具/使用codelinter实现IDE外静态代码分析/faqs-command-line-tool-22`
- 🌟 URL 提示：文档站网页 slug 与知识库 documentId 不一致是常态（如网页
  `ide-command-line-building-app` ↔ 知识库 `ide-hvigor-commandline`），一律以 `docs search` 结果为准。
