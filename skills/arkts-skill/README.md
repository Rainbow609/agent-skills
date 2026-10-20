# arkts-skill

ArkTS 语言层**检索 + 离线验证**技能。行为契约见 [SKILL.md](./SKILL.md)。

## 来源与自管说明

拷贝自上游 [anxuesm/arkts_skill](https://gitcode.com/anxuesm/arkts_skill)（2026-10-19 采集，上游最后提交 2026-04-22），按仓库惯例"拷进 `skills/` 改名自管"——上游无 SKILL.md 根布局，本目录为适配本机改造后的自管版本，上游周更不覆盖本目录。

上游配套 benchmark：https://gitcode.com/anxuesm/arkts_benchmark

## 目录结构

```
arkts-skill/
├── SKILL.md                        # 行为契约（检索工作流 / 离线验证命令 / 引用格式）
├── ArkTS_1_1_Rules_For_Agent.md    # 116 条 ArkTS 1.1 约束核对表（上游仓库根文件）
├── docs/                           # 检索语料（release 包内容）
│   ├── ArkTS-Language-Guide/       #   语言指南 9 章 114 文件（official-guide）
│   ├── ArkTS-API-Reference/        #   @kit.ArkTS API 参考 56 文件（openharmony-arkts-api）
│   └── linter/                     #   linter 实现反推约束摘要（linter-summary，非规范）
├── references/                     # 4 个 JSON 索引（doc/snippet/cli/topic_aliases）
├── scripts/search_docs.py          # 本地检索脚本（无向量库，grouped_results 主题聚合）
├── arkts-cli/                      # .ets 检查+编译产出 .abc（~223MB 含 vendored 运行时；mac/linux 可用，--run 执行仅 Linux）
└── linter-cli/                     # 快速 .ets 语法检查（~17MB；macOS 可用，独立文件需 --module-root）
```

未收录上游的 `tools/`（snippet 校验框架）与 `reference/`——那是上游维护文档用的开发期工具，与技能运行无关；需要时回上游仓库。

## 刷新方法

上游更新后重新采集（在 agent-skills 仓库根执行）：

```bash
TMP=$(mktemp -d) && git clone --depth 1 https://gitcode.com/anxuesm/arkts_skill.git "$TMP"
S=skills/arkts-skill
cp -R "$TMP/release/arkts-skill/docs" "$TMP/release/arkts-skill/references" "$TMP/release/arkts-skill/scripts" "$S/"
cp "$TMP/ArkTS_1_1_Rules_For_Agent.md" "$S/"
rm -rf "$S/arkts-cli" "$S/linter-cli" && cp -R "$TMP/arkts-cli" "$TMP/linter-cli" "$S/"
rm -rf "$TMP" && ./install.sh
```

注意：`references/*.json` 索引由上游 `build_index.py` 从语料生成，只换 docs 不重建索引会漂移；保守做法是 docs 与 references 成对更新（都来自同一上游提交的 release 包）。

另：`arkts-cli/runtime/ark/es2abc/mac/` **不来自上游**（上游只带 linux 二进制），是 2026-10-19 从本机 DevEco Studio SDK 拷入的 arm64 版（`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/bin/ark/build-mac/bin/` 下的 `es2abc` → `mac/bin/`，`libhilog/libhmicui18n/libhmicuuc/libsec_shared` 四个 dylib → `mac/lib/`）。上游刷新覆盖 runtime 后若 mac 目录丢失，按此路径重拷；DevEco 升级后建议重拷保持版本对齐。
