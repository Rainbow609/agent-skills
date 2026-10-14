# agent-skills

个人用户层 AI 编码代理的**技能 / 智能体 / MCP 配置**单一真源，参照 [mattpocock/skills](https://github.com/mattpocock/skills) 的组织方式：

- **上游技能不 vendor**——由 [`npx skills`](https://github.com/vercel-labs/skills)（Vercel 的开放技能 CLI）从源仓库安装、`npx skills update -g` 升级；
- **自有技能与智能体入库**——改这里，跑 `install.sh` 落盘；
- **运行时单一库**——全局技能统一落 `~/.agents/skills`，`~/.zcode/skills` 是指向它的符号链接（ZCode 两侧都读，从此不再双份漂移）。

## 仓库结构

```
agent-skills/
├── skills/                  # 自有技能（7 个，单一真源）
├── agents/zcode/            # ZCode 智能体定义（.md，含 color/model/thoughtLevel/tools 专属字段）
├── agents/universal/        # 跨 agent 智能体定义（.agent.md 精简格式，两者语义须保持一致）
├── mcp/zcode-mcp.json       # ZCode MCP servers（合并进 ~/.zcode/cli/config.json）
├── mcp/claude-mcp.json      # Claude Code MCP servers（整文件 → ~/.claude/mcp.json）
└── install.sh               # 幂等装配脚本
```

## 用法

```bash
# 新机初始化 / 日常重装（幂等）
git clone <本仓库> ~/git/agent-skills && ~/git/agent-skills/install.sh

# 升级上游技能
npx skills update -g

# 改了自有技能 / 智能体 / MCP 后
~/git/agent-skills/install.sh
```

前置：`node`/`npx`、`jq`、`rsync`；`openspec`、`devecocli` 可选（缺失时对应技能跳过并提示）。

## 技能来源清单

| 来源 | 技能 | 管理方式 |
|---|---|---|
| [mattpocock/skills](https://github.com/mattpocock/skills) | ask-matt、code-review、tdd、to-spec、grilling 等 ~40 个 | `npx skills add mattpocock/skills -g` |
| [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | ponytail 六件套（ponytail/-review/-audit/-debt/-gain/-help） | `npx skills add DietrichGebert/ponytail -g` |
| [linhay/harmony-next.skills](https://github.com/linhay/harmony-next.skills) | harmony-next（HarmonyOS 离线知识库，72M） | `npx skills add linhay/harmony-next.skills --skill harmony-next -g` |
| OpenSpec 官方 | openspec-* 8 个 | openspec CLI 自管（`openspec update`，`~/.agents/skills/.openspec-target` 是其标记） |
| 华为官方（DevEco） | hmos-* 9 个（DFX 崩溃分析、ArkUI 场景等） | `devecocli skills add` + 手动 cp，无 npx skills 源 |
| **自有（本仓库）** | arkui-design、harmonyos-arkts、harmonyos-development、git-commit、git-pr-description、harmonyos-device-testing、universal-product-quality | 入库，install.sh rsync 落盘 |

## 注意事项

- **npx skills 无版本锁定**：`update` 即 latest；上游技能内容以源仓库为准，本仓库不存副本。
- 自有技能若与上游技能同名，`rsync --delete` 会以本仓库版本接管该名称（当前无同名冲突）。
- **MCP 配置无密钥**：全部指向 homebrew 二进制。若将来加带 token 的 server，用 `${ENV_VAR}` 引用，**密钥绝不入库**。
- ZCode 侧 MCP 用 jq 按 server **合并**（config.json 里其他 server 与设置不动），落盘前自动备份为 `.bak-<时间戳>`。
- `universal-product-quality` 目录名与其 SKILL.md `name: universal-product-quality-gate` 不一致，历史原因保留目录名。
- Claude Code 的 `~/.claude/skills` 不在 install.sh 管理范围：需要时用 `npx skills add <源> -g -a claude-code`（对全局库做符号链接），hmos-*/openspec-* 从 `~/.agents/skills` 手动拷贝。
- 智能体定义两格式（`agents/zcode` 与 `agents/universal`）语义上必须同步修改；文件级内容允许格式差异（ZCode 专属 frontmatter 字段只存在于 zcode 版）。
