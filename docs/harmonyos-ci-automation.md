# 鸿蒙 CI 自动化：构建、测试、报告与失败策略

> 适用前提：搭 GitLab/Jenkins 等流水线，或把本地命令搬进 CI 时查「官方命令是什么、社区方案哪里不可照抄」。
> 社区来源：华为云社区 Jack20《HarmonyOS开发：自动化测试》《HarmonyOS开发：开发者工具链——CLI工具与自动化脚本》
> （bbs.huaweicloud.com/blogs/480147、/480658，2026-06-24）。
> 所有命令已用官方文档与 devecocli 离线库复核（2026-10-28）；与博客冲突处见文末纠错表。
> 构建命令面见 `harmonyos-deveco-studio-cli.md`；hdc/hilog 见 `harmonyos-cli-debugging.md`；
> 测试分层见 `harmonyos-unit-testing.md` 与 `harmonyos-app-testing-fullchain.md`。

## 流水线骨架

```text
build → unit test → UI/instrument test → report
                 ↘ 失败策略：阻断 / 记录告警 / 重试
```

三层测试的官方口径：

| 层级 | 框架 | 执行 | CI 形态 |
| --- | --- | --- | --- |
| 单元测试 | `@ohos/hypium`（arkxtest JsUnit） | `hvigorw test`（Local）/ `onDeviceTest`（设备） | Local 可直接跑；Instrument 需设备 |
| UI 测试 | ArkTS `@ohos.UiTest` 或 Python Hypium | `aa test` / xdevice | 需真机/模拟器 |
| 兼容性/云测 | DevEco Testing | 客户端或 Console | 需账号与设备资源 |

## 官方命令基线（可直接进 CI）

```bash
# 构建（assembleHap 必须 --mode module；--mode project 只有 assembleApp）
hvigorw clean
hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon

# 静态检查门禁（有 error 即非零退出）
codelinter -c code-linter.json5 -i -f json -o codelinter.json -e error

# Local Test（无设备；官方明示不支持 Linux，CI 用 macOS runner）
hvigorw test -p module=entry -p coverage=true --no-daemon

# Instrument Test（需设备）
hvigorw onDeviceTest -p module=entry -p coverage=true --no-daemon

# 设备侧等价执行（需先安装 app hap 与 ohosTest hap）
hdc install -r entry-default-signed.hap
hdc install -r entry-ohosTest-signed.hap
hdc shell aa test -b <bundle> -m <module> -s unittest OpenHarmonyTestRunner \
  -s class <Suite#case> -s timeout 15000

# 拉回产物
hdc file recv <设备路径> <本地路径>
```

- `hvigorw` 其余命令须在工程根目录执行；`--no-daemon` 是命令行模式推荐项。
- 内存不足用 `--max-old-space-size=N`（hvigor 是 Node 工具，不是 JVM）。
- 任务清单用 `hvigorw tasks`，依赖关系用 `hvigorw taskTree`，缓存清理用 `clean` / `prune`。
- `-p coverage=true` 控制测试是否出覆盖率；测试框架插桩编译用 `-p ohos-test-coverage=true`；已有打点数据可用 `collectCoverage` 生成报表。

## 报告与产物（官方路径）

| 测试 | 报告 | 结果文件 |
| --- | --- | --- |
| Local Test | `<module>/.test/default/outputs/test/reports/index.html` + `coverageReport.json` | `<module>/.test/default/intermediates/test/coverage_data/test_result.txt` |
| Instrument Test | `<module>/.test/default/outputs/ohosTest/reports/index.html` + `coverageReport.json`；C++ 覆盖率在 `.../outputs/ohosTest/cpp_reports/index.html` | `<module>/.test/default/intermediates/ohosTest/coverage_data/test_result.txt` |
| ASan | — | `<module>/.test/default/intermediates/ohosTest/coverage_data` |
| 静态检查 | `codelinter.json` | — |

🌟 **JUnit 不是官方产物**：官方 Local/Instrument 文档给的是 html + json + `test_result.txt`，没有 JUnit XML。社区博客里的 JUnit 解析脚本建立在一个未证实的前提上；CI 平台若要 JUnit，需要自己从 `test_result.txt` 转换或接入自定义 reporter。覆盖率报告是**模块级**的，官方暂不支持自动生成项目级报告（可用 hvigorw 多模块结果手工汇总）。

## 失败策略

社区方案里值得保留的工程做法（非官方 API）：

- **稳定/不稳定用例分开**：稳定用例失败 → 阻断；标记为不稳定的用例失败 → 重试 ≤2 次，仍失败只告警不阻断，避免网络抖动拖垮整条流水线。
- **超时双层保护**：命令级 `timeout 600 hvigorw test ...`，Job 级 `timeout: 15m`（GitLab）或 `timeout(time: 10, unit: 'MINUTES')`（Jenkins）。
- **`|| true` 只用于保产物**：`hvigorw test ... || true` 能让后续步骤收集报告，但必须再用解析结果决定门禁，否则测试失败会被吞掉。
- **报告可视化**：把通过率、失败用例名与消息汇总成 HTML/CI 报告；数字比日志更容易定位。

## 覆盖率

- Local Test：`hvigorw test -p module=entry -p coverage=true`（缺省就是 true）。
- Instrument Test：`hvigorw onDeviceTest -p module=entry -p coverage=true`。
- 插桩编译：`hvigorw ... -p ohos-test-coverage=true`。
- 报表：`index.html`（人看）+ `coverageReport.json`（机器读）。
- 覆盖率是模块级；项目级需自行汇总，不要指望单条命令出全项目报告。

## 设备供给

| 方案 | 做法 | 注意 |
| --- | --- | --- |
| 局域网设备池 | `hdc tconn <ip>:<port>` → `hdc list targets` 验证 | hdc 服务默认 **8710**；端口以设备无线调试显示为准，`5555` 是 adb 习惯 |
| 云测 | 官方 DevEco Testing Console（`DevEcoTestingConsole.sh/.bat`） | 需客户端已登录并开启登录保活；详见 `harmonyos-deveco-testing-platform.md` |
| 设备常亮 | `hdc shell power-shell wakeup`；测试期覆盖自动熄屏 `hdc shell power-shell timeout -o 600000` | `setmode 602` 是**性能模式**，不是常亮；UI 用例黑屏会报 `Tests failed` |
| 连接异常 | `hdc kill -r` 重启 hdc 服务 | 端口占用/驱动问题先查 8710 |

## 社区方案纠错表（务必按官方列改）

| 博客写法 | 官方/复核结果 | 说明 |
| --- | --- | --- |
| `hvigorw test@ut` / `test@uitest` / `test@unittest` | 官方文档用 `hvigorw test`（Local）/ `hvigorw onDeviceTest`（设备） | 官方任务表未见 `@ut`；博客多个示例自相矛盾 |
| `hvigorw --module entry assembleHap` | `hvigorw --mode module -p module=entry@default assembleHap` | `--mode project` 下报 `00306054 Task assembleHap not found` |
| `hvigorw --list` | `hvigorw tasks` | 官方任务清单命令 |
| `hvigorw --dependencies` | `hvigorw taskTree` | 官方依赖关系命令 |
| `hvigorw --no-build-cache` | `--no-incremental`；清缓存用 `clean` / `prune` | hvigor 的缓存控制是增量构建，不是 build-cache 开关 |
| `hvigor-config.json5` 里 `execution.jvmOptions: "-Xmx4g"` | 配置项是 `nodeOptions.maxOldSpaceSize`（V8，默认 8192MB）；JVM 堆用命令行 `hvigorw --Xmx <MB>` | `execution` 无 `jvmOptions` 字段；别把 V8 与 JVM 堆混为一谈 |
| `hvigorw --module entry lint` | `codelinter -e error ...` | hvigorw 没有官方 lint 任务；codelinter 才是 CI 门禁件 |
| `hdc tconn 192.168.1.100:5555` | `hdc tconn <ip>:<port>`；hdc **PC 侧 server** 默认 **8710** | tconn 端口以设备无线调试显示为准；5555 是 adb 默认端口，照抄常连不上 |
| `hdc hilog -t MyApp` / `-l E` | `hdc shell hilog -T MyApp -L E -P <pid>` | 小写 `-t` 是日志类型，`-l` 是落盘文件大小；tag/level/pid 用大写 |
| `hdc install -r -g your-app.hap` 可绕过签名 | `-g` 仅 API 24+、仅 debug 包，作用是授予/手动设置权限 | **不能绕过签名**；release 包必须正式签名 |
| `hapsigner sign-app ...` | 官方写法是 `java -jar hap-sign-tool.jar sign-app ...` | 未检索到独立的 `hapsigner` 可执行文件；博客漏了 jar 与 Java 包装 |
| `entry/build/default/outputs/default/test/` | `<module>/.test/default/outputs/test/reports` | Local Test 的官方报告路径；博客路径未在官方文档确认 |
| `hdc file recv /data/local/tmp/test-results/` | 官方 Instrument 结果在模块 `.test/.../coverage_data/` | `/data/local/tmp/test-results/` 未在官方文档确认 |
| `curl https://devetesting.huawei.com/api/v1/test` | 官方为 `DevEcoTestingConsole.sh/.bat` | 博客的 REST 端点未在官方文档找到，勿作为集成依据 |
| Hypium 2.0 / `hdc perf` / ohpm workspaces / 构建缓存云同步 | 官方文档未检索到 | 视为**未证实**，不要写进排期或架构假设 |

## 最小 CI 清单

- [ ] 构建：`assembleHap --mode module`，产物与签名配置齐全
- [ ] 静态门禁：`codelinter -e error`
- [ ] Local Test：macOS runner，`hvigorw test -p module=...`
- [ ] Instrument Test：设备池或云测，安装 app + ohosTest 两个 hap
- [ ] 报告：上传 `.test/` 与 `codelinter.json`，失败用例名+消息可见
- [ ] 失败策略：稳定阻断、flaky 重试、命令与 Job 双超时
- [ ] 设备：常亮、连接自检、断连重启 `hdc kill -r`
- [ ] 不照抄未证实命令；以 `hvigorw tasks` / `--help` 的实际任务名为准

## 来源

- 社区（需按上表纠错）：[自动化测试](https://bbs.huaweicloud.com/blogs/480147)、[CLI 工具与自动化脚本](https://bbs.huaweicloud.com/blogs/480658)
- 官方：[命令行构建工具（hvigorw）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-commandline)、[Local Test](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-local-test)、[Instrument Test](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-instrument-test)、[hdc](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hdc)、[hilog](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hilog)
