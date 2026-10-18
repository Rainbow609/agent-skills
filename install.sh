#!/usr/bin/env bash
# 用户层技能 / 智能体 / MCP / 全局 AGENTS.md 装配脚本 —— 仓库为单一真源，幂等可重跑。
# 🌟 上游技能已全量 vendor 进 upstream/（GitHub Actions 周更开 PR 同步），本仓库即唯一技能源；
#    下游一条命令 npx skills add 本仓库即可获得全部 88 个技能。
# Claude 侧 MCP 与 hooks 由 skillshare 托管（缺失时回退脚本内 jq 合并，见 ④⑤）。
set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL="$HOME/.agents/skills"            # 全局技能库：npx skills 全局目标，ZCode/kimi-code/codex 等共用
AGENTS_ZCODE="$HOME/.zcode/agents"          # ZCode 智能体（.md，含 color/model/tools 等 ZCode 专属字段）
AGENTS_UNIVERSAL="$HOME/.agents/agents"     # 跨 agent 智能体（.agent.md，精简格式）
SKILLSHARE_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/skillshare"   # skillshare 中央库（Claude MCP/hooks 托管）

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ⚠\033[0m %s\n' "$*"; }

command -v node >/dev/null || { echo "需要 node/npx（npx skills 依赖）"; exit 1; }
command -v jq >/dev/null || { echo "需要 jq（MCP 配置合并用）"; exit 1; }
command -v rsync >/dev/null || { echo "需要 rsync"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"

# ① 全量技能 + 双库智能体：apm 优先（lockfile 锁定 commit/SHA 并跨格式转换智能体），无 apm 回退 npx skills。
if command -v apm >/dev/null; then
  log "apm 全量分发（用户级）：技能+智能体，清单取自仓库 apm/home-apm.yml"
  mkdir -p "$HOME/.apm"
  [ -f "$HOME/.apm/apm.yml" ] && cp "$HOME/.apm/apm.yml" "$HOME/.apm/apm.yml.bak-$ts"
  cp "$REPO_DIR/apm/home-apm.yml" "$HOME/.apm/apm.yml"
  # 🌟 apm 会把包内 hooks/ 目录当「可执行原语」自动集成进 claude/codex 配置——与本题分工冲突
  #    （Claude hooks 归 skillshare、codex/cmux hooks 由工具自管仅存档）。个人级 deny 一次，
  #    覆盖 hooks/mcp/bin/canvas/lsp（写 ~/.apm/config.json，幂等，deny 恒胜）。
  #    🌟 apm deny 即使 --user 也要求 CWD 存在 apm.yml（否则 exit 1 静默假失败）——须 cd 仓库根执行。
  (cd "$REPO_DIR" && apm deny --user Rainbow609/agent-skills >/dev/null 2>&1) || warn "apm deny 未生效，hooks 可能被 apm 重复注入（检查 ~/.apm/config.json）"
  if apm install -g; then
    log "apm 安装完成（lock: ~/.apm/apm.lock.yaml）"
  else
    warn "apm 安装失败——目标目录存在非 apm 管理的同名文件时需先手动清理或改用 apm install -g --force（详见 README）；本次跳过"
  fi
else
  warn "未装 apm（brew install apm 可启用锁定分发），回退 npx skills"
  log "从本仓库安装全部技能（npx skills -> ${CANONICAL}）"
  npx -y skills@latest add "$REPO_DIR" -g -a codex -y --full-depth || warn "技能安装失败，跳过"
fi
expected="$(find "$REPO_DIR" -name SKILL.md -not -path '*/.git/*' | wc -l | tr -d ' ')"
installed="$(find -L "$CANONICAL" -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
if [ "$installed" -lt "$expected" ]; then
  warn "技能数量对账：仓库 ${expected} 个，全局库仅 ${installed} 个，部分技能未安装"
else
  log "技能数量对账通过：${installed}/${expected}"
fi

# ② 自有技能 → 全局库：逐目录 rsync（--delete 只作用于该技能目录自身，不碰其他）。
for d in "$REPO_DIR"/skills/*/; do
  name="$(basename "$d")"
  log "同步自有技能 ${name} -> ${CANONICAL}/${name}"
  rsync -a --delete "${d%/}/" "$CANONICAL/$name/"
done

# ③ 智能体定义 → 三落（各目录各自格式，覆盖同名文件、不动其他文件）。
zcode_agents=("$REPO_DIR"/agents/zcode/*.md)
universal_agents=("$REPO_DIR"/agents/universal/*.agent.md)
log "落智能体定义：ZCode 版 -> ${AGENTS_ZCODE}，universal 版 -> ${AGENTS_UNIVERSAL}"
mkdir -p "$AGENTS_ZCODE" "$AGENTS_UNIVERSAL"
((${#zcode_agents[@]})) && cp "${zcode_agents[@]}" "$AGENTS_ZCODE/"
((${#universal_agents[@]})) && cp "${universal_agents[@]}" "$AGENTS_UNIVERSAL/"
# opencode 版：universal 正文 + opencode 专属 frontmatter（mode: subagent；只读代理 permission deny
# edit/write——tools 数组在 opencode 1.18 会令配置校验直接报错）。手改 universal 正文后需同步转换本目录。
if [ -d "$HOME/.config/opencode" ]; then
  opencode_agents=("$REPO_DIR"/agents/opencode/*.md)
  log "落智能体定义：opencode 版 -> ${HOME}/.config/opencode/agents"
  mkdir -p "$HOME/.config/opencode/agents"
  ((${#opencode_agents[@]})) && cp "${opencode_agents[@]}" "$HOME/.config/opencode/agents/"
fi

# ④ MCP 配置：均无密钥。
#    ZCode 侧：skillshare 的 MCP 客户端列表不含 zcode，无法接管，由本脚本 jq 按 server 合并
#    （保留 config.json 里的其他 server 与设置；不存在时以模板生成）。
#    🌟 合并用 jq 的 `*`（递归深合并）而非 `+`（浅合并，同名键整体替换）：同名 server 的
#    env 必须逐键合并——模板键优先、本机独有键保留。曾用 `+` 导致 deveco-codegenie 的
#    UI_VERIFY_*（verify_ui 的模型三件套）每跑一次 install.sh 就被抹掉一次。
#    Claude 侧：skillshare 接管——仓库定义导入 Skillshare 源后 sync 进 ~/.claude.json
#    （Claude Code 唯一的用户级 MCP 路径；旧脚本写过的 ~/.claude/mcp.json 并非 Claude 读取路径）。
#    skillshare 缺失时回退为 jq 直接合并进 ~/.claude.json。
#    opencode 侧：skillshare 同样不接管，jq 合并进 ~/.config/opencode/opencode.json 并做格式转换
#    （opencode 要求 command 为数组、env 键名为 environment、需补 type/enabled；保留 reeve 等本机已有 server）。
ZCODE_CONFIG="$HOME/.zcode/cli/config.json"
if [ -f "$ZCODE_CONFIG" ]; then
  cp "$ZCODE_CONFIG" "$ZCODE_CONFIG.bak-$ts"
  if jq --slurpfile mcp "$REPO_DIR/mcp/zcode-mcp.json" \
      '.mcp.servers = ((.mcp.servers // {}) * $mcp[0].servers)' \
      "$ZCODE_CONFIG" > "$ZCODE_CONFIG.new" && [ -s "$ZCODE_CONFIG.new" ]; then
    mv "$ZCODE_CONFIG.new" "$ZCODE_CONFIG"
    log "MCP 已合并进 ${ZCODE_CONFIG}（备份 .bak-${ts}）"
  else
    rm -f "$ZCODE_CONFIG.new"
    echo "错误：jq 合并失败，${ZCODE_CONFIG} 未改动（原文件备份在 .bak-${ts}）" >&2
    exit 1
  fi
else
  mkdir -p "$(dirname "$ZCODE_CONFIG")"
  jq -n --slurpfile mcp "$REPO_DIR/mcp/zcode-mcp.json" \
    '{mcp: {servers: $mcp[0].servers}}' > "$ZCODE_CONFIG"
  log "已按模板生成 ${ZCODE_CONFIG}（新机首次配置）"
fi
if [ -d "$HOME/.claude" ]; then
  if command -v skillshare >/dev/null; then
    if [ ! -f "$SKILLSHARE_CFG_DIR/config.yaml" ]; then
      log "初始化 skillshare 配置（无技能 target，仅托管 MCP/hooks）"
      skillshare init --no-copy --no-git --no-targets --no-skill --no-tui || warn "skillshare init 失败"
    fi
    for srv in $(jq -r '.mcpServers | keys[]' "$REPO_DIR/mcp/claude-mcp.json"); do
      skillshare mcp import "$srv" --from claude --file "$REPO_DIR/mcp/claude-mcp.json" \
        --target claude --replace --no-tui || warn "skillshare 导入 ${srv} 失败"
    done
    skillshare sync mcp -g || warn "skillshare sync mcp 失败"
    log "Claude MCP 已由 skillshare 落盘 ~/.claude.json（源：mcp/claude-mcp.json）"
  else
    warn "未装 skillshare（brew install skillshare 可启用托管），回退 jq 合并 ~/.claude.json"
    if [ -f "$HOME/.claude.json" ]; then
      cp "$HOME/.claude.json" "$HOME/.claude.json.bak-$ts"
      if jq --slurpfile mcp "$REPO_DIR/mcp/claude-mcp.json" \
          '.mcpServers = ((.mcpServers // {}) + $mcp[0].mcpServers)' \
          "$HOME/.claude.json" > "$HOME/.claude.json.new" && [ -s "$HOME/.claude.json.new" ]; then
        mv "$HOME/.claude.json.new" "$HOME/.claude.json"
        log "MCP 已合并进 ~/.claude.json（备份 .bak-${ts}）"
      else
        rm -f "$HOME/.claude.json.new"
        echo "错误：jq 合并失败，~/.claude.json 未改动（原文件备份在 .bak-${ts}）" >&2
        exit 1
      fi
    else
      warn "~/.claude.json 不存在（先启动一次 Claude Code 再重跑），Claude MCP 回退跳过"
    fi
  fi
else
  warn "未找到 ~/.claude，Claude MCP 跳过"
fi
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
if [ -d "$HOME/.config/opencode" ]; then
  if [ -f "$OPENCODE_CONFIG" ]; then
    cp "$OPENCODE_CONFIG" "$OPENCODE_CONFIG.bak-$ts"
    # 🌟 同 ZCode 侧：用 jq `*` 深合并而非 `+`，同名 server 的本机独有 env 键才不会被抹掉。
    if jq --slurpfile mcp "$REPO_DIR/mcp/zcode-mcp.json" \
        '.mcp = ((.mcp // {}) * ($mcp[0].servers | to_entries | map({key: .key, value: {type: "local", command: ([.value.command] + (.value.args // [])), environment: (.value.env // {}), enabled: true}}) | from_entries))' \
        "$OPENCODE_CONFIG" > "$OPENCODE_CONFIG.new" && [ -s "$OPENCODE_CONFIG.new" ]; then
      mv "$OPENCODE_CONFIG.new" "$OPENCODE_CONFIG"
      log "opencode MCP 已合并进 ${OPENCODE_CONFIG}（备份 .bak-${ts}）"
    else
      rm -f "$OPENCODE_CONFIG.new"
      echo "错误：jq 合并失败，${OPENCODE_CONFIG} 未改动（原文件备份在 .bak-${ts}）" >&2
      exit 1
    fi
  else
    jq -n --slurpfile mcp "$REPO_DIR/mcp/zcode-mcp.json" \
      '{mcp: ($mcp[0].servers | to_entries | map({key: .key, value: {type: "local", command: ([.value.command] + (.value.args // [])), environment: (.value.env // {}), enabled: true}}) | from_entries)}' \
      > "$OPENCODE_CONFIG"
    log "已按模板生成 ${OPENCODE_CONFIG}（新机首次配置）"
  fi
else
  warn "未找到 ~/.config/opencode，opencode MCP 跳过"
fi

# ⑤ Claude 个人配置（hooks 接线 / 模型 / 权限等）：仓库为脱敏模板（不含任何 token）。
#    hooks 段（7 个 orca 事件）由 skillshare 托管（条目 orca，adopt/备份/漂移检测一体），
#    其余键由本脚本 jq 合并（保留本机 secrets 与本地独有键，模板键优先）。
#    skillshare 缺失时回退为整模板合并（含 hooks，即旧行为）。
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -d "$HOME/.claude" ]; then
  use_skillshare=false
  if command -v skillshare >/dev/null && [ -f "$SKILLSHARE_CFG_DIR/config.yaml" ]; then use_skillshare=true; fi
  if [ -f "$CLAUDE_SETTINGS" ]; then
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak-$ts"
    if [ "$use_skillshare" = true ]; then
      merge='.[0] * (.[1] | del(.hooks))'   # hooks 归 skillshare，其余键照旧合并
    else
      merge='.[0] * .[1]'
    fi
    if jq -s "$merge" "$CLAUDE_SETTINGS" "$REPO_DIR/hooks/claude-settings.json" > "$CLAUDE_SETTINGS.new" && [ -s "$CLAUDE_SETTINGS.new" ]; then
      mv "$CLAUDE_SETTINGS.new" "$CLAUDE_SETTINGS"
      log "Claude settings 已合并（保留本机 secrets；备份 .bak-${ts}）"
    else
      rm -f "$CLAUDE_SETTINGS.new"
      echo "错误：Claude settings 合并失败，${CLAUDE_SETTINGS} 未改动" >&2
      exit 1
    fi
  else
    cp "$REPO_DIR/hooks/claude-settings.json" "$CLAUDE_SETTINGS"
    warn "已生成 Claude settings（模板不含 token，请补 env.ANTHROPIC_AUTH_TOKEN 后再用）"
  fi
  if [ "$use_skillshare" = true ]; then
    entry_file="$(mktemp)"
    jq '{description: "Orca agent hooks (claude)", bindings: {claude: {events: .hooks}}}' \
      "$REPO_DIR/hooks/claude-settings.json" > "$entry_file"
    skillshare hooks add orca --file "$entry_file" --replace --sync -g \
      || warn "skillshare hooks 托管失败（hooks 已在 settings 中，功能不受影响）"
    rm -f "$entry_file"
    log "Claude hooks 已由 skillshare 托管（条目 orca，源：hooks/claude-settings.json）"
  fi
else
  warn "未找到 ~/.claude，Claude settings 跳过"
fi

# ⑥ 运行时布局：~/.zcode/skills → 全局库符号链接（幂等；真实目录先备份再替换）。
if [ -L "$HOME/.zcode/skills" ]; then
  target="$(readlink "$HOME/.zcode/skills")"
  if [ "$target" = "$CANONICAL" ]; then
    log "~/.zcode/skills 已指向全局库，跳过"
  else
    ln -sfn "$CANONICAL" "$HOME/.zcode/skills"
    log "~/.zcode/skills 重定向：${target} -> ${CANONICAL}"
  fi
elif [ -d "$HOME/.zcode/skills" ]; then
  skills_bak="$HOME/.zcode/skills.bak-$ts"
  mv "$HOME/.zcode/skills" "$skills_bak"
  ln -s "$CANONICAL" "$HOME/.zcode/skills"
  log "原目录已备份为 $(basename "$skills_bak")，符号链接 ~/.zcode/skills -> ${CANONICAL}"
else
  mkdir -p "$HOME/.zcode"
  ln -s "$CANONICAL" "$HOME/.zcode/skills"
  log "已建立符号链接 ~/.zcode/skills -> ${CANONICAL}"
fi

# ⑦ 全局 AGENTS.md：仓库为单一真源，落盘 ~/.zcode/AGENTS.md。
ZCODE_AGENTS="$HOME/.zcode/AGENTS.md"
mkdir -p "$HOME/.zcode"
if [ -f "$ZCODE_AGENTS" ]; then
  cp "$ZCODE_AGENTS" "$ZCODE_AGENTS.bak-$ts"
  log "原 AGENTS.md 已备份 .bak-${ts}"
fi
cp "$REPO_DIR/AGENTS.md" "$ZCODE_AGENTS"
log "AGENTS.md 已落盘 ~/.zcode/AGENTS.md"

# ⑧ 斜杠命令落盘：OpenSpec opsx 命令（三工具各自格式，cp 只覆盖同名不删他命令）。
if [ -d "$HOME/.zcode" ]; then
  mkdir -p "$HOME/.zcode/commands/opsx"
  cp "$REPO_DIR"/commands/zcode/opsx/*.md "$HOME/.zcode/commands/opsx/"
  log "opsx 命令已落盘 ~/.zcode/commands/opsx/"
fi
if [ -d "$HOME/.claude" ]; then
  mkdir -p "$HOME/.claude/commands/opsx"
  cp "$REPO_DIR"/commands/claude/opsx/*.md "$HOME/.claude/commands/opsx/"
  log "opsx 命令已落盘 ~/.claude/commands/opsx/"
fi
if [ -d "$HOME/.iflow" ]; then
  cp "$REPO_DIR"/commands/iflow/opsx-*.md "$HOME/.iflow/commands/" 2>/dev/null || {
    mkdir -p "$HOME/.iflow/commands"
    cp "$REPO_DIR"/commands/iflow/opsx-*.md "$HOME/.iflow/commands/"
  }
  log "opsx 命令已落盘 ~/.iflow/commands/"
fi

# ⑨ 各 agent 的全局规则软链：Claude Code / Codex / opencode 复用 ~/.zcode/AGENTS.md 单一真源（幂等；真实文件先备份再替换）。
for d in "$HOME/.claude" "$HOME/.codex" "$HOME/.config/opencode"; do
  if [ ! -d "$d" ]; then warn "未找到 ${d}，全局规则软链跳过"; continue; fi
  link="$d/AGENTS.md"
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$ZCODE_AGENTS" ]; then
      log "${link} 已指向单一真源，跳过"
    else
      ln -sfn "$ZCODE_AGENTS" "$link"
      log "${link} 重定向 -> ${ZCODE_AGENTS}"
    fi
  elif [ -f "$link" ]; then
    cp "$link" "$link.bak-$ts"
    ln -sfn "$ZCODE_AGENTS" "$link"
    log "${link} 原文件已备份 .bak-${ts} 并改为软链"
  else
    ln -s "$ZCODE_AGENTS" "$link"
    log "已建立软链 ${link} -> ${ZCODE_AGENTS}"
  fi
done

log "完成。上游技能由 GitHub Actions 周更开 PR；改自有技能/智能体/MCP/hooks/commands/AGENTS.md 后重跑本脚本。"
