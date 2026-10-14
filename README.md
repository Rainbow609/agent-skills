# agent-skills

个人用户层 AI 编码代理的**技能 / 智能体 / MCP 配置 / 全局规则**单一真源，vendor 分发模式（参照 [mattpocock/skills](https://github.com/mattpocock/skills) 的组织方式）：

- **上游技能全量 vendor**——三个 git 上游整树收进 `upstream/`，GitHub Actions 每周自动同步并**开 PR 供审阅**，合并即周更；下游不感知上游变动节奏；
- **一条命令装全部**——`npx skills add <本仓库>` 获得全部技能（含 openspec/hmos 快照），`npx skills update` 锚定本仓库更新；
- **自有内容入库**——自有技能、智能体、MCP、AGENTS.md 改这里，跑 `install.sh` 落盘。

## 仓库结构

```
agent-skills/
├── skills/                  # 自有技能（7 个，单一真源）
├── upstream/                # vendor 的 git 上游（周更 PR 自动整树同步，勿手改）
│   ├── mattpocock/skills/   #   mattpocock/skills
│   ├── DietrichGebert/ponytail/          #   ponytail 六件套
│   └── linhay/harmony-next.skills/       #   HarmonyOS 离线知识库 72M
├── snapshot/                # 无 git 源的快照（不参与周更，手动刷新）
│   ├── openspec/            #   openspec-* 8 个（openspec CLI 模板，2026-10-14 采）
│   └── huawei-hmos/         #   hmos-* 9 个（devecocli 分发，2026-10-14 采）
├── agents/zcode/            # ZCode 智能体（.md，含 color/model/thoughtLevel/tools 专属字段）
├── agents/universal/        # 跨 agent 智能体（.agent.md 精简格式，与 zcode 版语义保持一致）
├── mcp/zcode-mcp.json       # ZCode MCP servers（合并进 ~/.zcode/cli/config.json）
├── mcp/claude-mcp.json      # Claude Code MCP servers（整文件 → ~/.claude/mcp.json）
├── AGENTS.md                # 全局个人规则（落盘 ~/.zcode/AGENTS.md）
├── .upstream/upstreams.json # 同步清单：源仓库 / 分支 / 子路径 / 落点 / LICENSE 落位
├── .github/scripts/sync-upstream.sh      # 同步逻辑（本地也可直接跑）
└── .github/workflows/sync-upstream.yml   # 周一 11:00（北京）cron + 手动 dispatch，固定分支开/更新 PR
```

## 用法

```bash
# 新机初始化 / 日常重装（幂等；私有仓库按提示先 gh auth login）
git clone <本仓库> ~/git/agent-skills && ~/git/agent-skills/install.sh

# 下游也可以只装技能（智能体/MCP/AGENTS.md 仍走 install.sh）
npx skills add <owner>/agent-skills -g

# 升级技能 = 合并周更 PR 后重跑 install.sh（或直接 git pull + install.sh）
```

前置：`node`/`npx`、`jq`、`rsync`、`git`。

## 来源与许可

| 目录 | 来源 | 同步方式 |
|---|---|---|
| `upstream/mattpocock/skills` | [mattpocock/skills](https://github.com/mattpocock/skills)（MIT，见其 LICENSE） | 周更 PR |
| `upstream/DietrichGebert/ponytail` | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)（MIT） | 周更 PR |
| `upstream/linhay/harmony-next.skills` | [linhay/harmony-next.skills](https://github.com/linhay/harmony-next.skills)（仓库页标 MIT，未附 LICENSE 文件） | 周更 PR |
| `snapshot/openspec` | openspec CLI（npm）模板快照，2026-10-14 采集 | 手动（`openspec update` 后拷回） |
| `snapshot/huawei-hmos` | 华为官方 DevEco 技能库（`devecocli skills add`）快照，2026-10-14 采集 | 手动（devecocli 更新后拷回） |
| `skills/`、`agents/`、`mcp/`、`AGENTS.md` | 自有 | 直接改 |

## 注意事项

- **技能落盘为独立拷贝**：`npx skills` 对本地源实测走 copy（非 symlink），改仓库后需重跑 `install.sh` 同步到全局库。仓库位置建议仍固定在 `~/git/agent-skills`（install.sh 与文档按此路径引用）。
- **`upstream/` 勿手改**：周更 PR 会整树覆盖。要魔改上游技能请 fork 源仓库改 `upstreams.json` 指向，或拷进 `skills/` 改名自管。
- **周更 PR 复用同一分支**（`upstream-sync/weekly`）：上周未合并时本周推送自动更新该 PR，不会堆积。
- **MCP 配置无密钥**：全部指向 homebrew 二进制。若将来加带 token 的 server，用 `${ENV_VAR}` 引用，**密钥绝不入库**。
- ZCode 侧 MCP 用 jq 按 server **合并**（config.json 里其他 server 与设置不动），落盘前自动备份为 `.bak-<时间戳>`。
- `universal-product-quality` 目录名与其 SKILL.md `name: universal-product-quality-gate` 不一致，历史原因保留目录名。
- 本仓库为 **private**：技能内容多为 MIT 上游的再分发，仅供个人/受邀协作者使用，勿转公开时忽略上表许可信息。
- Claude Code 的 `~/.claude/skills` 不在 install.sh 管理范围：需要时用 `npx skills add <owner>/agent-skills -g -a claude-code`。
