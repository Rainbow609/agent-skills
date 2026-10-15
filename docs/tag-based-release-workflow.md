# 打 tag 之后的开发与版本演进（tag 唯一版本源工作流）

> 适用前提：版本号不硬编码在源码里，而是由 **Git tag 在构建时注入**（如 manbo-reader 的
> `scripts/ci/sync-version.js` + GitHub Actions tag 触发）。核心问题：tag 之后怎么开发？
> 版本号在一开始定还是完成后定？

## 核心结论

1. **版本号在「发布时刻」由 tag 决定，不是在开发开始时定。** 开发期间 main 分支上没有任何
   版本承诺——GitHub Flow 的第一原则是「main 始终处于可发布状态」，发版时做的是
   「给当前 main 起一个版本号」，而不是「按预定版本号赶工」。
2. **tag 之后开发直接在 main 上继续（或从 main 切新 feature 分支），无需任何"解 tag"
   "版本复位"操作。** tag 是历史中指向某个 commit 的锚点，不锁分支、不阻断后续提交；
   下一个 tag 总是打在更新的 commit 上。
3. **更新日志在开发过程中累积、发布时定稿**（Keep a Changelog 的 `Unreleased` 段），
   与版本号同一时刻（发布时）落定。

## 时间线

```
tag v2.1.5 ◄────────────── main 历史锚点，不动
      │
      ▼  tag 之后立刻继续开发
main: ──feature PR──feature PR──fix PR── ……（期间日志在 Unreleased 累积）
      │
      ▼  决定发版（ main 已具备发布条件）
① 把 Unreleased 日志定稿为本版条目（versionName = 按 SemVer 选好的号）
② git tag v2.1.6 && git push origin v2.1.6
③ CI 由 tag 触发：注入版本号 → 构建 → 发布 Release
      │
      ▼  开发继续，循环往复
```

## 官方依据

| 结论 | 来源 |
|---|---|
| Release 基于 Git tag，tag 标记仓库历史中的一个特定点 | GitHub Docs《About releases》 |
| 创建 Release 时才选择/创建 tag 并指定目标分支——tag 是发布动作的产物，不是开发的起点 | GitHub Docs《Managing releases in a repository》 |
| main 始终保持可部署；feature 分支短生命周期，PR 合回 main | GitHub Flow（GitHub 官方指南） |
| MAJOR/MINOR/PATCH 递增规则（不兼容变更/新功能/修复）、预发布版本优先级低于正式版 | SemVer 2.0.0 规范第 6/7/8/9/11 条 |
| 日志维护：开发期用 `Unreleased` 段累积，发布时移动为新版本段；每个版本必须有条目；不要用 commit log 直接当更新日志 | Keep a Changelog 1.1.0 |

## 版本号何时确定——决策表

| 时机 | 动作 | 说明 |
|---|---|---|
| 开发开始 | **不定版本号** | 只做功能分支；改了公共行为才在评审时讨论"这算 minor 还是 major" |
| 开发中 | 只累积日志 | `web/data/release-notes.json`（或 CHANGELOG.md）维护 Unreleased 内容 |
| 发布时刻 | **tag 定版** | 看 main 自上一 tag 以来的增量，按 SemVer 选号：全是修复 → patch；有兼容新功能 → minor；有破坏性变更 → major |
| tag 已推送后发现错误 | **永不移动已发布 tag** | 修复内容走下一个 patch tag；移动/复用 tag 会破坏 immutable release 与产物缓存一致性 |

## tag 之后的日常开发操作

```bash
# tag 打完后，本地同步一下即可继续干活，没有任何额外步骤
git checkout main && git pull

# 新功能照旧从 main 切分支
git checkout -b feat/some-feature main
# ……开发、PR、合并……

# 期间累积更新日志（改 data/release-notes.json 的 Unreleased 内容或首条草稿）

# hotfix（线上紧急修复）：从 tag 切，修完合回 main，打新 patch tag
git checkout -b hotfix/crash-fix v2.1.6
# ……修复、PR 合回 main……
git tag v2.1.7 && git push origin v2.1.7
```

## 反模式（官方口径明确反对）

- **开发开始就 bump 版本号**——版本承诺过早，中途范围变化必然产生"文件里的版本 vs tag
  的版本"双写漂移；tag 唯一源体系下这步完全被 CI 取代。
- **移动或复用已发布的 tag**（如删了 `v2.1.6` 重打到别的 commit）——immutable release
  语义被破坏，已分发产物的来源无法追溯。
- **把 commit log 当更新日志**——Keep a Changelog 指出 commit 记录的是源码演化步骤，
  而日志条目是给用户看的跨 commit 显著差异，两者目的不同。
- **tag 带临时后缀当正式版用**（如 `v2.1.6-tmp`）——预发布应显式标 prerelease
  （SemVer 第 9 条：`-alpha`/`-beta`/`-rc` 优先级低于正式版，GitHub Release 有
  pre-release 开关），正式 tag 只接受纯 `X.Y.Z`。

## 参考

- GitHub Docs — About releases: <https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases>
- GitHub Docs — Managing releases in a repository: <https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository>
- GitHub Docs — Immutable releases: <https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases>
- GitHub Flow 指南: <https://guides.github.com/introduction/flow/>（现收录于 docs.github.com《GitHub flow》）
- SemVer 2.0.0 规范: <https://semver.org/>
- Keep a Changelog 1.1.0: <https://keepachangelog.com/en/1.1.0/>
