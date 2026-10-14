# commands —— 斜杠命令存档

本目录收录各 coding agent 的斜杠命令（slash commands），补上技能/智能体/MCP/hooks 之外的第五类用户层资产。

## 内容

当前唯一命令集为 **OpenSpec 的 `opsx:*`**（`openspec` CLI 按工具各自格式生成，共 8 条：apply / archive / bulk-archive / explore / propose / sync / update / verify）：

| 目录 | 运行时落点 | 格式差异 |
|---|---|---|
| `zcode/opsx/` | `~/.zcode/commands/opsx/` | 标准 frontmatter（name/description/category/tags） |
| `claude/opsx/` | `~/.claude/commands/opsx/` | 同上 + `allowed-tools: Bash(openspec:*)`（Claude 专属字段） |
| `iflow/opsx-*.md` | `~/.iflow/commands/` | 扁平命名格式（`name: "/opsx-apply"`、`id` 字段） |

三份是同一命令集的不同工具格式，**勿互相覆盖**。

## 部署与刷新

- **部署**：`install.sh` 第 ⑧ 步把三份 cp 到各自运行时目录（仅覆盖同名文件、不删除目录内其他命令）；目标工具目录不存在则跳过。
- **刷新**（openspec CLI 升版后）：本机跑 `openspec update`，确认三处命令目录更新后：
  ```bash
  cp -R ~/.zcode/commands/opsx   commands/zcode/
  cp -R ~/.claude/commands/opsx  commands/claude/
  cp ~/.iflow/commands/opsx-*.md commands/iflow/
  ```
  然后提交。与 `snapshot/openspec/`（技能）同源同刷新节奏。
