# openspec-* 快照（8 个技能）

来源：openspec CLI（npm 包 `@fission-ai/openspec`）安装到 `~/.agents/skills` 的副本。
采集日期 2026-10-14；2026-10-16 随 CLI 1.14.2 刷新（8 个 SKILL.md 共 37 行变更：verify 增补 REMOVED 需求的 baseline 追溯规程、update 支持部分填充的 glob artifact、explore 泛化非默认 schema、交付提示语改 `/opsx:` 风格）。
openspec 官方没有可直接 git 同步的技能仓库，故为快照，不参与周更工作流。

刷新方式：`npm i -g @fission-ai/openspec@latest` 升级 CLI 后，在 HOME 跑 `openspec update`（会把技能写入 `~/.agents/skills/` 与各已识别工具目录），确认 `~/.agents/skills/openspec-*` 更新后，把 8 个目录拷回本目录并提交。
注意 `~/.agents/skills/.openspec-target` 是该 CLI 的安装标记文件，不属于技能，勿拷入。
若 `openspec update` 对某工具报 `Cannot verify dangling symbolic link`（该工具技能目录里存在死链，常见于第三方同步器实验残留），先清理该死链再重跑即可。
