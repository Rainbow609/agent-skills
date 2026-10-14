# hooks —— Agent 钩子库存档

本目录收录本机各 coding agent 的钩子（hook）配置与脚本，补上技能/智能体/MCP 之外的第四类用户层资产。

## 内容与策略

| 文件 | 来源 | 部署方式 |
|---|---|---|
| `claude-settings.json` | `~/.claude/settings.json` 的脱敏模板：hooks 接线（Orca，已改 `$HOME` 相对路径）+ model/permissions/statusLine/env（**不含任何 token**） | install.sh 用 jq **合并**进本机 `~/.claude/settings.json`——本机 secrets 与本地独有键保留，模板键优先；新机首次直接落模板（需自行补 API 凭据） |
| `codex-hooks.json` | `~/.codex/hooks.json` 快照（cmux 接线，cmd 已是 `command -v` 便携格式，无绝对路径） | **仅存档**，不反向同步——该文件由 cmux 安装器管理，Codex 的 `[hooks.state]` trusted_hash 与条目内容绑定，覆盖会造成信任失效 |
| `orca/*.sh` | `~/.orca/agent-hooks/` 11 个脚本（Orca 应用安装，向本机 Orca 端点上报 agent 事件） | **仅存档**，不反向同步——Orca 升级会自行更新；脚本本身自带 `[ -x ]`/env 守卫，未装 Orca 的机器上静默空转 |

## 🌟 密钥纪律

- 本目录**永不入库任何 token**（`ANTHROPIC_AUTH_TOKEN` 等一律剔除）；合并部署时本机凭据来自既有 `~/.claude/settings.json` 被原样保留。
- 刷新快照：Orca 更新后 `cp ~/.orca/agent-hooks/*.sh hooks/orca/`；cmux 更新后 `cp ~/.codex/hooks.json hooks/codex-hooks.json`；Claude 配置改动后按上表重新生成脱敏模板（生成命令见 git 历史）。
