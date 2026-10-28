# 鸿蒙知识检索链路：四轨 + 官方库与 Context7

> 适用前提：任何鸿蒙项目排查「这个知识去哪查」时用；本文件是检索链路的跨项目真源，
> 项目 AGENTS.md 只留指针。核实与实测：2026-10-16（含 Context7 实查验证）。

## 检索链路（顺序即优先级）

1. **EverOS**（`search_memory` / `recall_agent_experience`）：跨会话记忆，起手先搜（Memorix 已弃用，仅存档）。
2. **项目 `docs/`**：项目真源，结论带 `file:line`，与代码冲突以代码为准。
3. **agent-skills `docs/`**（本仓库）：跨项目通用真源，索引见其 `README.md`。
4. **官方资料**：以下两个通道互补，不是二选一——
   - **`devecocli docs search "<关键词>"`**：官方知识库**全文**（开发指南 / API 参考 / FAQ / 最佳实践 /
     版本说明 / 变更预告六目录）。API/组件类问题的首选，本地离线可用。
   - **Context7**（`resolve-library-id` → `query-docs`）：官方文档站与 samples 的**镜像索引**，
     强在**代码级片段**（带官方源 URL）与样例工程；devecocli 未覆盖或需要可运行示例时用它。

全部无果才自行调研（WebSearch 等）。

## 🌟 为什么文档站必须绕过网页直抓

`developer.huawei.com` 的文档页、samples 页、产品落地页（arkts/、arkui/、deveco-testing/ 等）
都是 SPA：web 抓取工具只能拿到标题/描述，**正文抓不到**。可用通路只有两条：
`devecocli docs`（官方知识库镜像）与 Context7（官方文档站镜像）。别再徒劳去 curl 网页。

## devecocli docs 用法与坑

- `docs search "<关键词>" [--catalog <harmonyos-guides | harmonyos-references | best-practices | harmonyos-faqs | harmonyos-releases | harmonyos-roadmap | all>] [--format json] [--limit N]`
- 🌟 **`docs read` 必须用完整 `documentId`**：先用 `--format json` 拿 `documentId` 字段
  （格式如 `开发指南/ArkTS_方舟编程语言/ArkTS简介/arkts-overview`），网页 URL 的 slug
  与之不一致是常态（如网页 `doccenter-testing/hypium-python-guidelines` ↔ 知识库
  `开发指南/单元测试和UI测试/应用UI测试_基于Python/hypium-python-guidelines`）。
- 输出末尾会混入版本升级提示行，脚本解析 JSON 时按首个 `[` 到最后一个 `]` 截取。

## Context7 鸿蒙库 ID（2026-10-16 实查）

| 库 ID | 内容 | 备注 |
| --- | --- | --- |
| `/websites/developer_huawei_consumer_cn_doc_harmonyos-guides` | 官方开发指南全文索引（code snippets 6.4 万+） | API 用法/FAQ 片段首选 |
| `/websites/developer_huawei_consumer_cn_doc_harmonyos-references` | 官方 API 参考全文索引（7.4 万+） | 接口签名/枚举查证 |
| `/linganmin/harmonyos_samples` | 官方 samples 镜像（High reputation） | 样例工程代码 |
| `/harmonyos-dev/harmonyos-codelabs` | 官方 Codelabs 集合 | 教程式样例 |
| `/harmony-55/harmonyos_samples` | 另一 samples 镜像（Low reputation） | 兜底，注意甄别 |

**实测验证（2026-10-16）**：以「TaskPool 与 Worker 区别/Sendable」查询 guides 索引，
返回带官方源 URL 的代码片段（concurrency-faq / normal-object / sendable-freeze / arkts-overview），
内容与 devecocli docs 得到的口径一致——两通道互为校验，可放心用于工作流。

## 通道选择速查

| 需求 | 首选 |
| --- | --- |
| 接口签名/枚举/版本要求 | devecocli docs（references 目录）或 Context7 references 索引 |
| 概念/指南/最佳实践全文 | devecocli docs（guides/最佳实践目录） |
| 可运行代码示例 | Context7 samples/codelabs；devecocli 案例文档内链 |
| 官方 FAQ | devecocli docs（FAQ 目录，检索命中率高） |
| 本项目历史决策/坑 | EverOS → 项目 docs/ |

## 相关

- 项目内链示例（manbo）：AGENTS.md「知识检索与同步」= 本链路的项目化收窄。
- 各知识领域的落点地图：见本仓库 `docs/` 下 `harmonyos-*.md` 系列（测试/CLI/一多/框架等）。
