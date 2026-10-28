# HarmonyOS 应用接续（跨端迁移 / continuation）：接入要点与坑

> 适用前提：给 HarmonyOS 应用做「应用接续」——用户在 A 设备操作，切到 B 设备的同一应用无缝继续（系统侧也称跨端迁移 / 自由流转）。
> 本文是**跨项目精炼版**，关键结论均于 2026-10-16 回一手来源复核（`devecocli docs read` 官方原文；社群条目注明印证等级）。
> 长文与逐条证据（含 `file:line`）在 manbo-reader 仓库：`docs/continuation-official.md`（官方）、`docs/continuation-community.md`（社群实战）、`docs/continuation-shelf-design.md`（项目侧落地障碍）。
> 华为工具链与文档迭代快，引用前请复核文末「官方资料索引」中的原文。

## 1. 接入最小路径

| 步 | 做什么 | 关键点 |
| --- | --- | --- |
| 1 | `module.json5` 的能力项配 `"continuable": true` | **缺省 false**；配 false 时系统按「不可接续」处理且不报错——对端不出现接续图标时先查这里；且仅当应用**获焦且可接续**才发接续广播（官方 FAQ 原文） |
| 2 | 源端实现 `onContinue(wantParam)` | 返回 `AGREE(0)` / `REJECT(1)` / `MISMATCH(2)`；待迁移数据写进 `wantParam`（容量见 §2）。官方口径：**回调内发生异常可直接返回 REJECT**；版本协商不匹配返回 MISMATCH（读系统预置 `wantParam.version`，见 §2） |
| 3 | 对端实现 `onWindowStageRestore(windowStage)` | 与源端 `onContinue` **成对**；在 `onCreate`/`onNewWant` 判 `LaunchReason.CONTINUATION(=3)` 解析数据（`onCreate`＝冷启动或多实例热启动，`onNewWant`＝单实例热启动） |
| 4 | 对端恢复成功后重新 `setMissionContinueState(ACTIVE)` | 否则只能迁过来、迁不回去（社区多源印证 + 官方模板同款） |
| 5 | 按需 `setMissionContinueState(INACTIVE)` | 页面级动态开关接续图标（如不可迁移的本地内容页） |

## 2. 🌟 硬数据与容量（数字必须记准）

- **Want 数据上限**：API 23 起 **200KB**；API 22 及之前 **100KB**（官方 API 页原文：受 IPC 通信限制）。它与「接续数据 <100KB 走 wantParam」的**选型阈值**是两个不同口径，勿混。
- **分布式数据对象（DDO）**：跨端迁移单对象 **≤150KB**（多端协同 ≤500KB）；另有 16 实例 / 3 设备 / 50ms 约束。
- 官方的数据迁移分档：<100KB 且无文件 → `want.param`；需要文件 → 先拷到 `distributedFilesDir` 转 `Asset`，经 DDO 承载（多文件用 `Assets` 数组）。
- 🌟 **系统预置 wantParam 字段**（官方概述原文）：`version`＝**对端应用版本号**——接续前做兼容协商的标准姿势：低于阈值 → `showToast` 提示用户 + 返回 MISMATCH 终止协商；`targetDevice`＝对端设备 networkId。自定义 key **勿与预置字段撞名**，否则被系统覆盖导致对端取数异常。

## 3. 🌟 生命周期与恢复（最容易翻车的一节）

- 迁移启动时**执行 `onWindowStageRestore()`，不执行 `onWindowStageCreate()`**（冷/热启动皆然，官方原文）——初始化逻辑只放在 `onWindowStageCreate` 里，接续后必然缺失。
- `restoreWindowStage()`（在 `onWindowStageRestore` 或 `onNewWant` 的 CONTINUATION 分支调用）**必须在同步方法中**（API 页约束）。
- 触发顺序：`onCreate()` / `onNewWant()` → `onWindowStageRestore()`；页面栈自动恢复**仅支持 router**（`navigation` 应用不迁移页面栈，需自行经 want 传页面信息手动加载）。
- 源端接续后是否退出，由 want 里的 `SUPPORT_CONTINUE_SOURCE_EXIT_KEY` 控制；长内容/阅读类官方建议源端退出（涉听书可仅暂停）。
- 🌟 **快速启动目标应用**：`continueType` 值加 `_ContinueQuickStart` 后缀（如 `EntryAbility_ContinueQuickStart`）＝用户发起接续后对端**立即拉起**（默认要等数据传完才拉起）。代价是对端收到**两次启动**：先 `PREPARE_CONTINUATION`（冷启动走 onCreate、热启动走 onNewWant），数据就绪后再来一次 `CONTINUATION`（onNewWant）——业务分支只认 CONTINUATION，勿在 PREPARE 阶段做恢复。
- 按需页面栈：`wantParam[SUPPORT_CONTINUE_PAGE_STACK_KEY]`（原样 key `ohos.extra.param.key.supportContinuePageStack`）设 false 可关掉系统页面栈恢复（**默认恢复**），改在 `onWindowStageRestore` 里 `loadContent` 指定落地页——navigation 应用即走此路（见上行 router 限制）。
- 🌟 **迁移启动的 `restoreWindowStage` 会销毁重建 windowStage 内容**：迁移启动（冷/热）都靠它触发页面恢复（官方：需在 `onCreate()/onNewWant()` 执行完成前调用，见上条）；「入口页整体重建（`aboutToAppear` 重跑、`@Watch` 重挂、实例字段归零）」官方未明文，为双真机实测。于是**单次 CONTINUATION 投递内即可产生两条恢复链**：热启动 `onNewWant` 写恢复数据+置触发标志（旧实例 `@Watch` 链）→ 同步 `restoreWindowStage`（销毁旧实例 → 新实例 `aboutToAppear` 读标志链）——两链并发各开一次页面（双开实测 2026-10-18，项目未配 `_ContinueQuickStart` 亦复现）。恢复链的去重/一次性守卫状态必须**进程级静态持有**（纯函数静态类即可，可 LocalUnit 直测），放页面实例字段必失效（症状签名：第二链实例字段全 0、双 open、双页面叠栈）。配置 `_ContinueQuickStart`（见上条）后系统再叠加 PREPARE_CONTINUATION+CONTINUATION 双请求，恢复入口触发次数更多，静态化更显必要。

## 4. 🌟 进度接续三场景配方（全文精读 `bpta-application-continue-progess`，2026-10-16）

通用骨架＝§1 五步，外加**恢复逻辑统一封装**：官方示例把恢复提取为 `continueRestore(want)` 公共方法，供 `onCreate` / `onNewWant` 的 `LaunchReason.CONTINUATION` 分支共用；先写 AppStorage 标志位与数据、最后 `restoreWindowStage(new LocalStorage())`，页面首帧读标志做一次性恢复。

### 4.1 长列表（List / Grid / Scroll / WaterFlow）

先试系统路，不满足再自定义：

- **系统路 `.restoreId(整数)`**：通用属性（API 8 起，元服务 API 11 起），系统按 Id 配对两端组件自动恢复滚动状态。边界（一手复核 `ts-universal-attributes-restoreid`）：
  - List(API 8) / Grid(API 9)：迁移顶部条目**索引**，对端将该条目置顶；Grid 的 **ScrollBar 位置不迁**。
  - Scroll(API 9)：迁移**绝对偏移(vp)**，两端显示规格/布局不一致时失准。
  - WaterFlow(API 11)：**索引 + 顶部 FlowItem 主轴偏移(vp)，四者中精度最高**。
  - 同应用内各迁移组件的 restoreId 必须唯一，重复＝两端配对失败。
- **自定义路**：`onDidScroll` 记 offset → `onContinue` 写 wantParam → 对端 `onDidBuild()` 一次性 `scroller.scrollTo()` 恢复。两个官方模式：
  - `onDidBuild` 在**首次 build 完成后只回调一次**（后续重渲染不回调），天然适合一次性恢复（配布尔标志）。
  - 恢复期间用 `setCurrentOffset` 标志挡住 `onDidScroll` 回写，否则恢复值被初始滚动事件冲掉。

### 4.2 媒体播放（avPlayer）

- 进度源：`avPlayer.on('timeUpdate')` 写 AppStorage；**用户拖进度条期间置 `isSliderAction` 守卫**，不回写进度。
- 迁移内容：播放列表集数 + 播放状态 + 进度，官方建议再带播放设置（画质/音频等）。
- 恢复：avPlayer 初始化完成后判接续标志 → `seek(continueTime)` → 清标志。

### 4.3 Web 组件（ArkWeb）

- 滚动位置在网页内部，ArkUI 层拿不到——用 `runJavaScript()` 读写 `document.getElementById(...).scrollTop`：源端 `onTouch(Up)` 读一次；对端在 **`onPageEnd`**（页面加载完成）再写回，URL 一并进 wantParam。

### 4.4 官方示例两个可借鉴模式 + 一个注意点

- wantParam 除业务进度外还迁移**一多断点值**（对端按断点出合适布局）与 **NavPathStack 栈顶页名**（`getAllPathName()` 末项；页面栈自动恢复仅 router，见 §3）。
- ⚠️ 官方示例恢复用真值守卫 `want.parameters.key && AppStorage.setOrCreate(...)`：值为 0（列表顶 / 0:00）时跳过恢复——因缺省态恰为 0 故无害，照抄前想清楚语义。

## 5. 🌟 坑清单（多为官方文档没有明写的实感）

- `onContinue` 抛异常 = **静默中断**：系统无提示、日志留痕 → 必须 try-catch + hilog 打点分段定位。
- 接续数据**一次性搬运**：对端恢复后要主动落定状态，失败即丢。
- 对端接续图标 **1 分钟无操作 / 锁屏 10 秒自动消失**——测试用例要把点击压进时限内。
- **模拟器不支持接续**：须双真机 + 同华为账号 + 组网 + 系统设置「多设备协同 > 接续」开启；先跑 §6 第一条命令验组网。
- 权限：**API 12 起免 `DISTRIBUTED_DATASYNC`**（大量旧文仍写「必须申请」，以官方某版本的变更为准）；API 11 及以前需声明 + 动态申请。
- 🌟 **跨端迁移配置三档**（以概述 `bpta-continue-cast` 为准）：① 同应用异 Ability（同 Bundle，双端 Ability 名不同）＝`continueType` 双端一致；② 同开发者不同 BundleName＝`continueBundleName` + `continueType` **两字段都要**、双端一致（旧口径「仅需 continueBundleName」不完整，已修订）；③ 不同开发者（跨 APPID）＝再加 AGC「接续服务」申请，且 **AppID 配置顺序＝对端匹配顺序**（发起端把对端设备形态的 AppID 排最前，如移动端发起：TV＞PC＞移动）、**务必包含自己的 AppID**，审批通过后还需重新下载 Profile 打包。
- `continueType` 规则：本应用内唯一；字母/数字/下划线、≤127 字节、不支持中文；字符串数组**仅第一个生效**（配多个是白配）。
- 🌟 **恢复数据的消费语义（谁清一次性数据、判重命中清不清键）不要按静态推演改动**：双投递 × 页面重建的真实系统时序下，code-review 推演出的「更安全」修正可能实测反而破坏接续（真机反例：判重命中清键版正确、不清键版接续异常，2026-10-18 用户实测裁决后回退）。时序类并发行为一律双真机验证后再落地。
- 官方「新闻阅读」垂类（电子书/听书）建议：发起页 = 书籍首页/阅读页，同步阅读与听书进度。

## 6. 调试配方

```bash
# 1) 组网检查：输出 RemoteDeviceInfo 列表即已成功组网的设备（双机前提先验它）
hidumper -s 4700 -a "buscenter -l remote_device_info"

# 2) 单机伪造「跨端迁移启动」（模拟器不支持接续时的替代验证）
#    -c 语义 = 调试时通过跨端迁移启动 Ability（OpenHarmony aa-tool.md 原文）
hdc shell aa start -b <bundleName> -a <abilityName> -c --ps <key> <value>
```

- `aa` **没有** `continue` 子命令；网传 `hdc emulator start` / `aa continue` 均为杜撰，勿照抄（已对官方命令表核否）。
- 失败排查：DistributedSchedule 错误码 `16300501`（系统服务异常），常见根因是软总线套接字权限。
- 🌟 **恢复链三点日志二分**（「恢复到旧位置」一次定位源端旧还是对端旧）：源端阅读器发布（publish）/ 源端 `onContinue`（migrate）/ 对端打开（open）三条日志统一自定义 tag（如 `Continuation`），两台真机各拉一次快照即可对拍页码；`hilog -x` 是快照式拉取，比长驻日志流抗断连（无线调试易掉）。两台设备在同一局域网时 `hdc -t <ip:port> shell "hilog -x" | grep Continuation`。

## 7. 存疑与已核清（引用前复核）

- ✅ 已核清（2026-10-28）：`onContinue` 的 Promise 异步版本自 **API 18** 起支持（接口参考页）；最佳实践页当前只给 async 示例、未再标 API 12。引用以接口页为准。
- 权限口径冲突：`free-flow-faqs-1` FAQ 仍按 API 11 及以前口径写「需申请 `DISTRIBUTED_DATASYNC`」。
- 源端返回 `REJECT` 后的系统后续行为，官方未说明。
- 跨 APPID 配置口径差：概述（`bpta-continue-cast`）要求 continueBundleName + continueType + AGC 接续服务申请；FAQ `free-flow-faqs-2` 同场景示例只突出 continueBundleName、**全程未提 AGC 申请步骤**——配置以概述为准，接续不生效时先补齐两字段再查申请状态。

## 8. 官方资料索引（`devecocli docs read "<路径 ID>"` 可直接复核）

| 文档 | 路径 ID |
| --- | --- |
| 应用接续概述 | `最佳实践/跨端迁移/应用接续概述/bpta-continue-cast` |
| 应用接续数据迁移 | `最佳实践/跨端迁移/应用接续数据迁移/bpta-continue-data` |
| 常见接续最佳实践（长列表/媒体/Web 进度） | `最佳实践/跨端迁移/常见接续最佳实践/bpta-application-continue-progess` |
| Want（200KB 约束原文） | `API参考/Ability_Kit_程序框架服务/ArkTS_API/通用能力的接口_推荐/ohos_app_ability_Want_Want_/js-apis-app-ability-want` |
| UIAbility（onWindowStageRestore / onContinue 成对） | `API参考/Ability_Kit_程序框架服务/ArkTS_API/Stage模型能力的接口/ohos_app_ability_UIAbility_带界面的应用组件_/js-apis-app-ability-uiability` |
| 不同 APPID 接续 FAQ | `FAQ/自由流转/不同APPID的应用如何实现应用接续/free-flow-faqs-2` |

> 一手复核时间：2026-10-16（Want 200KB 分界、`onWindowStageRestore` 语义、aa `-c` 语义均对官方原文核对；同日补 §4——restoreId 支持矩阵与 onDidBuild「仅首次 build 后回调一次」语义对官方原文核对；同日全文精读概述 `bpta-continue-cast` 697 行，§1/§2/§3/§5 增量与修订——系统预置字段、`_ContinueQuickStart` 双次拉起、配置三档——均对概述与 FAQ 原文核对）。
> 落地案例：manbo-reader（HarmonyOS 漫画/电子书阅读器）——接续改造前置调研、项目侧障碍与策略取舍见其 `docs/continuation-index.md`。
