# 提交信息格式规范

## 格式要求

```markdown
<type>(<scope>): <简体中文简要描述>

<简体中文详细描述（可选）>

<footer（可选）>
```

- **语言**：必须使用简体中文，技术术语保留英文，中文标点用全角
- **type**：遵循 Conventional Commits，一律小写英文
- **scope**：小写英文（模块名或目录名，如 `stationb`、`scheduler`），与受影响的 src 目录或组件对齐；无法归属单一 scope 时省略
- **描述**：祈使句，不使用句点结尾，控制在 50 字以内
- **正文**：与描述间空一行，每行 ≤ 72 字符，说明动机、影响与权衡，不逐行复述 diff 可见的内容
- **footer**：与正文间空一行，采用 git trailer 格式——token 后接 `:` 或 `#`（如 `Closes #123`、`Reviewed-by: ...`）
- **BREAKING CHANGE**：在 type/scope 后加 `!`（如 `feat!:`），并于 footer 写 `BREAKING CHANGE: <迁移说明>`；破坏性变更可出现于任何 type

## 类型对照表

| type | 用途 | 简体中文示例 |
|------|------|-------------|
| `feat` | 新增功能 | `feat(stationb): 新增 get_stb_dw1 数据迁移函数` |
| `fix` | 修复问题 | `fix(scheduler): 修复 APScheduler 启动时任务过滤逻辑错误` |
| `docs` | 文档变更 | `docs(CLAUDE.md): 新增 commit 信息须使用简体中文的规范` |
| `refactor` | 重构逻辑 | `refactor(view): 修正 v_eol_dss_stationb_dw1 schema 引用错误` |
| `chore` | 调整配置项 | `chore(deps): 更新依赖版本至最新稳定版` |
| `build` | 构建系统或外部依赖来源变更 | `build(deps): 更换 PyPI 内部镜像源地址` |
| `perf` | 性能优化 | `perf(query): 为 issue_item 字段新增非聚集索引` |
| `test` | 新增/更新测试 | `test(stationb): 新增分批处理单元测试` |
| `style` | 格式调整（无逻辑变更）| `style: 统一缩进为四个空格` |
| `ci` | CI/CD 变更 | `ci: 新增自动化部署脚本` |
| `revert` | 回退提交 | `revert: 回退 "feat(auth): 新增 OAuth2 登录"` |

## Good vs Bad 示例

```
# BAD: 含糊、无上下文
git commit -m "修复问题"
git commit -m "更新"
git commit -m "WIP"

# GOOD: 清晰、具体、说明原因
git commit -m "fix(api): 修复 503 服务不可用时的重试逻辑

外部 API 在高峰时段偶尔返回 503 错误。
新增指数退避重试机制，最多尝试 3 次。

Closes #123"

# GOOD: 破坏性变更——type 加 ! 并于 footer 注明迁移方式
git commit -m "refactor!(api): 移除 v1 查询接口

BREAKING CHANGE: 移除 GET /v1/orders 端点，请改用 /v2/orders。"
```

## 提交模板资产（.gitmessage）

本规范已资产化为模板文件 `assets/gitmessage`，随技能安装在用户目录（`~/.agents/skills/git-commit/assets/gitmessage`，与 `~/.zcode/skills/` 下内容一致），让未经 agent 的手动提交也遵循同一规范：

```bash
# 于任意仓库执行一次即可；用绝对路径（git 会展开 ~），不依赖技能装在仓库内
git config commit.template ~/.agents/skills/git-commit/assets/gitmessage

# 之后不带 -m 的 git commit 会自动带入注释模板
git commit
```

- 模板全行为 `#` 注释，git 提交时自动剥除，不会残留于信息
- agent 执行分组提交时仍以 `-m` / `-F` 直接给信息，模板仅作用于人类交互式提交

## 格式骨架验证（grep）

执行 `git commit` 前以 bash grep 验证格式：

```bash
echo "{type}({scope}): {简体中文描述}" | grep -qE "^(feat|fix|docs|refactor|chore|build|perf|test|style|ci|revert)(\([a-z0-9_-]+\))?!?: .{1,50}$"
```

不通过时中止，显示格式要求，要求用户修正。

## 语义验证清单（代理逐组执行）

grep 只验证格式骨架；以下语义检查由代理在 `git commit` 前逐组执行：

- [ ] type 许可（`feat|fix|docs|refactor|chore|build|perf|test|style|ci|revert`）
- [ ] 描述为简体中文（技术术语除外），不含英文句子
- [ ] 描述 ≤50 字符，无句点结尾
- [ ] scope 为小写英文模块名或省略
- [ ] 破坏性变更已加 `!` 并写 BREAKING CHANGE footer
- [ ] 正文（如有）与描述间空一行，每行 ≤72 字符

不通过时：中止提交，显示具体不符项目，要求修正后再继续。
