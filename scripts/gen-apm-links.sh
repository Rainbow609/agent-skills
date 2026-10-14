#!/usr/bin/env bash
# 生成 APM 包的 symlink 视图（供 apm install 全量分发）：
#   skills/            ← 根集合：自有 7 个为真实目录，其余 81 个技能以 symlink 指向 upstream/ 或 snapshot/
#   .apm/agents        ← 目录 symlink 指向 agents/universal（12 个 .agent.md）
# 🌟 APM 发现规则（实测 apm v0.33.0）：
#   ① 根 skills/ 存在时归类为 skill_bundle，只扫「直接子目录含 SKILL.md」一层（不递归、.apm/skills 被忽略）；
#   ② symlink 条目会被跟随，但仅限指向包内（仓库内）路径，跨包根会拒绝。
# 幂等：先清理 skills/ 下全部 symlink（只删链接，不碰真实目录），再重建；.apm/agents 同理。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# 清理上一轮的 symlink 条目（仅 -type l）
find skills -maxdepth 1 -type l -delete
rm -rf .apm/skills

# 收集非自有技能目录（upstream/ + snapshot/）
skill_dirs=()
while IFS= read -r d; do skill_dirs+=("$d"); done < <(find upstream snapshot -name SKILL.md -not -path '*/.git/*' -not -path '*/.tmp/*' -print 2>/dev/null | xargs -I{} dirname {} | sort)

linked=0
for d in "${skill_dirs[@]}"; do
  name="$(basename "$d")"
  if [ -e "skills/$name" ]; then
    echo "warning: name collision, skip: $name ($d)" >&2
    continue
  fi
  ln -s "../$d" "skills/$name"
  linked=$((linked + 1))
done

# 智能体：.apm/agents 目录 symlink（12 个 .agent.md）
mkdir -p .apm
rm -f .apm/agents
ln -s ../agents/universal .apm/agents

total=$(find skills -mindepth 1 -maxdepth 1 -type d -o -mindepth 1 -maxdepth 1 -type l | wc -l | tr -d ' ')
echo "apm view: skills 共 ${total} 项（新增链接 ${linked}），agents -> .apm/agents"
