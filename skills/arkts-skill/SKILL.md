---
name: arkts-skill
description: 检索权威 ArkTS 语言层参考并对纯非 UI ArkTS 代码做离线验证。编写 / 审查 / 测试 / 调试 ArkTS 时，用本技能的本地文档检索代替模型记忆——尤其涉及 ArkTS 语法约束（arkts-no-* / arkts-sendable-*）、Sendable 与 taskpool 并发、@kit.ArkTS（collections / utils / ASON / XML / Buffer）、TS→ArkTS 迁移时；也可用 linter-cli / arkts-cli 对 .ets 做离线语法检查与编译运行（后续改善离线验证调用的基础）。边界：只覆盖纯非 UI 语言层，ArkUI 组件与状态管理归 arkui-design，写码规范与审查归 harmonyos-arkts。ArkTS 语言层查证、.ets 离线验证均应触发。
---

# ArkTS 检索与离线验证技能

本技能提供两层能力：**grounded 检索**（本地结构化文档索引，引用可解释）与**离线验证**（对纯非 UI `.ets` 做语法检查、编译、运行）。目标是让 ArkTS 回答基于仓库内已验证资料，而非模型记忆。

技能根目录（下称 `$SKILL_DIR`）：`~/.agents/skills/arkts-skill`

## 布局与来源分级

| 路径 | 内容 | 证据地位 |
|------|------|----------|
| `$SKILL_DIR/docs/ArkTS-Language-Guide/` | ArkTS 语言指南，9 章 114 文件（语法/公共库/并发/运行时/跨语言/工具链/迁移） | **主规范来源**（official-guide） |
| `$SKILL_DIR/docs/ArkTS-API-Reference/` | `@kit.ArkTS` API 参考 56 文件（collections / utils / ASON / SendableLruCache 等） | **API 细节主来源**（openharmony-arkts-api） |
| `$SKILL_DIR/docs/linter/ArkTS_Syntax_Knowledge_From_Linter.md` | 从 ArkTSLinter_1_1 实现反推的约束摘要（含规则强度：error / warning / 条件允许 / migratable） | 实现侧证据（linter-summary），**不等同官方规范** |
| `$SKILL_DIR/ArkTS_1_1_Rules_For_Agent.md` | 116 条 ArkTS 1.1 约束一行一条清单 | 快速核对表 |

规则强度以 linter 摘要的四分级为准——不是所有"不支持"都是硬错误，warning 级和 migratable 级在非严格模式下可放行。

## 检索工作流

```bash
python3 "$HOME/.agents/skills/arkts-skill/scripts/search_docs.py" --query "<用户问题>"
```

1. 优先读 `grouped_results`（主题聚合，更接近最终回答结构）；`results` 是兼容保留的扁平候选。
2. 需要原文时打开引用的文档文件。
3. 每条引用必须可追溯：文件路径 + 章节路径 + 来源类型 + 一句匹配理由 + 基于文档的结论。
4. 首轮结果弱时，扩展到相邻章节或类别再答；仍无结果就明说，并列出已尝试的查询词。
5. linter 摘要来的结论要注明"来自 linter 实现，非官方规范文本"；API 参考里的示例不作为纯非 UI 验证证据。

## 离线验证

按需选用，不要默认执行；用户要求"验证 / 跑一下 / 检查语法"时使用。平台差异（2026-10 实测）：

**语法/语义检查——linter-cli，macOS / Linux 均可用（首选）**：

```bash
node "$HOME/.agents/skills/arkts-skill/linter-cli/bin/linter-cli.js" --input /abs/path/example.ets --module-root /abs/some/dir
```

- 独立文件（不在 `src/main/ets` 工程布局内）**必须显式传 `--module-root`**，否则报 "Cannot infer module root"；值指任意存在的目录即可。
- 退出码：0 = Lint OK，1 = 存在违规。违规按 arkts-no-* / arkts-sendable-* 规则号输出，与官方 linter 语义一致。

**检查 + 编译——arkts-cli，macOS / Linux 可用**：

```bash
node "$HOME/.agents/skills/arkts-skill/arkts-cli/bin/arkts-cli.js" --input /abs/path/example.ets --out-dir /tmp/arkts-out
```

- 完整管线：ArkTS 语法检查（报 arkts-no-* / arkts-sendable-* 规则，退出码 0 = 通过、1 = 有违规）→ 转换 → es2abc 编译产出 `.abc`。
- 入口文件有本地相对导入时加 `--input-dir <源码根目录>`（多文件一起进临时工作区）。
- macOS 的 es2abc 为 arm64，取自本机 DevEco Studio SDK（`ets-loader/bin/ark/build-mac`），已按 `runtime/ark/es2abc/mac/{bin,lib}` 布局接入；若报 "Missing packaged es2abc binary"，从对应 DevEco 路径重拷即可。

**运行 `.abc`——`--run` 仅 Linux**：mac 缺 `runtime/ark/jsvm/mac/bin/ark_js_vm`（DevEco 不带独立 Ark VM），会报 "Missing packaged ark_js_vm binary"；检查与编译不受影响。需要真实执行验证时走 Linux/docker。

约束：两者只支持**纯非 UI** ArkTS（类、函数、Sendable、taskpool、collections 等）。含 ArkUI 组件、状态管理装饰器的 `.ets` 无法离线验证，不要尝试。

## 结果输出格式

除非用户另有要求，检索结论按此结构给出：

```markdown
- 主题: <主题标签>
- 引用: <文件路径#章节>
- 来源: <official-guide | openharmony-arkts-api | linter-summary>
- 匹配理由: <一句>
- 结论: <基于文档的一两句>
- 后续: <可选的验证命令>
```
