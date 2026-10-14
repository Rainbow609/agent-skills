# 提交历史重整与恢复

## 提交历史重整（rebase 路线）

**触发条件**：本地已累积多个杂乱提交（WIP、混组、顺序错误），需要整理为原子提交。工作区尚有未提交变更时，先走主路线提交或 `git stash`，再重整历史。暂存与 rebase 是互补工具：未提交变更以暂存区逐组雕琢（主路线），已提交历史以 rebase 重整（本路线）。

### 守门（强制）

- 只重写**未推送**的提交：以 `git branch -r --contains <hash>` 判定——任何远程分支已包含即为已推送
- 已推送到个人功能分支：须经用户确认，重整后以 `git push --force-with-lease` 更新（禁用 `--force`）
- 已存在于共享或保护分支：❌ 中止——已推送历史不重写，改建议 `git revert`

### 手段选择

| 目标 | 手段 |
|------|------|
| 合并相邻同质提交 | `git rebase -i <base>`，标 `squash` / `fixup` |
| 调整提交顺序 | `git rebase -i <base>` 调换行序（有冲突风险，先向用户说明依赖） |
| 一个提交含多个逻辑 | `git rebase -i <base>` 标 `edit` → `git reset HEAD^` → 回到"智能分组策略"逐组重新提交 |
| 修补最新提交 | `git commit --amend` |
| 事后修正并入较早提交 | `git commit --fixup <hash>` + `git rebase -i --autosquash <base>` |

### 约束与执行

- **禁止把整条分支 squash 成单一大提交作为常态**——合并后的提交无法单独 revert 或被引用，违背原子性初衷；squash 仅用于清理意外或噪音提交（WIP、`fix typo` 之类）
- 逻辑顺序：被依赖的变更（重命名、接口调整）在前，依赖方在后（同"提交顺序规范"）
- 执行前展示**重整规划**（提交序列前后对照）经用户确认；`edit` 停点可跑测试，验证每个提交点皆可运作
- 冲突：hunk 解法（找意图、保双方、不发明新行为）遵循 `resolving-merge-conflicts` 技能；解决后 `git add` + `git rebase --continue`；规划不可行时 `git rebase --abort` 回原状；意外搞砸以 `git reflog` 找重整前 HEAD，`git reset --hard <hash>` 兜底
- 完成后重跑"推送前 upstream 校验"与"推送确认"

---

## 冲突与错误处理

| 情境 | 处理方式 |
|------|----------|
| 非 Git 仓库 | 显示：`❌ 当前目录不是 Git 仓库`，终止流程 |
| 无变更可提交 | 显示：`ℹ️ 工作区干净，无需提交` |
| 提交信息为英文 | 显示：`⚠️ 提交信息必须使用简体中文`，要求重新输入 |
| Pre-commit hook 失败 | 显示：`⚠️ Hook 失败：{error}`，选项：修复后重试 / 跳过（--no-verify）/ 取消 |
| 提交冲突 | 显示：`⚠️ 提交发生冲突`，选项：手动解决后继续 / 取消 |
| 用户取消 | 显示：`⚠️ 已取消`，保留所有变更 |
| Rebase 冲突／中断 | 解决后 `git add` + `git rebase --continue`；放弃重整以 `git rebase --abort` 回原状 |

---

## 反模式

```
# BAD: 直接提交所有变更为一个大提交
git add .
git commit -m "更新"

# GOOD: 按功能分组提交
git add core_eol/eol_dd_dss_stationb.py
git commit -m "feat(stationb): 新增 AVL 模型分批处理逻辑"
git add tests/test_stationb.py
git commit -m "test(stationb): 新增分批处理单元测试"

# BAD: 使用英文提交信息
git commit -m "fix bug"

# GOOD: 使用简体中文
git commit -m "fix(scheduler): 修复 APScheduler 启动时任务过滤逻辑错误"

# BAD: 提交信息过于笼统
git commit -m "修改了一些东西"

# GOOD: 具体说明变更内容
git commit -m "refactor(database): 提取连接池至独立模块"

# BAD: 将不相关变更合并为一个提交
git add .
git commit -m "feat+fix+docs: 多种变更"

# GOOD: 分开提交，每个聚焦单一目的

# BAD: 纯重构与行为变更混入同一提交（reviewer 无法区分风险）
git commit -m "refactor(auth): 清理代码顺便修复 session 问题"

# GOOD: 机械性重构独立提交并注明无行为变更
git commit -m "refactor(auth): 提取连接池至独立模块（无行为变更）"

# BAD: 合并前把整条分支 squash 成一个大提交（历史无法单独 revert）
# GOOD: 原子提交直接进 PR，squash 仅用于清理 WIP／噪音提交

# BAD: 重写已推送的共享分支历史（force push 破坏协作者）
# GOOD: 只重整未推送提交；个人分支须 --force-with-lease 并经用户确认
```

---

## Quick Reference

| 任务 | 命令 |
|------|------|
| 创建功能分支（基底 = 当前分支） | `git switch -c <type>/<功能简述>` |
| 创建功能分支（基底 = origin/主分支） | `git switch -c <type>/<功能简述> --no-track origin/<主分支>` |
| 查看工作区状态 | `git status --short` |
| 查看已暂存变更 | `git diff --cached --stat` |
| 核对暂存内容明细 | `git diff --cached` |
| 按文件类型查看变更 | `git status --porcelain` |
| 交互式选块暂存（同文件多逻辑拆分） | `git add -p {path}` |
| 暂存特定文件 | `git add {path}` |
| 提交（简体中文信息） | `git commit -m "type(scope): 描述"` |
| 多行信息提交 | 引号内直接换行的多行 `-m`，或写入 msg.txt 后 `git commit -F msg.txt` |
| 提交后核对单一提交 | `git log -1 --stat` |
| 修改最后一次提交 | `git commit --amend --no-edit` |
| 修改最后一次提交信息 | `git commit --amend -m "新信息"` |
| 取消暂存 | `git reset HEAD -- {path}` |
| 查看提交历史 | `git log --oneline -n 10` |
| 扫描可用远程 | `git remote` |
| 推送并设定 upstream | `git push -u <remote> <branch>` |
| 交互式重整提交历史 | `git rebase -i <base>` |
| 检查提交是否已推送 | `git branch -r --contains <hash>` |
| 于 edit 停点拆分提交 | `git reset HEAD^` 后逐组重新暂存提交 |
| 事后修正并入较早提交 | `git commit --fixup <hash>` → `git rebase -i --autosquash <base>` |
| 中止重整（回原状） | `git rebase --abort` |
| 重整搞砸兜底 | `git reflog` → `git reset --hard <hash>` |

---

## 场景化补救（undo 处方）

| 情境 | 补救 |
|------|------|
| 最后一组提交信息打错 | `git commit --amend -m "新信息"` |
| 最后一组漏了文件 | `git add <path>` → `git commit --amend --no-edit` |
| 最后一组分组错误，想重新分 | `git reset HEAD~1`（变更回工作区）→ 重走分组流程 |
| 中间某组有问题、其后已有提交 | `git rebase -i <base>` 标 `edit` → 修正 → `--amend` → `--continue` |
| 事后漏改要并入较早提交 | `git commit --fixup <hash>` + `git rebase -i --autosquash <base>` |
| 已推送的提交需要撤销 | `git revert <hash>`（不改写历史）→ 推送 |
| 误提交 secrets | 未推送：重整历史剔除该文件；已推送：视同泄露，先轮换密钥再清理历史 |
| 误暂存不想提交的文件 | `git restore --staged <path>` |
| 工作区改错且未提交 | `git restore <path>`（不可逆，先确认无保留价值） |
