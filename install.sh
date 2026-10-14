#!/usr/bin/env bash
# 用户层技能 / 智能体 / MCP 装配脚本 —— 仓库为单一真源，幂等可重跑。
# 🌟 上游技能不 vendor，统一经 npx skills（vercel-labs/skills）安装到全局库 ~/.agents/skills；
#    自有技能、智能体定义、MCP 配置由本脚本落盘。
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

# ① 上游技能：npx skills 安装。-a codex 的全局目标即 ~/.agents/skills（与既有安装一致）。
#    🌟 单个上游失败不阻断：③④⑤⑥ 是纯本地落盘，必须继续执行。
log "安装 mattpocock/skills（工程/生产力技能，~40 个）"
npx -y skills@latest add mattpocock/skills -g -a codex -y || warn "mattpocock/skills 安装失败，跳过"
log "安装 DietrichGebert/ponytail（ponytail 六件套）"
npx -y skills@latest add DietrichGebert/ponytail -g -a codex -y || warn "DietrichGebert/ponytail 安装失败，跳过"
log "安装 linhay/harmony-next.skills（HarmonyOS 离线知识库，72M，较慢）"
npx -y skills@latest add linhay/harmony-next.skills --skill harmony-next -g -a codex -y || warn "harmony-next 安装失败，跳过"

# ② CLI 自管上游：无 npx skills 源，只能由各自 CLI 管理；缺 CLI 只提示不失败。
if command -v openspec >/dev/null; then
  log "openspec update 刷新 openspec-* 技能"
  openspec update || warn "openspec update 失败，openspec-* 保持现状"
else
  warn "未装 openspec CLI，openspec-* 技能跳过（npm i -g openspec 后重跑）"
fi
if command -v devecocli >/dev/null; then
  warn "hmos-* 9 个技能由 devecocli 管理且需手动 cp 到 ${CANONICAL}（无 npx skills 源），缺失时用 devecocli skills list/find 补装"
else
  warn "未装 devecocli，hmos-* 技能无法检查/补装"
fi

# ③ 自有技能 → 全局库：逐目录 rsync（--delete 只作用于该技能目录自身，不碰其他）。
for d in "$REPO_DIR"/skills/*/; do
  name="$(basename "$d")"
  log "同步自有技能 $name → $CANONICAL/$name"
  rsync -a --delete "${d%/}/" "$CANONICAL/$name/"
done

# ④ 智能体定义 → 双落（两目录各自格式，覆盖同名文件、不动其他文件）。
zcode_agents=("$REPO_DIR"/agents/zcode/*.md)
universal_agents=("$REPO_DIR"/agents/universal/*.agent.md)
log "落智能体定义：ZCode 版 → ${AGENTS_ZCODE}，universal 版 → ${AGENTS_UNIVERSAL}"
mkdir -p "$AGENTS_ZCODE" "$AGENTS_UNIVERSAL"
((${#zcode_agents[@]})) && cp "${zcode_agents[@]}" "$AGENTS_ZCODE/"
((${#universal_agents[@]})) && cp "${universal_agents[@]}" "$AGENTS_UNIVERSAL/"

# ⑤ MCP 配置：均无密钥。ZCode 侧按 server 合并（保留 config.json 里的其他 server 与设置），
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
    echo "错误：jq 合并失败，$ZCODE_CONFIG 未改动（原文件备份在 .bak-${ts}）" >&2
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

# ⑥ 运行时布局：~/.zcode/skills → 全局库符号链接（幂等；真实目录先备份再替换）。
if [ -L "$HOME/.zcode/skills" ]; then
  target="$(readlink "$HOME/.zcode/skills")"
  if [ "$target" = "$CANONICAL" ]; then
    log "~/.zcode/skills 已指向全局库，跳过"
  else
    ln -sfn "$CANONICAL" "$HOME/.zcode/skills"
    log "~/.zcode/skills 重定向：$target → $CANONICAL"
  fi
elif [ -d "$HOME/.zcode/skills" ]; then
  skills_bak="$HOME/.zcode/skills.bak-$ts"
  mv "$HOME/.zcode/skills" "$skills_bak"
  ln -s "$CANONICAL" "$HOME/.zcode/skills"
  log "原目录已备份为 $(basename "$skills_bak")，符号链接 ~/.zcode/skills → $CANONICAL"
else
  mkdir -p "$HOME/.zcode"
  ln -s "$CANONICAL" "$HOME/.zcode/skills"
  log "已建立符号链接 ~/.zcode/skills → $CANONICAL"
fi

log "完成。更新上游用：npx skills update -g；改自有技能后重跑本脚本。"
