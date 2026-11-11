#!/usr/bin/env bash
# 用户层 ZCode 子代理 / Claude settings / hooks 装配脚本 —— magpie 已接管技能、MCP、全局 AGENTS.md
# 与其余子代理（claude / codex / opencode 等），本脚本只负责 magpie 不管的部分。幂等可重跑。
# 上游技能 vendor 进 upstream/（GitHub Actions 周更开 PR 同步）；本机技能/MCP/instructions/子代理以 magpie Library 为准。
set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_ZCODE="$HOME/.zcode/agents"          # ZCode 智能体（.md，含 color/model/tools 等 ZCode 专属字段）
SKILLSHARE_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/skillshare"   # skillshare 中央库（Claude hooks 托管）

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ⚠\033[0m %s\n' "$*"; }

command -v jq >/dev/null || { echo "需要 jq（Claude settings 合并用）"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"

# ① ZCode 子代理定义（magpie Library 的子代理目标不含 zcode，这一路仍由本脚本落盘）。
#    其余子代理（claude / codex / opencode 等）由 magpie Library 管理（应用 Library → Subagents），不再在此落盘。
zcode_agents=("$REPO_DIR"/agents/zcode/*.md)
log "落智能体定义：ZCode 版 -> ${AGENTS_ZCODE}"
mkdir -p "$AGENTS_ZCODE"
((${#zcode_agents[@]})) && cp "${zcode_agents[@]}" "$AGENTS_ZCODE/"

# ② Claude 个人配置（hooks 接线 / 模型 / 权限等）：仓库为脱敏模板（不含任何 token）。
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

log "完成。技能 / MCP / 全局 AGENTS.md / 其余子代理由 magpie Library 管理（改后跑 magpie library sync）；本脚本只管 ZCode 子代理与 Claude settings/hooks。"
