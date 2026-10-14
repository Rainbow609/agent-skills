#!/usr/bin/env bash
# 用户层技能 / 智能体 / MCP / 全局 AGENTS.md 装配脚本 —— 仓库为单一真源，幂等可重跑。
# 🌟 上游技能已全量 vendor 进 upstream/（GitHub Actions 周更开 PR 同步），本仓库即唯一技能源；
#    下游一条命令 npx skills add 本仓库即可获得全部 88 个技能。
set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL="$HOME/.agents/skills"            # 全局技能库：npx skills 全局目标，ZCode/kimi-code/codex 等共用
AGENTS_ZCODE="$HOME/.zcode/agents"          # ZCode 智能体（.md，含 color/model/tools 等 ZCode 专属字段）
AGENTS_UNIVERSAL="$HOME/.agents/agents"     # 跨 agent 智能体（.agent.md，精简格式）

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ⚠\033[0m %s\n' "$*"; }

command -v node >/dev/null || { echo "需要 node/npx（npx skills 依赖）"; exit 1; }
command -v jq >/dev/null || { echo "需要 jq（MCP 配置合并用）"; exit 1; }
command -v rsync >/dev/null || { echo "需要 rsync"; exit 1; }

# ① 全量技能：从本仓库（本地路径源）安装全部技能到全局库。单条失败不阻断本地落盘步骤。
#    🌟 必须 --full-depth：CLI 默认只扫根目录与 skills/ 深度 3，upstream/、snapshot/ 下的 62 个
#    vendored 技能只有全树扫描才装得上。
log "从本仓库安装全部技能（npx skills -> ${CANONICAL}）"
npx -y skills@latest add "$REPO_DIR" -g -a codex -y --full-depth || warn "技能安装失败，跳过"
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

# ③ 智能体定义 → 双落（两目录各自格式，覆盖同名文件、不动其他文件）。
zcode_agents=("$REPO_DIR"/agents/zcode/*.md)
universal_agents=("$REPO_DIR"/agents/universal/*.agent.md)
log "落智能体定义：ZCode 版 -> ${AGENTS_ZCODE}，universal 版 -> ${AGENTS_UNIVERSAL}"
mkdir -p "$AGENTS_ZCODE" "$AGENTS_UNIVERSAL"
((${#zcode_agents[@]})) && cp "${zcode_agents[@]}" "$AGENTS_ZCODE/"
((${#universal_agents[@]})) && cp "${universal_agents[@]}" "$AGENTS_UNIVERSAL/"

# ④ MCP 配置：均无密钥。ZCode 侧按 server 合并（保留 config.json 里的其他 server 与设置），
#    config.json 不存在时（新机首次配置）以模板生成；Claude 侧为整文件覆盖。落盘前各自备份。
ts="$(date +%Y%m%d-%H%M%S)"
ZCODE_CONFIG="$HOME/.zcode/cli/config.json"
if [ -f "$ZCODE_CONFIG" ]; then
  cp "$ZCODE_CONFIG" "$ZCODE_CONFIG.bak-$ts"
  if jq --slurpfile mcp "$REPO_DIR/mcp/zcode-mcp.json" \
      '.mcp.servers = ((.mcp.servers // {}) + $mcp[0].servers)' \
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
  [ -f "$HOME/.claude/mcp.json" ] && cp "$HOME/.claude/mcp.json" "$HOME/.claude/mcp.json.bak-$ts"
  cp "$REPO_DIR/mcp/claude-mcp.json" "$HOME/.claude/mcp.json"
  log "MCP 已写入 ~/.claude/mcp.json（备份 .bak-${ts}）"
else
  warn "未找到 ~/.claude，Claude MCP 跳过"
fi

# ⑤ Claude 个人配置（hooks 接线 / 模型 / 权限等）：仓库为脱敏模板（不含任何 token）。
#    合并语义：本机 secrets 与本地独有键保留，模板键优先（jq 右侧覆盖）。
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -d "$HOME/.claude" ]; then
  if [ -f "$CLAUDE_SETTINGS" ]; then
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak-$ts"
    if jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" "$REPO_DIR/hooks/claude-settings.json" > "$CLAUDE_SETTINGS.new" && [ -s "$CLAUDE_SETTINGS.new" ]; then
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

log "完成。上游技能由 GitHub Actions 周更开 PR；改自有技能/智能体/MCP/hooks/commands/AGENTS.md 后重跑本脚本。"
