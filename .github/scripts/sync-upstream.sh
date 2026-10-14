#!/usr/bin/env bash
# 遍历 .upstream/upstreams.json，把各上游子树同步进 upstream/（含 LICENSE 落位）。
# 只负责落盘与报告变更；提交 / 开 PR 由调用方（GitHub Actions 工作流）决定。
# 本地也可直接跑：.github/scripts/sync-upstream.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 🌟 jq 不能放进程替换里：其失败会被子 shell 吞掉导致 CI 假绿。先取值再喂循环。
entries="$(jq -r 'to_entries[] | [.key, .value.repo, .value.branch, .value.subpath, .value.dest, (.value.license // "-")] | @tsv' .upstream/upstreams.json)"

failed=()
while IFS=$'\t' read -r id repo branch subpath dest license; do
  echo "==> sync ${id}: ${repo} (${branch}) ${subpath}/ -> ${dest}/"
  if ! git clone -q --depth 1 --branch "$branch" "$repo" "$tmp/$id"; then
    echo "error: clone ${repo} failed" >&2
    failed+=("$id")
    continue
  fi
  if [ ! -d "$tmp/$id/$subpath" ]; then
    echo "error: upstream ${repo} has no subpath ${subpath}" >&2
    failed+=("$id")
    continue
  fi
  mkdir -p "$dest"
  # 🌟 --exclude .git：subpath 为 "."（整仓 vendor，如 titanwings/distilly）时防止把克隆的 .git 带进本仓库
  rsync -a --delete --exclude .git "$tmp/$id/$subpath/" "$dest/"
  if [ "$license" != "-" ] && [ -f "$tmp/$id/LICENSE" ]; then
    mkdir -p "$(dirname "$license")"
    cp "$tmp/$id/LICENSE" "$license"
  fi
done <<< "$entries"

if ((${#failed[@]})); then
  echo "error: ${#failed[@]} upstream(s) failed: ${failed[*]}" >&2
  exit 1
fi

# 重建 APM 包的 symlink 视图（上游增删技能后 skills/ 链接需同步）
./scripts/gen-apm-links.sh

if git status --porcelain -- upstream/ skills/ | grep -q .; then
  echo "==> upstream changes:"
  git status --porcelain -- upstream/ skills/
else
  echo "==> upstream up to date"
fi
