---
name: git-pr-description
description: PR 描述生成器＋PR 自动创建器。触发时机：请求生成 PR 描述、描述未合并提交、创建 Pull Request 说明、PR 前比对分支差异生成 What/Why/How 摘要、要求创建 PR。侦测到 gh CLI 已安装且完成认证时，直接创建 PR 并返回网址，而非只输出描述。
---

# PR 描述生成器（侦测到 gh 时直接创建 PR）

## When to Activate

- 用户请求生成 PR 描述
- 准备发起 Pull Request 前需要整理变更说明
- 需要比较当前分支与目标分支的差异并生成摘要
- 用户要求创建 PR，而变更已提交

> 核心心法：描述的任务是把 reviewer 本来得从 diff 反推的意图，由最了解变更的作者一次写清楚——What / Why / How / 验证方式。
>
> 交付心法：**描述不是终点，PR 才是**。侦测到 `gh` 已安装并完成认证时，直接建好 PR 并返回网址；环境不具备时才退回输出描述文字。

---

## 约定

**主分支** = 远端默认分支（`master` 或 `main`），以 `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`（gh 可用时）或 `git remote show origin` 的 HEAD branch 为准；本文以 `<主分支>` 指代，执行时替换为实际分支名。

---

## PR 前提交整理

在生成 PR 描述之前，确保提交历史已整理完毕：

### 检查清单

- [ ] 所有变更已按功能模块分组提交（使用 `/git-commit` 技能）
- [ ] 提交信息遵循简体中文 Conventional Commits 规范
- [ ] 无"WIP""更新""修复"等含糊提交信息
- [ ] 相关的测试变更已与功能变更一起提交或独立提交
- [ ] 无不应提交的文件（如 `.env`、暂存文件）
- [ ] 分支已推送到 `origin`，且远程 tip 与本地 HEAD 一致（模式 A 自动创建 PR 的前提）

### 整理命令参考

```bash
# 查看当前分支与主分支的提交差异
git log origin/<主分支>..HEAD --oneline

# 若提交历史杂乱，建议使用 git-commit 技能重新分组整理
# 或手动交互式 rebase（终端直接执行）
git rebase -i origin/<主分支>
```

> **注意**：PR 描述生成器只负责"描述已存在的提交"，不负责整理提交历史。提交整理请使用 `/git-commit` 技能。

---

## 工作流程

### 1. 侦测分支信息

```bash
# 获取当前分支
currentBranch=$(git branch --show-current)

# 主分支 = 远端默认分支（见"约定"）
gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null \
  || git remote show origin | sed -n 's/.*HEAD branch: //p'
```

- 当前分支就是主分支时没有 PR 可建（来源＝目标）→ 显示提示并终止，不要落入通用的"创建失败"路径
- 远端默认分支无法判定或用户明确指定其他目标时，才经交互提问工具确认

### 2. 取得提交差异

```bash
# 提交列表（简要）
git log origin/<主分支>..HEAD --oneline

# 变更统计
git diff origin/<主分支>...HEAD --stat

# 详细变更内容（针对关键文件，用于分析）
git diff origin/<主分支>...HEAD -- {文件路径}
```

### 3. 分析变更内容

根据提交信息分类：
- **feat**: 新功能
- **fix**: 错误修复
- **refactor**: 重构
- **chore**: 维护/清理
- **docs**: 文档变更
- **perf**: 性能优化

分析要点：
- 相同主题的提交合并为同一分类描述
- 从 diff 识别**破坏性变更**（删除文件、接口签名变更、schema 变动）——需在描述中显著标注
- 记录测试相关变更（新增/更新的测试文件），供"验证方式"区段引用

### 4. 决定交付方式（默认自动创建 PR）

```bash
# gh 是否安装
command -v gh

# gh 是否已认证（输出需见 github.com 的 ✓ Logged in）
gh auth status
```

| 环境 | 交付方式 |
|------|----------|
| `gh` 已安装，且已认证 | **模式 A：直接创建 PR**（见"模式 A"节） |
| 未安装 `gh`，或未认证 | **模式 B：输出完整描述**，由用户自行贴上 |

- 模式 A 是本技能侦测到可用环境后的**默认行为**——直接建好 PR 并返回网址，不要停在"这是描述，要我帮你建 PR 吗？"
- 只有用户明示"只要描述""我自己贴"时才改走模式 B
- 两种模式产出的描述内容完全相同，差别只在交付方式

---

## 完整输出模板

`````markdown
# 合并分支：{source_branch} → {target_branch}

## 标题 (Title)
`type(scope): 简要描述（简体中文，控制在 72 字以内）`

标题示例：
- `feat(olap_connector): 新增异步重试装饰器并完善错误防御机制`
- `fix(api): 修复异步执行器误用同步装饰器的问题`
- `refactor(retry): 提取公共重试逻辑消除同步异步代码重复`

## What
{简洁说明本次 PR 做了什么，用具体文件名或模块名，1-2 句话即可。}

## Why
{说明变更的动机与上下文：解决了什么问题、为何需要这个变更、不做的影响是什么。}

## How

1. **{变更项目名称（建议用函数名或模块名）}**：
   * {具体做了什么，用主谓宾结构}
   * {关键技术细节或实现方式}
   * {边界条件或防御性处理}
   * {安全性、幂等性或数据一致性考量}

2. **{变更项目名称}**：
   * {具体变更内容}
   * {集成点或调用路径}
   * {时序或依赖关系说明}

## 验证方式 (Testing)

{说明如何验证本变更：已执行的测试命令与结果、reviewer 可自行重现的步骤、需人工检查的边界情境。微小变更可一句话带过，不可整段省略。}

## 破坏性变更 (Breaking Changes)

{仅在存在破坏性变更时保留此区段：列出受影响的接口/行为、迁移方式与受影响的调用方。无破坏性变更时整段移除。}

## 相关提交 (Related Commits)

- `{sha} {type}({scope}): {subject}`
- `{sha} {type}({scope}): {subject}`
`````

---

## 模式 A：自动创建 PR（侦测到 gh）

交付物是 **PR 网址**，不是待贴上的文字。描述内容仍写入 `.tmp/pr_description_<branch>.md` 留存（写入前须确认 `.tmp/` 已被 `.gitignore` 忽略，见"执行顺序"后的说明），作为副产物与留证。

执行前，命令必须**先写出、再执行**（不是执行后补述），写出内容含将执行的命令与"来源分支 → 目标分支"，让用户当下就能看见代理对远程做了什么；用户若在请求中表明"先别建 PR""只要描述"，一律走模式 B；用户在看到命令后要求停止时立即中止并改走模式 B，已创建的 PR 是否关闭交由用户决定。

### 执行顺序

```bash
# 1) 来源分支是否已在远程，且远程 tip 等于本地 HEAD
#    无输出 = 未推送；SHA 与 git rev-parse HEAD 不符 = 本地还有未推提交
#    两种情况都走"交互式选择"的未推送提问，不可直接创建（否则 PR 内容与描述不符）
git ls-remote --heads origin <source_branch>
git rev-parse HEAD

# 2) 是否已有 open PR（--state all 会列出已合并/已关闭，仅 open 状态阻挡创建）
gh pr list --head <source_branch> --state open --json number,url

# 3) 创建 PR——--title 与 --body-file 带齐后 gh 不进交互提示，缺任意一个会停在等待输入
#    --title 的角括号是占位符，必须换成实际标题，不可照抄
gh pr create --head <source_branch> --base <主分支> --title "<type>(<scope>): <简要描述>" --body-file .tmp/pr_description_<branch>.md

# 4) 取回结果（网址、编号、标题、来源→目标）
gh pr view <source_branch> --json number,url,title,baseRefName,headRefName
```

描述文件内容即"完整输出模板"的成品，但**不含**外层包裹的 5 个反引号。

文件名中的 `/` 以 `-` 取代——分支名含斜线（如 `docs/webui-x` → `.tmp/pr_description_docs-webui-x.md`），照抄分支名会让 `gh` 找不到文件。`.tmp/` 目录不存在时（fresh clone、新建 worktree）先创建再写文件。写入前以 `git check-ignore -q .tmp/` 确认已被忽略：退出码非 0（未忽略）时向仓库根 `.gitignore` 追加一行 `.tmp/` 再写文件，防止描述文件被误提交。

### 参数惯例

| 参数 | 用法 |
|------|------|
| `--base <主分支>` | 目标分支；省略时 `gh` 自动用仓库默认分支，仅在用户明确要求其他目标时显式指定 |
| `--draft` | 仅在用户明示草稿时加 |
| `--body-file` | 指向 `.tmp/pr_description_<branch>.md`；`-` 可从 stdin 读 |
| `--fill` | **一律不用**：它会用提交信息自动拼标题和描述，绕过本技能的 What/Why/How 结构与人工把关 |

> 合并后是否删除来源分支由 GitHub 仓库设置（Automatically delete head branches）或合并时的 `gh pr merge --delete-branch` 决定，创建 PR 阶段无对应参数，无需处理。

### 边界与禁止事项

- **已有 open PR → 不重复创建**：回报既有 PR 网址；标题或描述需更新时用 `gh pr edit <编号> -y --title "<新标题>" --body-file .tmp/pr_description_<branch>.md`（`gh pr create` 不会更新已存在的 PR，这是已知行为，必须先查重）
- **已 merged／已 closed 的旧 PR 不阻挡创建**：同一分支名可能来自上一个已并的 PR，只有 `open` 状态才算"已存在"
  （`--state` 的合法取值是 `open|closed|merged|all`；写成早期文档里的 `opened` 会被 gh 直接拒绝：`invalid argument "opened"`）
- 创建成功后**只回报**：不自动 `gh pr merge`、不自动关闭 PR、不自动改写提交历史
- 来源分支未推送、或远程 tip 落后本地时，**不得默默推送**——推送属写入操作，需先走"交互式选择"取得用户同意
- 创建失败（403 权限不足、host 不可达、参数错误）→ 显示原始错误，**退回模式 B** 输出完整描述，不盲目重试超过一次
- `gh` 认证的是 GitHub Enterprise 主机而 origin 是 github.com（或反之）→ 走模式 B，不得改用其他远程创建

---

## 输出原则

### 包裹规则
- 模式 B 向用户展示描述时，必须以 **5 个反引号**（`````）包裹整个 PR 描述，确保 markdown 语法不被渲染
- 模式 A 的 `.tmp/pr_description_<branch>.md` 内容**不含**外层包裹反引号（PR 描述直接是 markdown）

### 标题格式
- 严格遵循 **Conventional Commits** 规范
- 格式：`` `type(scope): 简要描述` ``（用反引号包裹）
- `type` 限定为：`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `perf`, `ci`, `revert`
- 含破坏性变更时 type 后加 `!`（如 `refactor!(api)`），与提交信息规范一致
- `scope` 为受影响的模块或组件名称
- 描述使用**祈使句**，不加大写开头与句点，控制在 72 字以内
- **必须使用简体中文**

### 内容结构（What / Why / How / 验证）
- **What**：1-2 句话说明"做了什么"，用具体文件名或模块名，不空泛
- **Why**：说明动机与上下文，解释"为何需要这个变更"与"不做的影响"——reviewer 最需要而作者最常漏掉的部分
- **How**：用数字列表列具体变更，每个项目以关键函数或模块名开头，子项用 bullet points 说明具体行为、关键技术细节、边界处理；可加一句"建议重点审查 {文件}"引导 reviewer 把精力放在高风险处
- **验证方式**：写下测试命令与重现步骤，把 reviewer 的验证成本降为照做即可
- **破坏性变更**：存在时显著标注并附迁移指引，不得只写在 commit footer
- **语言统一**：简体中文撰写，技术术语保留英文
- **可直接复制**：输出完整的 markdown，无需用户再格式化
- **避免冗余表格**：不输出"变更统计"、"涉及文件"等表格，保持简洁

---

## 交互式选择

### 目标分支确认

仅在远端默认分支无法判定或用户明确要求其他目标时，才经环境交互提问工具（Claude Code 用 `AskUserQuestion`；VS Code 用 `vscode_askQuestions`）询问：

```
问题：目标分支为何？（默认取远端默认分支）
选项：
1. 远端默认分支（推荐）
2. 其他：手动输入分支名
```

### 来源分支未推送、或远程 tip 落后时

```bash
# 无输出 = 尚未推送到 origin；SHA 与 git rev-parse HEAD 不符 = 本地还有未推提交
git ls-remote --heads origin <source_branch>
git rev-parse HEAD
```

两种情况都以交互提问工具询问（推送是写入操作，需用户同意）：

```
问题：分支 <branch> 的远程 tip 与本地 HEAD 不一致（尚未推送，或本地还有未推提交），如何处理？
选项：
1. 推送并创建 PR（先 git push -u origin <branch> 补上提交，再创建 PR）
2. 只输出描述，我自己处理推送
```

### 输出格式

- 模式 A：回报 PR 网址、编号、标题、`来源分支 → 目标分支`
- 模式 B：一律输出**完整格式**；变更极小时可自行缩减 How 的条目数，但 What / Why / 验证方式不可省略

---

## 错误处理

| 情境 | 处理方式 |
|------|----------|
| 非 Git 仓库 | 显示：`❌ 当前目录不是 Git 仓库`，终止流程 |
| 无法判定目标分支 | 显示：`❌ 找不到默认分支`，询问用户指定目标分支 |
| 无提交差异 | 显示：`ℹ️ 目前分支与目标分支没有提交差异`，终止流程 |
| 当前分支是主分支 | 显示：`❌ 当前在主分支上，没有可创建的 PR`，终止流程 |
| 提交历史杂乱 | 提示用户先使用 `/git-commit` 技能整理提交历史 |
| 取得差异失败 | 显示：`⚠️ 取得提交差异失败：{error}`，询问：重试 / 终止 |
| 生成失败 | 显示：`❌ PR 描述生成失败：{error}`，保留中断结果供调查 |
| `gh` 未安装 | 走模式 B 输出描述，结尾附一句：安装 `gh`（`brew install gh`）并 `gh auth login` 后可直接创建 PR |
| `gh` 未认证 | 提示 `gh auth login`；本次走模式 B，不中断流程 |
| 来源分支未推送、或远程 tip 落后 | 交互提问：推送并创建 / 只输出描述（见"交互式选择"） |
| 该分支已有 open PR | 不重复创建，回报既有 PR 网址；需要时以 `gh pr edit` 更新标题或描述 |
| PR 创建失败 | 显示原始错误 → 退回模式 B 输出完整描述；不盲目重试 |

---

## 与其他技能的协作

- **提交整理**：生成 PR 描述前，请先使用 `/git-commit` 技能整理提交历史
- **代码审查**：PR 创建后的审查流程请使用 `/code-review` 技能
- **PR 生命周期**：本技能只负责"创建"，合并、关闭、标签与里程碑调整交由用户决定
