# agent-skills

个人用户层 AI 编码代理的**技能 / 智能体 / MCP 配置 / 全局规则**单一真源，vendor 分发模式（参照 [mattpocock/skills](https://github.com/mattpocock/skills) 的组织方式）：

- **上游技能全量 vendor**——三个 git 上游整树收进 `upstream/`，GitHub Actions 每周自动同步并**开 PR 供审阅**，合并即周更；下游不感知上游变动节奏；
- **一条命令装全部**——`npx skills add <本仓库>` 获得全部技能（含 openspec/hmos 快照），`npx skills update` 锚定本仓库更新；
- **自有内容入库**——自有技能、智能体、MCP、AGENTS.md 改这里，跑 `install.sh` 落盘。

## 仓库结构

```
agent-skills/
├── skills/                  # 自有技能 8 个（真实目录，含 manbo-reader 项目技能）+ 81 个 symlink 指向 upstream/snapshot（APM 包视图，由 scripts/gen-apm-links.sh 生成）
├── apm.yml                  # APM 包清单（name/version），使本仓库可被 apm 作为单一依赖全量分发
├── scripts/                 # gen-apm-links.sh：重建 skills/ symlink 视图与 .apm/agents（周更 CI 自动调用）；sync-to-kimi-work.sh：把鸿蒙/项目技能同步到 Kimi Work 技能目录（macOS，幂等，应用更新后重跑恢复）
├── upstream/                # vendor 的 git 上游（周更 PR 自动整树同步，勿手改）
│   ├── mattpocock/skills/   #   mattpocock/skills
│   ├── DietrichGebert/ponytail/          #   ponytail 六件套
│   ├── docker/skills/       #   Docker 官方 11 个容器技能
│   ├── titanwings/distilly/ #   Distilly：把"某人怎么想"蒸馏成可复用技能（单技能整仓，dot-skill 分支）
│   ├── KKKKhazix/khazix-skills/          #   数字生命卡兹克 6 技能（leader/neat-freak/khazix-writer 等，整仓）
│   ├── tt-a1i/archify/      #   Archify：想法/架构→交互式 HTML 图表（17M 自包含技能）
│   └── linhay/harmony-next.skills/       #   HarmonyOS 离线知识库 72M
├── snapshot/                # 无 git 源的快照（不参与周更，手动刷新）
│   ├── openspec/            #   openspec-* 8 个（openspec CLI 模板，2026-10-14 采）
│   └── huawei-hmos/         #   hmos-* 9 个（devecocli 分发，2026-10-14 采）
├── agents/zcode/            # ZCode 智能体（.md，含 color/model/thoughtLevel/tools 专属字段）
├── agents/universal/        # 跨 agent 智能体（.agent.md 精简格式，与 zcode 版语义保持一致）
├── mcp/zcode-mcp.json       # ZCode MCP servers（install.sh jq 合并进 ~/.zcode/cli/config.json）
├── mcp/claude-mcp.json      # Claude Code MCP servers（skillshare 导入源 → sync 进 ~/.claude.json；无 skillshare 时 jq 直合）
├── hooks/                   # 钩子库存档：claude-settings 脱敏模板（合并部署）+ codex/orca 快照（仅存档）
├── commands/                # 斜杠命令存档：OpenSpec opsx 三工具格式（install.sh cp 部署）
├── docs/                    # 通用知识沉淀（检索到官方依据后成文：git 常用知识、发布流程、工具兼容坑、订阅额度比价、鸿蒙系列：MCP 生态、单测配方、设备测试、CLI、一多、知识检索等）
├── AGENTS.md                # 全局个人规则（落盘 ~/.zcode/AGENTS.md）
├── .upstream/upstreams.json # 同步清单：源仓库 / 分支 / 子路径 / 落点 / LICENSE 落位
├── .github/scripts/sync-upstream.sh      # 同步逻辑（本地也可直接跑）
└── .github/workflows/sync-upstream.yml   # 周一 11:00（北京）cron + 手动 dispatch，固定分支开/更新 PR
```

## 用法

```bash
# 新机初始化 / 日常重装（幂等；公开仓库 clone 无需认证）
git clone https://github.com/Rainbow609/agent-skills.git   # clone 到任意位置，脚本自定位仓库根
cd agent-skills
./install.sh

# 下游也可以只装技能（智能体/MCP/AGENTS.md 仍走 install.sh）
npx skills add Rainbow609/agent-skills -g

# APM 全量分发（一条依赖装载 88 技能 + 12 智能体，lockfile 锁定 commit/SHA）
apm install -g Rainbow609/agent-skills#v2026.10.14     # 用户级；或在项目 apm.yml 中引用

# 升级技能 = 合并周更 PR 后重跑 install.sh（或直接 git pull + install.sh）
```

前置：`node`/`npx`、`jq`、`rsync`、`git`；`apm`（`brew install apm`，启用锁定分发与智能体跨格式转换；缺失时自动回退 npx 仅装技能）；`skillshare`（`brew install skillshare`，托管 Claude 侧 MCP/hooks；缺失时 install.sh 回退脚本内 jq 合并）。

**分发分工（2026-10-14 起；2026-10-16 起 skillshare 接管 Claude MCP/hooks）**：
- `apm install -g`（清单 `apm/home-apm.yml` → `~/.apm/apm.yml`）：全部 88 技能 → `~/.agents/skills` + `~/.claude/skills`；12 智能体 → `~/.agents/agents` + `~/.claude/agents`（.md）+ `~/.codex/agents`（自动转 .toml）。lockfile 记录精确 commit 与每文件 sha256。**注意**：apm 会把包内 `hooks/` 当「可执行原语」自动注入 claude/codex，与下方分工冲突，故 install.sh 先执行 `apm deny --user Rainbow609/agent-skills`（写 `~/.apm/config.json`，幂等；deny 覆盖 hooks/mcp/bin/canvas/lsp）。
- `skillshare`（中央库 `~/.config/skillshare/`，install.sh 自动无交互 bootstrap，不接技能 target）：① `mcp/claude-mcp.json` 导入为 Skillshare 源后 `sync mcp` 写入 `~/.claude.json`（Claude Code 唯一用户级 MCP 路径）；② `hooks/claude-settings.json` 的 hooks 段成为条目 `orca`（adopt 现有注册、自带备份/漂移检测）。
- `install.sh` 其余步骤：ZCode 专属落点（`~/.zcode/agents` 富格式、symlink）、ZCode MCP 合并（skillshare 无 zcode MCP 客户端，留在脚本内 jq）、Claude settings 非 hooks 键合并、commands、AGENTS.md。
- 无 apm 的机器：自动回退 `npx skills add`（装技能，不装智能体）。

## 来源与许可

| 目录 | 来源 | 同步方式 |
|---|---|---|
| `upstream/mattpocock/skills` | [mattpocock/skills](https://github.com/mattpocock/skills)（MIT，见其 LICENSE） | 周更 PR |
| `upstream/DietrichGebert/ponytail` | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)（MIT） | 周更 PR |
| `upstream/docker/skills` | [docker/skills](https://github.com/docker/skills)（Apache-2.0，见其 LICENSE） | 周更 PR |
| `upstream/titanwings/distilly` | [titanwings/distilly](https://github.com/titanwings/distilly)（MIT，单技能整仓形态，SKILL.md+prompts+tools 自包含） | 周更 PR |
| `upstream/KKKKhazix/khazix-skills` | [KKKKhazix/khazix-skills](https://github.com/KKKKhazix/khazix-skills)（MIT，6 技能根级平铺整仓） | 周更 PR |
| `upstream/tt-a1i/archify` | [tt-a1i/archify](https://github.com/tt-a1i/archify)（MIT，仅取 `archify/` 技能子目录） | 周更 PR |
| `upstream/linhay/harmony-next.skills` | [linhay/harmony-next.skills](https://github.com/linhay/harmony-next.skills)（仓库页标 MIT，未附 LICENSE 文件） | 周更 PR |
| `snapshot/openspec` | openspec CLI（npm）模板快照，2026-10-14 采集 | 手动（`openspec update` 后拷回） |
| `commands/` | OpenSpec CLI 生成的 `opsx:*` 斜杠命令（zcode/claude/iflow 三工具格式快照） | 手动（`openspec update` 后拷回，见 commands/README.md） |
| `snapshot/huawei-hmos` | 华为官方 DevEco 技能库（`devecocli skills add`）快照，2026-10-14 采集 | 手动（devecocli 更新后拷回） |
| `skills/`、`agents/`、`mcp/`、`AGENTS.md` | 自有 | 直接改 |

## 注意事项

- **技能目录是 APM 包视图**：`skills/` 下 81 个 symlink（指向 upstream/snapshot）由 `scripts/gen-apm-links.sh` 生成，勿手改；增删技能后重跑该脚本。APM 发现规则（实测 v0.33.0）：只认根 `skills/` 一层直接子目录、symlink 仅限包内、`.apm/skills` 在根 skills/ 存在时被忽略。
- **clone 位置不限，勿写死路径**：install.sh 以 `$(dirname "${BASH_SOURCE[0]}")` 自定位仓库根，sync-upstream.sh 以 `git rev-parse --show-toplevel` 定位——这是 dotfiles 仓库的通行做法（self-locating bootstrap，参见 [holman/dotfiles](https://github.com/holman/dotfiles)）。新增脚本或文档时一律不要写死 clone 路径。
- **技能落盘为独立拷贝**：`npx skills` 对本地源实测走 copy（非 symlink），改仓库后需重跑 `install.sh` 同步到全局库。
- **MCP 模板含本机路径**：`/opt/homebrew/bin/...` 为 homebrew 二进制；`zcode-mcp.json` 的 `deveco-codegenie` command 指向**本机 guard 脚本**（`~/.local/bin/codegenie-mcp-guard`，防 codegenie 并发丢包，不入库，来历见 [docs/deveco-codegenie-mcp-guard.md](./docs/deveco-codegenie-mcp-guard.md)）——他机使用前请确认对应文件存在，或改回直连 `codegenie-mcp-server` / 自己环境下的命令路径。
- **`upstream/` 勿手改**：周更 PR 会整树覆盖。要魔改上游技能请 fork 源仓库改 `upstreams.json` 指向，或拷进 `skills/` 改名自管。
- **周更 PR 复用同一分支**（`upstream-sync/weekly`）：上周未合并时本周推送自动更新该 PR，不会堆积。
- **MCP 配置与 hooks 模板均无密钥**：MCP 全部指向 homebrew 二进制；hooks 的 claude-settings 模板已剔除 token（合并部署时本机凭据原样保留，新机需自行补）。若将来加带 token 的内容，用环境变量引用，**密钥绝不入库**。
- **hooks 目录**：`claude-settings.json` 为脱敏模板——hooks 段由 skillshare 托管（条目 `orca`），非 hooks 键由 install.sh jq 合并（本机 secrets 保留）；`codex-hooks.json` 与 `orca/*.sh` 由对应工具（cmux/Orca）自管，**仅存档不反向同步**。2026-10-16 起 apm 对该包的 hooks 集成已在个人配置 `deny`（曾发现其把 `hooks/` 自动注入 claude/codex 两侧：claude 侧与 skillshare 冲突产生重复注册、codex 侧违反「仅存档」意图）；`codex-hooks.json` 的既有 `~/.codex/hooks.json` 产物保持原样（详见 [hooks/README.md](./hooks/README.md)）。
- ZCode 侧 MCP 用 jq 按 server **合并**（config.json 里其他 server 与设置不动），落盘前自动备份为 `.bak-<时间戳>`。
- **Claude MCP 的落点是 `~/.claude.json`**（Claude Code 唯一用户级路径，官方文档确认）：由 skillshare 托管（`claude mcp get <name>` 可验）；旧版脚本写过的 `~/.claude/mcp.json`（cmux-mcp）并非 Claude 读取路径，已废弃——遗留文件可手动删除，install.sh 不再写它。
- `universal-product-quality` 目录名与其 SKILL.md `name: universal-product-quality-gate` 不一致，历史原因保留目录名。
- **开源与许可**：自有内容（`skills/`、`agents/`、`mcp/`、`install.sh`、`AGENTS.md`、工作流）以仓库根 [LICENSE](./LICENSE)（MIT）发布；`upstream/`、`snapshot/` 为各上游的再分发，许可见上表与各目录内保留的 LICENSE/说明文件。
- Claude Code 的 `~/.claude/skills` 不在 install.sh 管理范围：需要时用 `npx skills add <owner>/agent-skills -g -a claude-code`。
