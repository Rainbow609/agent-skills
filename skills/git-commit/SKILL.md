---
name: git-commit
description: 智能 Git 分组提交管理。触发时机：多个未暂存变更需要分组提交、多个杂乱 WIP 提交需要整理为原子提交、需要生成简体中文结构化提交信息、PR 前整理本地提交、需要保护分支守门（避免直接在 master/main 上提交）、提交前需要代码审查闸门。
---

# Git 分组提交管理器

## When to Activate

- 存在多个未暂存变更需要按功能模块分组提交
- 需要按照简体中文规范生成结构化提交信息
- 需要将杂乱变更整理为清晰、可追溯的提交历史
- 准备 Pull Request 前需要整理本地提交
- 已累积多个杂乱的本地提交，需要重整为原子提交（rebase 路线）
- 需要保护分支守门（避免直接在 master/main 上提交）
- 提交前需要代码审查闸门（审查代理 P0 归零才放行提交）

---

## 核心原则：Atomic Commits

每个提交应代表**单一、完整、可独立运作的变更**：

- **单一职责**：一个提交只做一件事，便于追踪、回退与审查
- **自包含可运作**：每个提交后项目仍可构建、测试通过，不留下损坏的中间态
- **可独立套用**：任何提交都能单独 cherry-pick 或 revert，不影响其他功能
- **信息交代缘由**：标题说明做了什么，正文说明为什么——动机与权衡才是日后搜索的重点
- **避免过度拆分**：相关联的变更（如同一功能的实现与测试）应合并为一个原子提交

> 参考：[Atomic Commits - Aleksandr Hovhannisyan](https://www.aleksandrhovhannisyan.com/blog/atomic-git-commits/)

---

## 提交信息规范

提交信息格式、类型对照表、Good/Bad 示例、grep 格式验证与语义检查清单，见 `references/commit-message-format.md`。

---

## 保护分支策略

保护分支清单、分支创建流程、`--no-track` 原理、分支命名验证、upstream 校验规则，见 `references/branch-strategy.md`。

---

## 提交前同步（强制）

功能分支提交前必须确保其建立在最新主分支之上。**主分支** = 远端默认分支（`master` 或 `main`），以 `git remote show origin` 的 HEAD branch 或 `gh repo view --json defaultBranchRef` 为准，下称 `<主分支>`：

1. `git fetch origin <主分支>`
2. 检查落后数：`git rev-list --count HEAD..origin/<主分支>`
3. 落后时执行 `git rebase --autostash origin/<主分支>`
4. 保护分支跳过 rebase（无法 rebase 至自身）
5. 已推送共享分支且落后时，中止并建议手动 rebase
6. 基底选择与同步独立：以当前分支为基底时，其相对主分支的领先提交会被功能分支继承（rebase 只补齐落后部分，不会移除继承的提交）

---

## 智能分组策略

### 分组维度

| 分组维度 | 说明 | 优先级 |
|----------|------|--------|
| **变更类型** | 按文件变更性质分组（feat/fix/refactor/chore/docs/perf） | 高 |
| **功能模块** | 按文件路径前缀分组（如 `database/`、`core_eol/`） | 高 |
| **测试关联** | 测试文件自动归并至对应功能模块组 | 中 |
| **文件变更类型** | 新增/修改/删除分类标记（识别 BREAKING CHANGE） | 中 |

### 分组逻辑

1. **相同类型 + 相同模块** → 合并为一组
2. **不同类型** → 按类型分开提交
3. **测试与源码同时变更** → 归入同一功能组
4. **单一文件被多类型修改** → 保持分开并提示用户选择
5. **BREAKING CHANGE**（删除文件或破坏性修改）→ 独立标记并在信息中注明

特殊规则：
- `docs/` 变更 → 可合并至关联功能组或独立提交
- `chore/` 变更 → 可合并至其他组或独立提交
- `style/` 变更 → 建议合并至同一文件的逻辑变更组

---

## 提交顺序规范（强制）

```
build > chore > refactor > fix > feat > test > docs
```

**规则：**
1. 不同 type **严格分离**，一个提交只含一种类型
2. 测试文件一律独立为 `test` 组，不并入 `feat`/`fix` 组
3. `pyproject.toml` 与 `uv.lock` 必须同组提交（`chore(deps)`），不可拆分
4. 同一逻辑变更跨多文件时合并为单一提交，禁止按 scope 切散
5. BREAKING CHANGE 独立成组，type 加 `!` 标记（如 `feat!`），footer 加 `BREAKING CHANGE: <描述>`

---

## 交互式提交流程

### 步骤 0：openspec 工作流侦测

```bash
openspec list --json 2>/dev/null
```

命令失败（openspec 未安装或无 `openspec/` 目录）→ 跳过此检查。侦测到活跃变更时，读取 `references/openspec-integration.md`：依完成度判定表找出"已完成"的变更，按提示模板询问用户是否先归档（`/opsx-archive`），再继续正常流程。

### 步骤 1：扫描变更

> 工作区干净且用户意在整理既有提交历史时，改走"提交历史重整（rebase 路线）"→ 见 `references/rebase-and-recovery.md`。

```bash
git status --short
git diff --cached --stat
git status --porcelain
```

### 步骤 2：分析分组

根据"智能分组策略"分析变更，向用户展示：
- 分组名称与建议 type/scope
- 涉及文件清单（按新增/修改/删除分类）
- 变更行数统计（+新增 / -删除）
- 建议的简体中文提交信息草稿

多组变更时，先展示**整体提交序列规划**（依提交顺序规范排列）经用户确认后，再逐组执行。

### 步骤 3：确认提交信息

使用交互提问工具（Claude Code 用 `AskUserQuestion`；VS Code 用 `vscode_askQuestions`）逐组询问：

```
问题：如何处理"{分组名称}"分组？（{K} 个文件，+{A}/-{B} 行）
选项：
1. 提交此分组（使用建议信息）
2. 修改提交信息后提交
3. 暂跳过此分组
4. 与其他分组合并
```

### 步骤 4：提交前审查闸门（强制）

分组确认后、执行任何 `git add` 前，对本次待提交变更做一次质量审查：

- **审查范围**：本会话要提交的全部分组（当前工作区 diff），一次审查，不逐组重复
- **审查方式**：由主代理做一次快速质量走查（逐文件读 diff：逻辑正确性、边界条件、遗漏的调用方/测试、敏感信息）；宿主提供审查子智能体时优先派发
- **P0 发现**：修复后复审，**P0 归零才放行**；两轮后仍有 P0 → 呈报用户决策
- **P1/P2 发现**：呈报用户选择：当场修复 / 带病提交 / 跳过
- **`/ponytail-review`（按需）**：用户要求，或本批变更新增大量抽象层／新依赖时加调一次

**跳过条件（命中其一即跳过）：**
- 用户指令明确要求跳过审查（"不用审查""直接提交"等）
- 本批变更仅 docs／注释／纯配置，无代码逻辑

### 步骤 5：分支自检

每组 `git add` 前执行：

#### 5a. 保护分支侦测

```text
【分支自检】当前分支 <X>｜是否保护分支：是/否｜指令含白名单允许字眼：是/否｜行动：<询问基底后创建功能分支 / 中止并报告 / 直接提交>
```

完整分支策略见 `references/branch-strategy.md`。

#### 5b. 分支命名验证 + 健康度检查

```bash
branch_name=$(git branch --show-current)
echo "$branch_name" | grep -qE "^(feat|fix|docs|refactor|chore|build|perf|test|style|ci|revert)/[a-z0-9]+(-[a-z0-9]+)*$"
```

不通过时提示用户"当前分支名 `<X>` 不符合 `<type>/<描述>` 规范，建议改名或接受现状"。新建的功能分支跳过此检查。

格式通过后，执行"分支健康度检查"——侦测已合并死分支、落后 master、变更类型与分支名不一致。详细规则见 `references/branch-strategy.md`"分支健康度检查"段落。

### 步骤 6：执行提交

```bash
# 按分组添加文件（明确列出路径，禁止 git add . / git add -A）
git add {分组涉及的文件}

# 提交前核对暂存内容与分组一致
git diff --cached --stat

# 提交信息格式验证（格式规范见 references/commit-message-format.md）
echo "{type}({scope}): {简体中文描述}" | grep -qE "^(feat|fix|docs|refactor|chore|build|perf|test|style|ci|revert)(\([a-z0-9_-]+\))?!?: .{1,50}$"

# 执行提交
git commit -m "{type}({scope}): {简体中文描述}"

# 提交后验证
git log -1 --stat
git status --short
```

- **多段落信息或含 `*`、引号等特殊字符**：bash/zsh 下正确加引号的 `git commit -m "多行消息"` 可安全使用——引号内的 `*` 不做 glob 展开，未加引号时 zsh 直接报 nomatch 错误而非静默展开，无 PowerShell 式陷阱。消息特别长或转义复杂时，写暂存文件后 `git commit -F` 更省心，事后删除暂存文件
- **重构与行为变更严禁混组**（cardinal rule）：纯机械性改名、搬移、格式化独立成 `refactor` 组并在信息中注明"无行为变更"
- 暂存区残留非本组的变更时保留不动，以明确路径 `git add` 只纳入本组文件
- 提交签名：检查 `git config --get commit.gpgsign`，已启用时带 `-S`

### 步骤 7：推送前 upstream 校验（强制）

提交完成后、推送前，**必须**校验当前分支的 upstream 指向。校验规则与修正命令见 `references/branch-strategy.md`"推送前 Upstream 校验"段落。

### 步骤 8：推送确认（询问）

提交完成后，先扫描可用远程，再用交互提问工具询问用户：

```bash
git remote
```

```
问题：是否推送当前分支 <branch> 到远程？
选项（依 git remote 扫描结果动态生成，origin 列首位）：
1. 推送到 origin（默认）
2. 推送到 <其他 remote>
3. 暂不推送（保留本地提交）
```

**规则：**
- 远程选项一律由 `git remote` 扫描结果动态生成，不硬编码
- 推送到 origin 以外的远程时，upstream 同样通过 `push -u` 指向该远程
- 用户选择"暂不推送"时保留本地提交
- 推送成功且远程返回 PR 创建链接时，输出链接供用户点击
- 推送失败时显示错误并询问：重试 / 更换远程 / 保留本地提交

### 步骤 9：PR 描述生成（询问）

推送完成后，用交互提问工具询问用户是否需要生成 PR 描述。确认后调用 `/git-pr-description` 技能。

- 仅在分支已有提交差异时才询问（`git log origin/<主分支>..HEAD` 无输出时跳过）
- 此步骤为非强制——用户可稍后手动调用 `/git-pr-description`

---

## 提交历史重整（rebase 路线）

完整的 rebase 流程、守门规则、手段选择、冲突处理、反模式、Quick Reference 与 undo 处方，见 `references/rebase-and-recovery.md`。

---

## 与其他技能的协作

- **openspec 归档**：提交时侦测活跃 openspec 变更，提示用户先以 `/opsx-archive` 归档已完成的 change
- **冲突解决**：提交或 rebase 过程遇到合并冲突时，hunk 解法（找意图、保双方、不发明新行为）遵循 `/resolving-merge-conflicts` 技能；rebase 机械操作见 `references/rebase-and-recovery.md`
- **PR 描述生成**：整理完提交后，使用 `/git-pr-description` 生成 Pull Request 描述
- **提交前审查**：由本技能"步骤 4 提交前审查闸门"执行——主代理快速走查，宿主支持时派发审查子智能体，按需加调 `/ponytail-review`
- **提交后正式审查**：对照 issue 的 Standards+Spec 双轴审查使用 `/code-review` 技能
