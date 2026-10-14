---
name: manbo-reader
description: >
  Project-specific conventions for the manbo-reader repo (HarmonyOS NEXT comic/ebook
  reader "纸飞机"/漫播漫画). Use when working in this codebase: adding or fixing an
  online comic source (图源/漫画源 service), HTML/API parsing, mirror fallback,
  reader pages (ComicReaderPage/ComicKitReaderPage), ebook flip pages, third_party
  reader-kit, native libs (libpagecurl/libcomic_zip/libavifdec), taskpool workers,
  storage managers, the web/ activation backend, or cloud sync. Triggers: manbo-reader,
  纸飞机, 漫播漫画, 漫画源, 图源 service, 包子漫画/拷贝漫画 style source, PageFlip 阅读器.
---

# manbo-reader 项目约定

HarmonyOS NEXT 漫画 + 电子书阅读器「纸飞机」（发行名：漫播漫画）。ArkTS + ArkUI 声明式 UI，
`compileSdkVersion/targetSdkVersion = 6.1.0(23)`（HarmonyOS 6.1），hvigor 构建，含 NDK C++ 模块。
通用 ArkTS/ArkUI/HarmonyOS 知识见配套技能 `harmonyos-development`、`harmonyos-arkts`、`arkui-design`；
本技能只记录**本仓库特有的架构与约定**，与通用规则冲突时以本技能为准。

## 目录地图

```
entry/src/main/ets/
├── entryability/EntryAbility.ets   # 程序入口
├── pages/                          # 路由页面（一文件一页，如 ComicDetailPage.ets）
├── views/                          # 大区块视图（ShelfView、OnlineSourceView 等）
├── components/                     # 可复用 UI 组件（含 painting_color_selector 本地模块）
├── services/                       # 🌟 在线图源与业务服务层（见下）
├── reader/                         # Kit 漫画阅读器策略/主题/裁剪（KitReaderPolicy 等）
├── ebook/                          # 纯文本电子书阅读器（翻页、文本排版抽取）
├── viewmodel/  models/             # 状态与数据模型
├── utils/
│   ├── source/                     # 图源解析工具：ComicParserUtil、JinmanDescrambleUtil 等
│   ├── manager/                    # 单例管理器（下载/备份/崩溃日志/磁盘清理…）
│   ├── net/                        # 网络：WebDAVClient、图片缓存、NetworkMonitor
│   ├── store/                      # 持久化（BookshelfStore 等 preferences 封装）
│   ├── media/  crypto/  ui/        # 播放器、加解密、UI 工具
├── workers/                        # taskpool worker（Zip/PDF渲染/上色/超分）
└── common/                         # Constants、FeatureFlags、IComicProvider、FormatRegistry
third_party/reader-kit/             # reader-core + reader-ui（本地 file: 依赖，勿改上游）
entry/src/main/cpp/                 # NDK：libpagecurl（仿真翻页）、libcomic_zip、libavifdec
web/                                # Node 后端：HAP 分发 + Ed25519 一机一码激活发卡站
cloud/cloud.md                      # 华为端云同步（数据云同步服务）部署指导
根目录 baozimanhua/、manwa/ 等空目录   # 遗留脚手架，无代码，勿在里面新建文件
```

## 在线图源：新增一个源的标准流程

图源是本项目的核心扩展点。以 `entry/src/main/ets/services/BaoziService.ets` 为模板：

1. **新建 `services/<Name>Service.ets`**，约定如下（照抄现有源的结构）：
   - `export class XxxService` **纯静态类**，无实例化；文件头用 `// ====` 横幅 + `🌟` 中文注释说明源特性。
   - 常量：`XXX_TAG`（hilog tag）、`XXX_DOMAIN`（hilog domain，如 `0x0006`，各源唯一）、
     `MIRRORS` 镜像域名列表、`USER_AGENT`。
   - HTTP 一律 `@ohos.net.http`，日志一律 `hilog`（`import { hilog } from '@kit.PerformanceAnalysisKit'`）。
   - **镜像回退模式**：`fetchHtml()` 先尝试最近可用的 `workingMirror`，失败轮询其余镜像并缓存成功者；
     提供 `setUserMirror()/getActiveMirror()` 让用户锁定域名。多镜像源必须实现这套回退。
   - HTML 源解析工具放 `utils/source/ComicParserUtil.ets`；站点专有乱序/解密放
     `utils/source/<Site>DescrambleUtil.ets`（参考 Jinman/Roumanwu）。
2. **注册能力**：`services/SourceCapabilities.ets` 是图源能力注册表（评论区/标签搜索/作者作品/
   多标签交集，级别 `native | keyword | none`、`MULTI_TAG_NATIVE | LOCAL | NONE`）。
   新增源必须在此登记，UI 白名单从此读取，**不要在页面里加硬编码白名单**。
   - ⚠️ 该文件不得 import 任何 views/ 或 pages/ 文件（OnlineSourceView 反向 import 全部
     service，会循环依赖）。service 层统一输出 `NormalizedComic`（id/title/author/cover）。
3. **登记源清单**：`sources.json`（根目录）与 `web/public/sources.json` 各加一条
   `{ name, pkg: "com.manbo.source.<id>", lang, version, nsfw }`，两处保持同步。
4. 详情页/搜索/评论等 UI 通过 `SourceCapabilities` 与分发层自动获得能力，无需改页面判断。

## 阅读器

- 漫画阅读主链路：`pages/ComicReaderPage.ets`（自绘翻页）与 `pages/ComicKitReaderPage.ets`
  （基于 `third_party/reader-kit`，策略/主题/键位拆在 `reader/Kit*` 文件中）。
  `reader-kit` 是 vendor 进来的上游模块（见 `third_party/UPSTREAM.md`），**改 bug 优先在外层
  reader/ 适配，直接改 third_party 需同步记录**。
- 翻页实现：仿真翻页的卷曲效果由 NDK `libpagecurl.so` 提供；电子书翻页在 `ebook/`
  （CoverFlip / Curl3D / Emulation / UpDown 四种子页面模式）。
- 图像格式：AVIF 解码走 NDK `libavifdec.so`；压缩包解析走 `libcomic_zip.so` + `utils/ZipInflator.ets`。

## 并发与后台

- 重计算一律 taskpool：`workers/` 下已有 ZipWorker、PdfRenderWorker、上色/超分（Colorize/SR）引擎。
- `@Concurrent` 函数只能调用 import 进来的模块函数，不能调用同模块内定义的函数——
  纯逻辑必须拆到独立模块（如 `NaturalSort.ets` 即为此从 ComicParserUtil 拆出，且保留再导出兼容旧路径）。
- `utils/source/ComicParserUtil.ets` 的扫描/排序已在后台线程完成，主线程零计算；新增扫描逻辑遵循同样口径。

## 状态、存储与开关

- 持久化统一走 `utils/store/`（preferences 封装），书架 `BookshelfStore.ets`；
  跨模块共享上下文用 `utils/GlobalContext.ets`。
- 单例管理器放 `utils/manager/`（ComicDownloadManager、CrashLogManager、BackupManager 等），命名 `XxxManager`。
- **功能屏蔽一律用 `common/FeatureFlags.ets` 开关**（如 `EBOOK_ENABLED = false`）：
  只隐藏入口、保留实现，恢复时改回 `true` 即可，禁止删代码式下线。

## 网络与后端

- 图片/缩略图缓存：`utils/net/OnlineImageCache.ets` / `OnlineThumbnailCache.ets`，勿自造缓存。
- `web/` 是独立的 Node 销售/激活后端（HAP 分发 + Ed25519 一机一码），有自己的
  package.json 与部署文档（`web/README.md`），改动与端侧分开验证（`node server.js` 本地起）。
- 华为端云数据同步按 `cloud/cloud.md` 部署，`services/CloudSyncService.ets` 是端侧收敛点。

## 构建与调试

- SDK 基线：`build-profile.json5` 中 `6.1.0(23)`，runtimeOS `HarmonyOS`；不要使用 API 26 预览特性。
- 构建走 hvigor（DevEco Studio 或 `hvigorw assembleHap`）；真机日志用 hilog 按 `XXX_TAG` 过滤。
- 崩溃/冻屏/泄漏日志分析用已安装的华为 DFX 技能：`hmos-jscrash-analysis`、`hmos-cppcrash-analysis`、
  `hmos-appfreeze-analysis`、`hmos-memleak-analysis`；UI 测试用 `hmos-instrument-test` / `harmonyos-device-testing`。

## 代码风格速记

- 注释用中文，重要约定前加 `🌟`（本仓库通行做法，用于标记"读代码前必须知道"的约束）。
- service 为静态类 + 静态常量；页面文件与页面同名；新工具按 `utils/<子目录>/Xxx.ets` 归类。
- 每处扫描/导入口径要与书架可见性对齐（ComicParserUtil 头部注释即此类对齐说明的范例）。
