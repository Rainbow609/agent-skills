# Git 常用知识：vendor / workflow / worktree

> 适用前提：单人开发者 + 多 AI agent 并行改码的日常场景，需要用 git 硬机制解决的几类问题——
> 怎么把外部代码引进仓库、分支与协作流程怎么定、怎么同时开多条分支不互相踩。
> 引用约定：引用块内的英文为官方文档**逐字原文**，行内标注来源；`文件:行号` 指本仓库。
> 本文只写「有官方依据 + 本仓库已在用」的部分，不给通用教程复述。

## 核心结论

1. **git 原生只有两条引外部代码的路**：submodule（只存指针）与 subtree（把上游历史合进来）；
   「直接拷贝目录 + 同步脚本」是约定不是机制（git 手册里没有它），包管理器依赖则要求上游有分发渠道。
   本仓库选了第三种（见 §1.5），理由是可裁剪上游子目录 + 下游 clone 即得文件。
2. **分支模型是选择题不是宗教题**：默认 GitHub Flow；要 CI/CD 纪律就上 trunk-based（短生命周期分支 + feature flag）；
   只有「同时维护多个线上版本」才值得 Git Flow——作者本人 2020 年补记建议持续交付的 Web 应用改用 GitHub Flow。
3. **合并语义记三句**：`--ff` 能快进就快进、`--no-ff` 永远造 merge commit、`--ff-only` 不能快进就报错退出。
   本地收口用 `--ff-only`（确认没被别人合过），要把分支边界固化进历史用 `--no-ff`。
4. **rebase 铁律**：可以 rebase 未推送的本地提交与独占的 feature 分支；**任何已共享的历史都不能 rebase**。
   推送用 `--force-with-lease` 而不是 `--force`——前者在远端被别人推过时会失败而不是覆盖。
5. **`git switch -c <b> origin/main` 的推送目标是 upstream 决定的，不是分支名决定的**。
   start-point 是 remote-tracking 分支时 `branch.autoSetupMerge`（默认 `true`）会自动把 upstream 设成主分支；
   从远端主分支起功能分支一律加 `--no-track`，首次推送显式 `git push -u origin <branch>`（§2.6 有 push.default 的准确边界）。
6. **worktree 是「多 agent / 多分支并行」的正解**：共享一份对象库与 refs，各工作树独立 HEAD 与 index，
   比多 clone 省磁盘、比 stash 来回切安全。硬约束是同一分支不能双开、submodule 支持不完整
   （官方原文 "It is NOT recommended to make multiple checkouts of a superproject."），手工删目录后必须 `prune`。
7. **急救三件套各管一段**：`reflog` 找回已丢失的提交，`revert` 用新提交抵消已推送的改动，`reset` 只动未推送的本地历史。

## 一、Git vendor：把外部代码引进本仓库

### 1.1 四条路的取舍

| 方式 | 适用场景 | 优点 | 代价 | 典型命令 |
| --- | --- | --- | --- | --- |
| submodule | 上游保持独立仓库身份，只需钉住某个 commit | 本仓库只存 gitlink + `.gitmodules`，「升级」= 改指针 | 使用者须额外 init/update；工作区默认 detached HEAD；clone 不加 `--recurse-submodules` 目录为空；**不能只取上游某子目录** | `git submodule add <repository> [<path>]`、`git submodule update --init --recursive` |
| subtree | 上游代码要真正成为本仓库某个子目录，且不要求使用者感知 | 无 gitlink/.gitmodules，clone 即得内容；可 `split` 反向回推上游 | 上游历史进入本仓库；`-P <prefix>` 必须处处一致 | `git subtree add -P <prefix> --squash <repository> <remote-ref>` |
| 直接拷贝目录（vendoring） | 下游只消费成品、要求 clone 即得全部文件；或只取上游某个子目录 | 无 git 元数据、无学习成本；文件物理在仓库内，npx/打包工具天然可用；可按子路径裁剪、整树覆盖 | 无 git 原生支持：来源/版本/License 全靠清单 + 脚本 + 提交记录，**上游 commit 无法自动对应** | 见 §1.4 |
| 包管理器 / 构建工具依赖 | 上游有成熟分发渠道，消费方愿意引入依赖 | 版本约束、lockfile、校验和 | 上游未发包、或包结构不含你要的目录时失效 | `npx skills add <repo> -g`；`apm install -g <repo>#<tag>`（本仓库被消费的实例：README.md:49,52） |

### 1.2 submodule 关键命令（逐字摘自 git-scm.com/docs/git-submodule）

```console
git submodule [--quiet] add [<options>] [--] <repository> [<path>]
git submodule add [-b <branch>] [-f | --force] [--name <name>] [--reference <repository>] [--depth <depth>] [--] <repository> [<path>]
git submodule [--quiet] status [--cached] [--recursive] [--] [<path>…]
git submodule [--quiet] update [--init] [--remote] [-N | --no-fetch] [-f | --force] [--checkout | --rebase | --merge] [--recursive] [--jobs <n>] [--] [<path>...]
git submodule [--quiet] foreach [--recursive] <command>
git submodule [--quiet] deinit [-f|--force] (--all|[--] <path>...)
git submodule [--quiet] absorbgitdirs [--] [<path>…]
git clone --recurse-submodules <repository>
```

- `status` 输出的 SHA-1 前可能带 `-`（未初始化）/`+`（与 index 不符）/`U`（合并冲突）。
- `foreach` 内可用变量：`$name $sm_path $displaypath $sha1 $toplevel`。
- `deinit` 不带 pathspec 会报错（防呆）；`-f` 连本地改动一起删。
- `--recursive` 原文：**"Traverse submodules recursively. This option is only valid for foreach, update, status and sync commands."**
- `absorbgitdirs` 用于把旧式「`.git` 目录内嵌在子模块里」的仓库归位到 superproject 的 `$GIT_DIR/modules`。

### 1.3 subtree 关键命令

> ⚠️ `git subtree` 的官方手册**不在** git-scm.com（`https://git-scm.com/docs/git-subtree` 实测 404，本文已核）；原文在 git.git 仓库的 `contrib/subtree/git-subtree.adoc`。

```console
# -P/--prefix 必填。原文："This option is mandatory for all commands."
git subtree [<options>] -P <prefix> add <repository> <remote-ref>
git subtree [<options>] -P <prefix> pull <repository> <remote-ref>
git subtree [<options>] -P <prefix> push <repository> <refspec>
git subtree [<options>] -P <prefix> split [<local-commit>]

# 官方 EXAMPLE 1：加一个 vendor 库（--squash 只取一个提交，减少 log 杂乱）
git subtree add --prefix=git-subtree --squash git://github.com/apenwarr/git-subtree.git master
# 官方 EXAMPLE 2：拉上游更新 / split 成可回推的分支
git subtree pull --prefix=gitweb git@github.com:whatever/gitweb.git master
git subtree split --prefix=gitweb --annotate='(split) ' --rejoin --branch gitweb-latest2
```

- `push` 的定义原文：**"Does a 'split' using the `<prefix>` subtree of `<local-commit>` and then does a 'git push' to push the result to the `<repository>` and `<remote-ref>`."**（即 `push` = `split` + `push`）。

### 1.4 直接拷贝目录（vendoring）

git 没有任何原生机制，做法 = 拉取 + 覆盖写入 + 正常提交，可追溯性靠「清单 + 提交信息」：

```console
git clone --depth 1 --branch "$branch" "$repo" "$tmp/$id"        # 浅克隆，只为一个 commit
rsync -a --delete --exclude .git "$tmp/$id/$subpath/" "$dest/"    # 镜像覆盖；--exclude .git 防把上游 .git 带进来
git switch -c upstream-sync/weekly
git add upstream/ skills/
git commit -m "chore(upstream): 定时同步上游技能"
```

可追溯的最低要求：清单里落「源仓库 + 分支 + 子路径 + 落点（+ License 落位）」。

### 1.5 本仓库的 vendoring 实践

1. **来源清单是唯一真源**：`.upstream/upstreams.json` 每条含 `repo / branch / subpath / dest / license` 五字段
   （例：`mattpocock-skills` = `mattpocock/skills` 的 `main` 分支 `skills/` 子目录 → 落 `upstream/mattpocock/skills`，
   License 落 `upstream/mattpocock/LICENSE`，`.upstream/upstreams.json:2-8`）；分支随上游而异
   （distilly 用 `dot-skill`、harmony-next.skills 用 `master`）。
2. **同步 = 浅克隆 + 只取子路径 + 镜像覆盖**：`git clone -q --depth 1 --branch "$branch"`
   （`.github/scripts/sync-upstream.sh:17`），校验 subpath 存在后 `rsync -a --delete --exclude .git`
   （`sync-upstream.sh:29`）；`subpath` 为 `"."` 即整仓 vendor（distilly、khazix-skills），
   脚本注释明确写了 `--exclude .git` 是为此设的（`sync-upstream.sh:28`）。
3. **License 落位由清单驱动**：清单 `license` 给出落点，脚本从克隆根拷 `LICENSE`（`sync-upstream.sh:30-32`），
   值为 `null` 则不拷。
4. **更新由 CI 定期开 PR、人工合并**：Actions 每周一 03:00 UTC + 手动 dispatch（`sync-upstream.yml:7-8`）；
   脚本只落盘并报告 `git status --porcelain` 变更（`sync-upstream.sh:44-46`），提交/开 PR 交给工作流；
   工作流建固定分支 `upstream-sync/weekly` 后 `push -f` 复用同一 PR，上周未合并则直接更新它，
   不堆积重复 PR（`sync-upstream.yml:39-47`）。落盘后重跑 `scripts/gen-apm-links.sh`
   为 `upstream/` 下的技能在 `skills/` 重建包内 symlink 视图（`sync-upstream.sh:42`）。
5. **为什么不用 submodule（依据仓库文件推断，仓库未明文写理由）**：目标是「本仓库即唯一技能源」，
   下游一条 `npx skills add <本仓库>` 拿到全部技能（README.md:5-6）。submodule 的方案有三处不合：
   ① 下游 clone 不带 `--recurse-submodules` 时子模块目录为空，扫描技能数量会对不上；
   ② 包管理器只跟随「包内」符号链接、只扫根 `skills/` 一层，要求文件物理存在于包内；
   ③ `submodule add <repository> [<path>]` 记录的是一整个仓库，没有「只取上游某子目录」的选项，
   只有 vendoring 能按清单 `subpath` 裁剪。

### 1.6 常见坑

- **submodule 的 detached HEAD**：`update` 默认走 checkout，原文：**"the commit recorded in the superproject will be checked out in the submodule on a detached HEAD"**；直接在子模块里改并提交会得到游离提交。不想游离用 `--rebase`（"The submodule's HEAD will not be detached"）。
- **忘记 `--recursive`**：嵌套子模块不会自动递归；`git clone --recurse-submodules` 等价于 clone 完立刻跑 `git submodule update --init --recursive <pathspec>`。补救甚至不必先跑 `init`——"you can also just use `git submodule update --init` without the explicit init step if you do not intend to customize any submodule locations"。
- **subtree 的重复合并历史**：不加 `--squash` 会把两次上游发布之间的**全部**提交合进来；用 `--rejoin` 则 results in "`git log` showing an extra copy of every new commit that was created"。
- **subtree 的 `-P` 必须始终一致**：换前缀等于换子树；`split`/`push` 的合成历史还依赖相同的 annotation——
  "Whenever you split, you need to use the same `<annotation>`, or else you don't have a guarantee that the new re-created history will be identical to the old one."
- **vendoring 的更新可追溯性差**：仓库里只有文件快照，没有指向上游 commit 的指针（对比 `git submodule status` 会打印 SHA-1）；本仓库清单只记分支名、脚本浅克隆不落上游 SHA、提交信息为固定文案，因此「这份文件来自上游哪个 commit」只能靠时间/内容比对。改进方向：同步时把上游 `git rev-parse HEAD` 写进提交信息或清单。

## 二、Git workflow：分支模型与协作流程

### 2.1 四种分支模型

| 模型 | 适用团队与节奏 | 优点 | 代价 |
| --- | --- | --- | --- |
| **GitHub Flow** | 任意规模；合并即可部署。六步：建分支 → 改动 → 建 PR → 处理 review → 合并 → 删分支 | 只有 feature 分支 + 默认分支；PR 就是协作面，可逐行评论（"ask collaborators for feedback on your changes"） | 不回答部署/环境/发布问题；隐含前提是默认分支随时可发 |
| **trunk-based** | 有规模后 = 短生命周期 PR 分支 + feature flag；要求成员 "commit to trunk at least once every 24 hours" | CI/CD 的使能项，"codebase is always releasable on demand"；规避 merge hell | 需 feature flag / branch by abstraction 配套；"If you have more than a couple of developers … you are going to need to hook up a build server" |
| **Git Flow** | 明确版本化、需同时维护多个线上版本的产品 | 角色清楚：master 常备可发布、develop 集成、feature/release/hotfix 各有起止规则 | GitLab 官方评价其 "too complicated for most use cases"；release/hotfix 来回合并有仪式成本与漏合风险。作者 2020 年补记：持续交付的 Web 应用应 "adopt a much simpler workflow (like GitHub flow)" |
| **GitLab Flow** | 需要环境纪律（staging / pre-prod / production / release 分支）的团队 | 在 main 之上加一层可控分支，纪律单向："commits only flow downstream"；release 分支 "branch as late as possible"，修 bug 走 upstream first | 分支更多、约定更细 |

### 2.2 PR 流程与分支保护

- **分支命名**：官方只要求 "A short, descriptive branch name enables your collaborators to see ongoing work at a glance." 且 "Make a separate branch for each set of unrelated changes."；本仓库约定 `<type>/<功能简述>`，type 与 §2.5 对齐。
- **PR 描述要素**：目的 + 关联 issue（closing keyword）；改动范围并明确不做什么；验证方式（跑了哪些测试、手工怎么复现）；
  需重点 review 的地方与已知取舍；breaking change 提示。
- **review 时机**：在一个分支上工作超过几小时就先开 MR 要反馈——"create a merge request without assigning it to anyone"，
  在描述或评论里 @ 人；准备好合并时再指派给最懂这块代码的人。草稿 PR 不能合并，也不会自动请求 code owner review。
- **CI 门禁**挂在受保护分支上："After enabling required status checks, all required status checks must pass before collaborators can merge changes into the protected branch."
- **分支保护为什么是「误推」的服务端兜底**：保护规则本身 "define whether collaborators can delete or force push to the branch and set requirements for any pushes to the branch"；开启 branch restrictions 后 "only users, teams, or apps that have been given permission can push to the protected branch"；默认 "GitHub blocks force pushes on all protected branches"，且 "you cannot delete a protected branch"。
  ⚠️ **默认管不住管理员**："the restrictions of a branch protection rule don't apply to people with admin permissions"——个人仓库自己就是 admin，必须显式开 "Do not allow bypassing"。

### 2.3 合并策略与 ff 家族

| 策略 | 历史形态 | 取舍 |
| --- | --- | --- |
| merge commit | GitHub 默认按钮："The pull request is merged using the `--no-ff` option." | 保留分支边界与合并时点；历史非线性（用 `git log --first-parent` 读主线） |
| squash | "the pull request's commits are squashed into a single commit" | 一个 PR = 一个提交，主线干净；丢掉分支内部粒度 |
| rebase and merge | 提交被 "added onto the base branch individually without a merge commit" | 线性无 merge commit，但会重写提交，只适合个人分支 |

`git merge` 的 ff 家族（逐字，git-scm.com/docs/git-merge）：

> With `--ff`, when possible resolve the merge as a fast-forward (only update the branch pointer to match the merged branch; do not create a merge commit). When not possible (when the merged-in history is not a descendant of the current history), create a merge commit.
> With `--no-ff`, create a merge commit in all cases, even when the merge could instead be resolved as a fast-forward.
> With `--ff-only`, resolve the merge as a fast-forward when possible. When not possible, refuse to merge and exit with a non-zero status.

照做：本地收口功能分支用 `git merge --ff-only`；要把功能分支边界固化进主线历史用 `--no-ff`。
`--ff` 是默认，但合入一个「不在 `refs/tags/` 自然位置上的 annotated tag」时 `--no-ff` 会被假定。

### 2.4 rebase 与 force-with-lease

- **可以 rebase**：尚未推送的本地提交；自己独占、没有别人基于它工作的 feature 分支。
- **不可以 rebase**：任何已共享的历史。原文：**"Rebasing (or any other form of rewriting) a branch that others have based work on is a bad idea: anyone downstream of it is forced to manually fix their history."**
- `--force`："This flag disables that check, the other safety checks in PUSH RULES below, and the checks in `--force-with-lease`. **It can cause the remote repository to lose commits; use it with care.**"
- `--force-with-lease`："This option overrides this restriction if the current value of the remote ref is the expected value. `git push` fails otherwise."
  不带期望值的形式 "will protect all remote refs that are going to be updated by requiring their current value to be the same as the remote-tracking branch we have for them"，
  但它 **"interacts very badly with anything that implicitly runs `git fetch` on the remote to be pushed to in the background"**（IDE 后台 fetch 会让 lease 失效），可搭配 `--force-if-includes`。
- 交互式 rebase 常用动作（git 自带 todo 模板原文）：`pick` / `reword`（改 message）/ `edit`（停下 amend）/ `squash`（并入上一条，保留两条 message）/ `fixup`（并入上一条，只留上一条 message）/ `drop` / `break` / `exec`。
  日常用法：`git commit --fixup=<sha>` 累积修补提交，收口时 `git rebase -i --autosquash <base>` 一次折叠——
  `--autosquash` 原文："Automatically squash commits with specially formatted messages into previous commits being rebased. If a commit message starts with "squash! ", "fixup! " or "amend! ", the remainder of the title is taken as a commit specifier"。

### 2.5 commit 规范（Conventional Commits 1.0.0）

结构：`<type>[optional scope]: <description>`，空行后 `[optional body]`，再空行后 `[optional footer(s)]`。
硬性规则原文：**"Commits MUST be prefixed with a type, which consists of a noun, feat, fix, etc., followed by the OPTIONAL scope, OPTIONAL !, and REQUIRED terminal colon and space."**

- `fix` → "patches a bug in your codebase (this correlates with PATCH in Semantic Versioning)"；
- `feat` → "introduces a new feature to the codebase (this correlates with MINOR in Semantic Versioning)"；
- `BREAKING CHANGE` → "a commit that has a footer BREAKING CHANGE:, or appends a ! after the type/scope, introduces a breaking API change (correlating with MAJOR in Semantic Versioning). A BREAKING CHANGE can be part of commits of any type."

其它 type 不被规范规定（"Additional types are not mandated by the Conventional Commits specification"），
社区通行的是 `build / chore / ci / docs / style / refactor / perf / test` 等（Angular convention 系）。
价值在于**可被脚本解析**："Automatically generating CHANGELOGs."、"Automatically determining a semantic version bump (based on the types of commits landed)."

### 2.6 上游追踪陷阱：从远端主分支起分支

`git branch --track` / `--no-track` 与 `branch.autoSetupMerge`（逐字，git-scm.com/docs/git-branch）：

> `-t, --track[=(direct|inherit)]`：When creating a new branch, set up `branch.<name>.remote` and `branch.<name>.merge` configuration entries to set "upstream" tracking configuration for the new branch. … `-t, --track`, or `--track=direct` means to use the start-point branch itself as the upstream; `--track=inherit` means to copy the upstream configuration of the start-point branch.
> `--no-track`：Do not set up "upstream" configuration, even if the `branch.autoSetupMerge` configuration variable is set.
> `branch.autoSetupMerge` … defaults to `true`. 有效取值：`false`（不做自动设置）、`true`（当起点是 remote-tracking 分支时自动设置）、`always`（起点是本地或 remote-tracking 分支都设置）、`inherit`（复制起点的追踪配置）、`simple`（仅当起点是 remote-tracking 分支且新分支与远端分支同名）。

**现象**：`git switch -c feat/x origin/main` 的 start-point 是 remote-tracking 分支，默认 `branch.autoSetupMerge=true`
等价于 `--track=direct`，于是写入 `branch.feat/x.remote=origin`、`branch.feat/x.merge=refs/heads/main`——
新分支的 upstream 直接指向主分支。而 upstream 是 `git push` 无参时的默认目标。

**准确边界（别把「一定会误推」当结论）**：无参 push 打到哪由 upstream 决定，但还要叠加 `push.default` 与客户端实现：
`push.default=upstream` 的语义才是 "push the current branch back to the branch whose changes are usually integrated into the current branch (which is called `@{upstream}`)"，
会真的写进 `origin/main`；而 Git 2.0 起的默认 `push.default=simple` 要求 "the current branch must also have an upstream tracking branch with the same name"，
名称不匹配时 push 直接失败——这其实是默认的第二道闸。GUI 的推送按钮本质是无参 push，是否会落到主分支取决于它的实现。

**照做**：从远端主分支起功能分支一律 `git switch -c <type>/<desc> --no-track origin/main`；
首次推送显式 `git push -u origin <branch>`；把 `branch.autoSetupMerge` 设为 `false` 可作全局止损；
真正的兜底是 §2.2 的受保护分支 + required reviews / status checks。

## 三、git worktree：一个仓库，多个工作树

### 3.1 是什么、与多 clone / stash 的取舍

官方定义原文：

> A git repository can support multiple working trees, allowing you to check out more than one branch at a time. … This new worktree is called a "linked worktree" as opposed to the "main worktree" prepared by git-init or git-clone.

每个工作树有独立的 `HEAD` 与 index，共享对象库与 refs。典型动机：一条分支给 CI、一条给人工 review、一条给 AI agent 同时开工，而不重复 clone。

| 维度 | 多 clone | stash 来回切 | git worktree |
| --- | --- | --- | --- |
| 对象库 / refs | N 份，要分别 fetch、逐仓库配 remote | 1 份 | 1 份，`add` 几乎零成本 |
| 分支切换 | 无切换成本 | 每次 stash/pop，易出错 | 各工作树独立 HEAD |
| 未提交改动 | 天然隔离 | 是干扰源 | 天然隔离 |
| AI agent 隔离 | 干净但最贵 | 完全无法隔离 | 一个 agent 一棵树，互不写坏 |
| 代价 | 磁盘、时间、多份配置漂移 | 中断流 | 同一分支不能双开；submodule 支持不完整 |

官方警告（git-scm.com/docs/git-worktree 的 BUGS 段）：**"Multiple checkout in general is still experimental, and the support for submodules is incomplete. It is NOT recommended to make multiple checkouts of a superproject."**；
另外 "linked worktrees containing submodules cannot be moved"。

### 3.2 命令与参数（照抄官方文档）

```bash
git worktree add [-f] [--detach] [--checkout] [--lock [--reason <string>]]
                [--orphan] [(-b | -B) <new-branch>] <path> [<commit-ish>]
git worktree list [-v | --porcelain [-z]]
git worktree lock [--reason <string>] <worktree>
git worktree move <worktree> <new-path>
git worktree prune [-n] [-v] [--expire <expire>]
git worktree remove [-f] <worktree>
git worktree repair [<path>...]
git worktree unlock <worktree>
```

- `-b/-B <new-branch>`："With `add`, create a new branch named `<new-branch>` starting at `<commit-ish>`, and check out `<new-branch>` into the new worktree. If `<commit-ish>` is omitted, it defaults to `HEAD`. By default, `-b` refuses to create a new branch if it already exists. `-B` overrides this safeguard, resetting `<new-branch>` to `<commit-ish>`."
- `-d/--detach`："With `add`, detach `HEAD` in the new worktree."
- `--orphan`："With `add`, make the new worktree and index empty, associating the worktree with a new unborn branch named `<new-branch>`."
- `-f`："By default, `add` refuses to create a new worktree when `<commit-ish>` is a branch name and is already checked out by another worktree, or if `<path>` is already assigned to some worktree but is missing. This option overrides these safeguards. To add a missing but locked worktree path, specify `--force` twice."
- `list --porcelain`："output in an easy-to-parse format for scripts. This format will remain stable across Git versions and regardless of user configuration. It is recommended to combine this with `-z`."
- `remove -f`："Only clean worktrees (no untracked files and no modification in tracked files) can be removed. Unclean worktrees or ones with submodules can be removed with `--force`. **The main worktree cannot be removed.**"；移除 locked worktree 要 `--force` 两次。
- `prune --expire <time>`："only prune missing worktrees if older than `<time>`"；默认宽限期由 `gc.worktreePruneExpire` 决定，"When 'git gc' is run, it calls 'git worktree prune --expire 3.months.ago'."
- `lock --reason`："If a worktree is on a portable device or network share which is not always mounted, lock it to prevent its administrative files from being pruned automatically. This also prevents it from being moved or deleted."
- `move`："Note that the main worktree or linked worktrees containing submodules cannot be moved with this command."
- `repair [<path>...]`："Repair worktree administrative files, if possible, if they have become corrupted or outdated due to external factors."

### 3.3 硬性约束与坑

- **同一分支不能同时 checkout 到两处**：`add` 在 `<commit-ish>` 已被别的工作树检出时直接拒绝（除 `--force`）；`git checkout` 侧的对应开关是 `--ignore-other-worktrees`。
- **主/链接工作树的关系**：每个链接工作树在 `$GIT_DIR/worktrees` 下有一个私有子目录（目录名通常是工作树路径的 basename，重名追加数字）。
  在该工作树内 `$GIT_DIR` 指向 `/path/main/.git/worktrees/<name>`，`$GIT_COMMON_DIR` 指回主工作树的 `.git`；
  `HEAD` 这类伪 ref 是各工作树私有的，`refs/` 开头的 ref 共享。
- **直接删目录必须 `prune`**："Remove worktree information in `$GIT_DIR/worktrees` for worktrees whose working trees are missing. Useful after manually removing a working tree that is no longer needed (but use "git worktree remove" next time you want to do so)."
- **可移动存储 / 被系统清理**：外置盘没挂载时 `git worktree list` 会标成 `prunable`，用 `lock --reason` 挡住自动 prune；目录被搬走或清理导致关联失效则跑 `repair`。
- **bare 仓库**："A repository has one main worktree (if it's not a bare repository) and zero or more linked worktrees."——裸仓库可以只挂链接工作树。
- **`core.bare` / `core.worktree`**："If the config variables `core.bare` or `core.worktree` are present in the common config file and `extensions.worktreeConfig` is disabled, then they will be applied to the main worktree only." 要逐工作树配置就得开 `extensions.worktreeConfig`。

### 3.4 典型场景

```bash
# 1) 为 PR review 临时开一棵（detached，不污染本地分支）
git fetch origin pull/1234/head:pr-1234          # 取回 PR 到本地临时分支，避免 FETCH_HEAD 被后续 fetch 覆盖
git worktree add --detach ../review-pr-1234 pr-1234
cd ../review-pr-1234 && make test
cd - && git worktree remove ../review-pr-1234 && git branch -D pr-1234

# 2) 并行跑两条 feature
git worktree add ../proj-feature-a -b feature/a   # 省略 <commit-ish> 时默认从 HEAD 起新分支
git worktree add ../proj-feature-b -b feature/b
# …两个目录各开编辑器/测试进程…
git worktree remove ../proj-feature-a ../proj-feature-b

# 3) 给每个 AI agent 一棵隔离树（含锁与回收）
for i in 1 2 3; do git worktree add --lock --reason "agent-$i" "../agent-$i" -b "agent/$i"; done
git worktree list --porcelain                     # 脚本友好，逐条确认树与分支
for i in 1 2 3; do git worktree unlock "../agent-$i" && git worktree remove "../agent-$i" || true; done
git worktree prune                                # 防漏：任何直接删目录的情况都靠它收尾

# 4) 中心 bare 仓库 + 多棵工作树（不需要主工作树）
git clone --bare git@github.com:me/proj.git proj.git
cd proj.git && git worktree add ../proj-main main
git worktree add ../proj-hotfix -b hotfix main
git worktree repair ../proj-main ../proj-hotfix   # 整个 proj.git 被搬动后用它重连
```

### 3.5 常用急救命令

| 命令 | 解决什么问题 | 可直接复制 |
| --- | --- | --- |
| `git reflog` | 误 `reset` / 误删分支后找回旧 tip。`HEAD@{1}` 是 "the commit that `HEAD` used to be at prior to the original `reset`" | `git reflog` → `git branch rescue <sha>`；或 `git reset --hard HEAD@{1}`（reset 前的位置另存于 `ORIG_HEAD`） |
| `git bisect` | 二分定位哪个提交引入回归。`--first-parent` 只沿第一父提交走，避免把合并进来的坏提交误报为元凶 | `git bisect start HEAD v1.2 && git bisect bad && git bisect good v1.2`；每步测完 `git bisect good/bad`；扫尾 `git bisect reset` |
| `git bisect run` | 有判定脚本时全自动。退出码：`0`=good、`1..127` 且非 `125`=bad、`125`="the current source code cannot be tested"（跳过）、其余码中止 | `git bisect start HEAD v1.2 && git bisect run ./test.sh`（脚本内 `make \|\| exit 125` 可跳过错构建） |
| `git cherry-pick` | 把某个提交的改动抄到当前分支，不搬整条历史。`-x` 追加 `(cherry picked from commit …)`，官方建议在 "between two publicly visible branches" 时加上 | `git cherry-pick -x <sha>`；冲突时 `git cherry-pick --abort`（"Cancel the operation and return to the pre-sequence state"） |
| `git stash` | 临时存起工作区+index 并还原到 `HEAD`。`-u` 连未跟踪文件一起存、`--keep-index` 保留已暂存内容在原地 | `git stash push -u -m "wip"`；取回 `git stash pop`（取出即出栈）或 `git stash apply`（"Like pop, but do not remove the state from the stash list"） |
| `git restore` | 只恢复文件，不动分支。"The command does not update your branch." | 丢单文件改动 `git restore <path>`；撤销暂存 `git restore --staged <path>`；取旧版本 `git restore --source=<sha> <path>` |
| `reset` / `restore` / `revert` 分工 | 官方原文：`git revert` "is about making a new commit that reverts the changes made by other commits"；`git restore` "is about restoring files in the working tree from either the index or another commit. This command does not update your branch."；`git reset` "is about updating your branch, moving the tip in order to add or remove commits from the branch. This operation changes the commit history." | 动历史用 `reset`，动文件用 `restore`，动「要不要这个提交」用 `revert`；`checkout` 的组合能力已按用途拆给 `switch`（切分支）与 `restore`（恢复文件），自身保留组合用法 |
| `git commit --amend` | "Replace the tip of the current branch by creating a new commit." 仅适合修正**尚未推送**的 tip（漏文件、改 message、补 author） | `git commit --amend --no-edit`（不改 message）；注意 "You should understand the implications of rewriting history if you amend a commit that has already been published."，误 amend 后用 `git reflog` 找回原提交 |

## 来源

| 内容 | 来源 |
| --- | --- |
| submodule 命令与语义 | https://git-scm.com/docs/git-submodule ；https://git-scm.com/docs/gitsubmodules |
| subtree 命令与语义（手册不在 git-scm.com） | https://raw.githubusercontent.com/git/git/master/contrib/subtree/git-subtree.adoc （`https://git-scm.com/docs/git-subtree` 为 404） |
| clone 的子模块行为 | https://git-scm.com/docs/git-clone |
| merge 的 ff 家族 | https://git-scm.com/docs/git-merge |
| rebase 规则与交互模式 | https://git-scm.com/docs/git-rebase |
| push 的 force / force-with-lease / push.default | https://git-scm.com/docs/git-push |
| branch 的 track / autoSetupMerge | https://git-scm.com/docs/git-branch |
| worktree 全部命令与约束 | https://git-scm.com/docs/git-worktree ；https://git-scm.com/docs/git-config （`gc.worktreePruneExpire`） |
| 急救命令语义（reflog/bisect/stash/cherry-pick/restore/reset/revert） | https://git-scm.com/docs/git-reflog 、/git-bisect 、/git-stash 、/git-cherry-pick 、/git-restore 、/git-reset 、https://git-scm.com/docs/git#_reset_restore_and_revert |
| GitHub Flow 六步与分支命名 | https://docs.github.com/en/get-started/using-github/github-flow |
| PR 能力与草稿 PR | https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests |
| 分支保护五条规则 | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches |
| 三种合并方式 | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/about-merge-methods-on-github |
| trunk-based / Git Flow / GitLab Flow | https://trunkbaseddevelopment.com/ 、https://nvie.com/posts/a-successful-git-branching-model/ 、https://docs.gitlab.com/ee/topics/gitlab_flow.html |
| Conventional Commits 1.0.0 | https://www.conventionalcommits.org/en/v1.0.0/ |
| 本仓库 vendoring 实现 | `.upstream/upstreams.json`、`.github/scripts/sync-upstream.sh`、`.github/workflows/sync-upstream.yml`、`scripts/gen-apm-links.sh` |
