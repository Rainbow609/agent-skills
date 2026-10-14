# 保护分支与 Upstream 策略

> **约定**：本文件中 `<主分支>` 指远端默认分支（`master` 或 `main`），以 `git remote show origin` 的 HEAD branch 为准，执行命令时替换为实际分支名。

## 保护分支清单

- **保护分支**：`master`、`main`、`release/*`、`hotfix/*`
- **默认行为**：当前分支为保护分支时，先询问基底（`origin/<主分支>` 或当前分支），再创建 `<type>/<功能简述>`（kebab-case）功能分支后提交
- **例外**：指令明确包含"在 master 上提交""直接提交到 master""不建分支直接提交"等白名单字眼时，方可在保护分支提交
- **模糊措辞不算例外**："不要修改分支名称""维持当前分支""就用现在的分支"等视为未指定，仍须创建功能分支

## 分支创建（强制）

**创建前先询问基底**——用交互提问工具（Claude Code 用 `AskUserQuestion`；VS Code 用 `vscode_askQuestions`）：

```
问题：功能分支 <type>/<功能简述> 以何处为基底？
选项：
1. `origin/<主分支>`（远程最新主分支）
2. 当前分支 <X>（本地现状，含本地未推送提交）
```

**使用 `git switch -c` 创建功能分支**（依所选基底择一）：

```bash
# 基底 = 主分支的远程跟踪分支：--no-track 必加，否则 upstream 会被自动设为主分支（推送陷阱）
git switch -c <type>/<功能简述> --no-track origin/<主分支>

# 基底 = 当前分支：不带起点，upstream 为空
git switch -c <type>/<功能简述>

# 提交后推送并设定正确 upstream（一步完成，两种基底皆同）
git push -u origin <type>/<功能简述>

# 验证 tracking 正确
git config --get branch.<type>/<功能简述>.merge
# 预期输出：refs/heads/<type>/<功能简述>（非 refs/heads/<主分支>）
```

> **为什么带 `origin/<主分支>` 起点时必须加 `--no-track`？**
> Git 的 `branch.autoSetupMerge` 默认为 `true`：只要起点是远程跟踪分支，无论 `git checkout -b` 或 `git switch -c` 都会自动将 upstream 设为该远程分支（实测 `git switch -c feat origin/main` 得到 `branch.feat.merge = refs/heads/main`），导致图形界面（GitKraken / GitHub Desktop 等）的 Push 按钮直接推送到主分支。`--no-track` 明确跳过此自动设定；不带起点的 `git switch -c` 起点是本地分支，不触发自动设定，故无需加。两种方式创建后都以 `git push -u` 一步完成推送与 tracking 设定。

> **工作区有未提交变更时**：`git switch` 会尝试带着变更切换；若基底与当前 HEAD 在这些文件上有差异则会拒绝，先 `git stash`、切换后 `git stash pop`。

## 分支命名验证

功能分支（非保护分支）必须符合 `<type>/<kebab-case 描述>` 格式。type 许可清单：`feat|fix|docs|refactor|chore|build|perf|test|style|ci|revert`。

```bash
branch_name=$(git branch --show-current)
echo "$branch_name" | grep -qE "^(feat|fix|docs|refactor|chore|build|perf|test|style|ci|revert)/[a-z0-9]+(-[a-z0-9]+)*$"
```

- **通过**：继续流程
- **不通过**：提示用户"当前分支名 `<X>` 不符合 `<type>/<描述>` 规范，建议改名或接受现状"，用户选择后继续
- **新建的功能分支**：已在保护分支侦测步骤中以规范格式创建，跳过此检查

## 分支健康度检查（格式验证通过后执行）

格式验证通过后，进一步检查分支的**语义健康度**——解决"忘了切回 master，旧功能分支上提交了不相关变更"的问题。三道检查依次执行，任一道命中即向用户报告，全部通过才放行。

### ① 已合并侦测（死分支）

分支已被合并至主分支时，在其上提交会产生孤立提交，增加后续 rebase/merge 的复杂度。

```bash
# 判断分支是否已合并至主分支
git merge-base --is-ancestor HEAD origin/<主分支>
# 如果上一行 exit code = 0 → 分支已合并（死分支）
```

- **已合并**：警告 `⚠️ 当前分支 <X> 已合并至主分支，是在死分支上提交。建议切回主分支重建新分支。`
- **未合并**：通过，继续下一道检查
- **跳过条件**：保护分支、新建的功能分支

### ② 落后侦测

分支落后主分支时，提交后 rebase 会产生额外冲突风险。

```bash
# 计算落后提交数
behind=$(git rev-list --count HEAD..origin/<主分支>)
```

- **落后 > 0**：警告 `⚠️ 当前分支 <X> 落后主分支 <N> 个提交，建议先 rebase 后再提交。`
- **落后 = 0**：通过，继续下一道检查

### ③ 变更类型一致性（软警告）

分支名 prefix 与待提交变更的建议类型不一致时，可能是建分支时的判断失误。

```bash
# 取得 branch prefix type
branch_type=$(echo "$branch_name" | cut -d'/' -f1)

# 分析待提交文件的建议 type（基于路径/内容推断）
# 与 branch_type 比对：若本批所有变更的建议 type 均 ≠ branch_type → 不一致
```

判定规则：
- **完全不一致**（本批所有变更的建议 type 都 ≠ branch prefix）：软警告 `⚠️ 分支名为 <type>/<desc>，但本批变更的建议提交类型为 <actual_type>，两者不一致。建议改名或接受现状。`
- **部分一致**（有匹配、有不匹配）：通过——允许 mixed types（开发中顺手修 bug 是正常节奏）
- **完全一致**：通过

> **判定"建议 type"的推断逻辑**：与步骤 2 的智能分组策略一致——按文件路径、变更性质（新增/修改/删除）推断每组变更的 type。此处不做精确分组，只需判断是否存在一致匹配。

### 输出模板

```text
【分支健康度】分支 <branch_name>
  ① 已合并至主分支（死分支）→ 建议切回主分支重建新分支
  ② 落后主分支 <N> 个提交 → 建议先 rebase
  ③ 变更类型 <branch_type> ≠ 提交类型 <actual_type> → 建议改名或接受现状
```

各项为 ✅ 时省略不显示，只列命中项。用户确认后继续流程。

## 推送前 Upstream 校验（强制）

提交完成后、推送前，**必须**校验当前分支的 upstream 指向：

```bash
# 获取当前分支名
currentBranch=$(git branch --show-current)

# 校验 upstream 指向
git config --get branch."$currentBranch".merge
```

**校验规则：**

| upstream 输出 | 判定 | 行动 |
|---------------|------|------|
| `refs/heads/<current_branch>` | ✅ 正确 | 允许推送 |
| `refs/heads/master` 或 `refs/heads/main` | ❌ 陷阱 | **阻止推送**，执行修正 |
| 无输出（未设定） | ⚠️ 警告 | 提示设定 upstream |
| `refs/heads/release/*` 或 `refs/heads/hotfix/*` | ❌ 陷阱 | **阻止推送**，执行修正 |

**修正命令（upstream 指向保护分支时）：**

```bash
# 远程分支已存在：直接修正 tracking
git branch --set-upstream-to=origin/"$currentBranch"

# 远程分支尚未创建：推送并设定 tracking（一步完成）
git push -u origin "$currentBranch"
```

**校验失败时的回报模板：**

```text
⚠️ upstream 陷阱侦测！
当前分支 <branch> 的 upstream 指向 <wrong_target>（非自身远程分支）。
直接推送会将代码送入保护分支。
已自动修正为 origin/<branch>，请确认后重新推送。
```

> **为什么需要此校验**：以远程跟踪分支为起点建分支时（`git checkout -b` 或 `git switch -c` 皆同），Git 会自动将 upstream 设为该远程分支，导致图形界面（GitKraken / GitHub Desktop 等）的 Push 按钮直接推送到保护分支。本技能以 `git switch -c` 不带起点、或带 `origin/<主分支>` 起点时必加 `--no-track` 从源头避免此问题，但此校验仍保留作为防御——分支可能由其他工具或手动创建。
