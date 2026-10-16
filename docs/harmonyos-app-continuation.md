# HarmonyOS 应用接续（跨端迁移 / continuation）：接入要点与坑

> 适用前提：给 HarmonyOS 应用做「应用接续」——用户在 A 设备操作，切到 B 设备的同一应用无缝继续（系统侧也称跨端迁移 / 自由流转）。
> 本文是**跨项目精炼版**，关键结论均于 2026-10-16 回一手来源复核（`devecocli docs read` 官方原文；社群条目注明印证等级）。
> 长文与逐条证据（含 `file:line`）在 manbo-reader 仓库：`docs/continuation-official.md`（官方）、`docs/continuation-community.md`（社群实战）、`docs/continuation-shelf-design.md`（项目侧落地障碍）。
> 华为工具链与文档迭代快，引用前请复核文末「官方资料索引」中的原文。

## 1. 接入最小路径

| 步 | 做什么 | 关键点 |
| --- | --- | --- |
| 1 | `module.json5` 的能力项配 `"continuable": true` | **缺省 false**；配 false 时系统按「不可接续」处理且不报错——对端不出现接续图标时先查这里 |
| 2 | 源端实现 `onContinue(wantParam)` | 返回 `AGREE(0)` / `REJECT(1)` / `MISMATCH(2)`；待迁移数据写进 `wantParam`（容量见 §2） |
| 3 | 对端实现 `onWindowStageRestore(windowStage)` | 与源端 `onContinue` **成对**；在 `onCreate`/`onNewWant` 判 `LaunchReason.CONTINUATION(=3)` 解析数据 |
| 4 | 对端恢复成功后重新 `setMissionContinueState(ACTIVE)` | 否则只能迁过来、迁不回去（社区多源印证 + 官方模板同款） |
| 5 | 按需 `setMissionContinueState(INACTIVE)` | 页面级动态开关接续图标（如不可迁移的本地内容页） |

## 2. 🌟 硬数据与容量（数字必须记准）

- **Want 数据上限**：API 23 起 **200KB**；API 22 及之前 **100KB**（官方 API 页原文：受 IPC 通信限制）。它与「接续数据 <100KB 走 wantParam」的**选型阈值**是两个不同口径，勿混。
- **分布式数据对象（DDO）**：跨端迁移单对象 **≤150KB**（多端协同 ≤500KB）；另有 16 实例 / 3 设备 / 50ms 约束。
- 官方的数据迁移分档：<100KB 且无文件 → `want.param`；需要文件 → 先拷到 `distributedFilesDir` 转 `Asset`，经 DDO 承载（多文件用 `Assets` 数组）。

## 3. 🌟 生命周期与恢复（最容易翻车的一节）

- 迁移启动时**执行 `onWindowStageRestore()`，不执行 `onWindowStageCreate()`**（冷/热启动皆然，官方原文）——初始化逻辑只放在 `onWindowStageCreate` 里，接续后必然缺失。
- `restoreWindowStage()`（在 `onWindowStageRestore` 或 `onNewWant` 的 CONTINUATION 分支调用）**必须在同步方法中**（API 页约束）。
- 触发顺序：`onCreate()` / `onNewWant()` → `onWindowStageRestore()`；页面栈自动恢复**仅支持 router**（`navigation` 应用不迁移页面栈，需自行经 want 传页面信息手动加载）。
- 源端接续后是否退出，由 want 里的 `SUPPORT_CONTINUE_SOURCE_EXIT_KEY` 控制；长内容/阅读类官方建议源端退出（涉听书可仅暂停）。

## 4. 🌟 坑清单（多为官方文档没有明写的实感）

- `onContinue` 抛异常 = **静默中断**：系统无提示、日志留痕 → 必须 try-catch + hilog 打点分段定位。
- 接续数据**一次性搬运**：对端恢复后要主动落定状态，失败即丢。
- 对端接续图标 **1 分钟无操作 / 锁屏 10 秒自动消失**——测试用例要把点击压进时限内。
- **模拟器不支持接续**：须双真机 + 同华为账号 + 组网 + 系统设置「多设备协同 > 接续」开启；先跑 §5 第一条命令验组网。
- 权限：**API 12 起免 `DISTRIBUTED_DATASYNC`**（大量旧文仍写「必须申请」，以官方某版本的变更为准）；API 11 及以前需声明 + 动态申请。
- 跨 APPID（手机 / PC 拆分不同包）接续需 `continueBundleName` + 在 AGC 申请「接续服务」；同一开发者不同 BundleName 仅需 `continueBundleName`。
- 官方「新闻阅读」垂类（电子书/听书）建议：发起页 = 书籍首页/阅读页，同步阅读与听书进度。

## 5. 调试配方

```bash
# 1) 组网检查：输出 RemoteDeviceInfo 列表即已成功组网的设备（双机前提先验它）
hidumper -s 4700 -a "buscenter -l remote_device_info"

# 2) 单机伪造「跨端迁移启动」（模拟器不支持接续时的替代验证）
#    -c 语义 = 调试时通过跨端迁移启动 Ability（OpenHarmony aa-tool.md 原文）
hdc shell aa start -b <bundleName> -a <abilityName> -c --ps <key> <value>
```

- `aa` **没有** `continue` 子命令；网传 `hdc emulator start` / `aa continue` 均为杜撰，勿照抄（已对官方命令表核否）。
- 失败排查：DistributedSchedule 错误码 `16300501`（系统服务异常），常见根因是软总线套接字权限。

## 6. 存疑（引用前复核，勿当定论）

- `onContinue` 的 Promise 异步版本起点：接口参考页写 API 18、最佳实践页写 API 12——**官方自相矛盾**（2026-10-16 查）。
- 权限口径冲突：`free-flow-faqs-1` FAQ 仍按 API 11 及以前口径写「需申请 `DISTRIBUTED_DATASYNC`」。
- 源端返回 `REJECT` 后的系统后续行为，官方未说明。

## 7. 官方资料索引（`devecocli docs read "<路径 ID>"` 可直接复核）

| 文档 | 路径 ID |
| --- | --- |
| 应用接续概述 | `最佳实践/跨端迁移/应用接续概述/bpta-continue-cast` |
| 应用接续数据迁移 | `最佳实践/跨端迁移/应用接续数据迁移/bpta-continue-data` |
| 常见接续最佳实践（长列表/媒体/Web 进度） | `最佳实践/跨端迁移/常见接续最佳实践/bpta-application-continue-progess` |
| Want（200KB 约束原文） | `API参考/Ability_Kit_程序框架服务/ArkTS_API/通用能力的接口_推荐/ohos_app_ability_Want_Want_/js-apis-app-ability-want` |
| UIAbility（onWindowStageRestore / onContinue 成对） | `API参考/Ability_Kit_程序框架服务/ArkTS_API/Stage模型能力的接口/ohos_app_ability_UIAbility_带界面的应用组件_/js-apis-app-ability-uiability` |
| 不同 APPID 接续 FAQ | `FAQ/自由流转/不同APPID的应用如何实现应用接续/free-flow-faqs-2` |

> 一手复核时间：2026-10-16（Want 200KB 分界、`onWindowStageRestore` 语义、aa `-c` 语义均对官方原文核对）。
> 落地案例：manbo-reader（HarmonyOS 漫画/电子书阅读器）——接续改造前置调研、项目侧障碍与策略取舍见其 `docs/continuation-index.md`。
