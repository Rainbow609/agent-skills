# opencode 全局接入同步链的坑（1.18.x）

> 实现落点：本仓库 `install.sh` ③④⑨ 的 opencode 分支＋`agents/opencode/`（12 转换件）＋README「MCP 模板含本机路径」条目；PR #27（2026-10-19 合入）。
> 同族文档：[opencode-zen-gateway-session-header.md](./opencode-zen-gateway-session-header.md)（Go 网关线，与本文互补不重复）。

## 技能：零新管道（官方文档明文）

- opencode 原生读取 **`~/.agents/skills/`**（全局）——与 ZCode/kimi-code/codex 共用的全局技能库即天然目标，无需复制或软链；项目级另读 `.opencode/skills/`、`.claude/skills/`（向上走到 worktree）。
- 推论：接 opencode 只需接 agents＋MCP＋全局规则三面，技能面零动作。

## 智能体：数组式 tools 会让整个配置加载失败（实测）

- 全局智能体目录＝`~/.config/opencode/agents/`（**复数**，官方 agents 文档明文；文件名即 agent 名）。
- 🌟 frontmatter 用数组式 `tools:` 在 opencode 1.18 是 schema 非法，且**报错的是配置校验整体**：连 `opencode mcp list` 都无法执行，报 `Configuration is invalid at <file>`。存量错误副本曾让 opencode 处于半瘫痪。
- 正确写法：`description`（必填）＋`mode: subagent`；工具约束用 `permission` 对象（allow/ask/deny），只读代理＝`permission: {edit: deny, write: deny}`；`tools` 字段已弃用（官方文档明文）。
- 验证命令：`opencode agent list`（同时完成 schema 校验与加载列表）。
- 本仓库形态：`agents/opencode/`＝universal 正文逐字对拍＋opencode 专属 frontmatter；手改 universal 正文后需同步转换该目录（install.sh 注释已标注）。

## MCP：本地 server 格式转换（官方 config schema）

- opencode.json 形状：`{"mcp":{"<名>":{"type":"local","command":["cmd","arg"],"environment":{...},"enabled":true}}}`——`command` 是**数组**（非 command＋args 两字段）、env 键名是 `environment`。
- 合并用 jq `*` 递归深合并（同 #25 教训：同名 server 的本机独有 env 键不被浅合并抹掉）；现有 server（如 reeve）原样保留。
- `opencode mcp list` 逐 server 报 connected 状态＝连通性验收命令。

## 全局规则与其他坑

- 全局 AGENTS.md＝`~/.config/opencode/AGENTS.md`（官方 rules 文档明文）——软链到单一真源即可。
- 🌟 `git switch -c <branch> origin/main` 会自动 track 主分支——须 `git branch --unset-upstream`（防图形界面推送按钮把代码送进保护分支）。
- 🌟 `apm deny` 即使 `--user`（写个人 `~/.apm/config.json`）也要求 **CWD 存在 apm.yml**，否则 exit 1 静默假失败——脚本内必须 `cd` 到含 apm.yml 的目录执行（install.sh 已修，PR #27 内 bc76eda）。
- apm 对 opencode 是「部分支持」target（hooks 不注入；项目级 skills/instructions 可）——全局三面仍归 install.sh。
- OpenSpec 的 opsx 命令/技能由 openspec CLI 自管（写入 `~/.opencode/{commands,skills}`），与本文的同步链并行，勿混装。
