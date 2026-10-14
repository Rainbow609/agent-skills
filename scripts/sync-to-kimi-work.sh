#!/usr/bin/env bash
# 将本仓库中的鸿蒙 / 项目技能同步到 Kimi Work 的技能目录（macOS）。
# 用途：Kimi Work（kimi-desktop）的技能索引扫描其 daimon 技能目录，
#       应用大版本更新可能重置该目录，重跑本脚本即可恢复。
# 幂等：以仓库为源做镜像同步（--delete 只作用于各技能自己的子目录）。
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIMI_SKILLS="$HOME/Library/Application Support/kimi-desktop/daimon-share/daimon/skills"

# 同步清单：Kimi Work 目标目录名 -> 仓库内源目录（相对仓库根）
SYNC_MAP=(
  "manbo-reader|skills/manbo-reader"
  "harmonyos-development|skills/harmonyos-development"
  "harmonyos-arkts|skills/harmonyos-arkts"
  "arkui-design|skills/arkui-design"
  "harmonyos-device-testing|skills/harmonyos-device-testing"
  "harmony-next|upstream/linhay/harmony-next.skills"
)

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ⚠\033[0m %s\n' "$*"; }

if [ ! -d "$KIMI_SKILLS" ]; then
  echo "未找到 Kimi Work 技能目录: $KIMI_SKILLS" >&2
  echo "（本脚本仅适用于 macOS 上的 Kimi 桌面版）" >&2
  exit 1
fi
command -v rsync >/dev/null || { echo "需要 rsync"; exit 1; }

# huawei-hmos 快照下的 hmos-* 技能逐个加入清单
for d in "$REPO_DIR"/snapshot/huawei-hmos/hmos-*/; do
  [ -f "$d/SKILL.md" ] && SYNC_MAP+=("$(basename "$d")|snapshot/huawei-hmos/$(basename "$d")")
done

ok=0; fail=0
for pair in "${SYNC_MAP[@]}"; do
  name="${pair%%|*}"
  src="$REPO_DIR/${pair#*|}"
  if [ ! -f "$src/SKILL.md" ]; then
    warn "跳过 $name：源目录缺少 SKILL.md（$src）"
    fail=$((fail + 1))
    continue
  fi
  mkdir -p "$KIMI_SKILLS/$name"
  rsync -a --delete "$src/" "$KIMI_SKILLS/$name/"
  ok=$((ok + 1))
done

log "同步完成：$ok 个技能 → $KIMI_SKILLS"
[ "$fail" -gt 0 ] && warn "$fail 个技能被跳过"
echo "提示：Kimi Work 的技能列表在会话启动时生成，需新开会话才能看到新增技能。"
