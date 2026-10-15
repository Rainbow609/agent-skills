# Kimi Code 子代理 tools 白名单：必须用 Kimi Code 工具名（Copilot 名单会整体失效）

> 适用对象：`~/.agents/agents/*.agent.md`（universal 格式自定义子代理，单一真源在
> 本仓库 `agents/universal/`，经 `install.sh` 第③步落盘）。从 VS Code Copilot 搬配置
> 时最容易踩这个坑。

## 现象与根因

子代理被派发后一个工具都挂不上：连续多轮用 `select_tools` 尝试加载 Read/Edit/Bash/Grep
全部返回 "No tools can be loaded in this session"，最后按铁律回报"受阻"。
客户端日志（kimi-code.log）对每个 agent 文件都有一串 WARN：

```
tools entry "xxx" matches no registered or built-in tool (a typo?)
```

根因：这些 `.agent.md` 的 `tools:` 白名单是从 Copilot 格式搬来的，写的是 Copilot 工具名
（`codebase`、`searchResults`、`usages`、`problems`、`changes`、`findTestFiles`、
`testFailure`、`runCommands`、`editFiles`，以及 OpenSpec 生成的 `"execute"`/`"read"`/
`"search"`/`"edit"`）。这些名字在 Kimi Code 里**一个都不存在**，运行时把白名单整体
过滤成空列表 → 子代理无工具可用。

**对照组**：`harmonyos-tester.agent.md` 没有 `tools:` 字段，继承默认完整工具集，一直
正常。这说明"不写 tools: 字段"本身就是合法且最省事的配置方式。

旁证：卡片上显示的"N 个工具"会把 `select_tools` 这个 meta 工具也算进去，看到"2 个工具"
不代表白名单生效。

## 修复方法（已执行，2026-10-15）

1. **首选**：删掉 `tools:` 字段，子代理继承默认完整工具集（harmonyos-tester 模式）。
   只读约束靠正文铁律维持即可。
2. **要保留白名单**（如刻意限制只读代理）：按下面的映射换成 Kimi Code 工具名。

### Copilot → Kimi Code 工具名映射

| Copilot 工具名 | Kimi Code 等价 | 说明 |
|---|---|---|
| `codebase` | `Grep`, `Glob`, `Read` | 语义检索/代码库问答 |
| `searchResults` | `Grep`, `Glob` | 文本搜索 |
| `usages` | `Grep`, `Read` | 引用查找 |
| `problems` / `changes` | `Read`, `Bash` | 诊断/git 状态 |
| `findTestFiles` | `Grep`, `Glob` | 测试文件定位 |
| `testFailure` | `Bash` | 跑测试看输出 |
| `runCommands` | `Bash` | 终端 |
| `editFiles` | `Edit`, `Write` | 编辑/新建 |
| `"execute"` | `Bash` | OpenSpec 生成配置里的项 |
| `"read"` | `Read` | 〃 |
| `"search"` | `Grep`, `Glob` | 〃 |
| `"edit"` | `Edit`, `Write` | 〃 |
| `server/tool`（MCP 旧写法） | `mcp__<server>__<tool>` | Kimi Code 的 MCP 工具命名规范 |

映射时按**意图**替换、自动去重，天然保留各代理的只读/可写边界（只读代理的名单里没有
`editFiles`/`"edit"`，映射结果就不会出现 `Edit`/`Write`）。

除 `tools:` 列表外，还要清理两处残留：正文里引用旧工具名的句子（如"用 codebase 搜索"
"runCommands 仅限只读 git 命令"），以及 description 行尾的 `(Tools: ...)` 括注——它们
会被注入到会话的代理清单里，不清理就会持续传播错误名字。

## 防再犯

校验/修复一体脚本：`scripts/check_agent_tools.py`（零依赖，Python 3 标准库）。

```bash
# 校验（默认扫本仓库 agents/universal/，退出码 1 = 有未知工具名）
python3 scripts/check_agent_tools.py

# 自动修复：按映射表改写 tools:、正文残留引用与 description 括注
python3 scripts/check_agent_tools.py --fix

# 扫其他目录（如 Copilot 格式配置源）
python3 scripts/check_agent_tools.py <目录> [--fix]
```

改完源文件后部署（与 `install.sh` 第③步同语义）：

```bash
cp agents/universal/*.agent.md ~/.agents/agents/
```

建议：新增/修改 universal 代理后随手跑一次校验；从 Copilot 仓库搬新代理时必跑。

## 注意事项

- **代理注册表在「对话开始」时快照**：运行中修改/新增 `~/.agents/agents/*.agent.md`（包括
  `install.sh` 落盘）对**已开启的对话不生效**，派生子代理仍用旧配置（新代理则报
  `Subagent profile "xxx" was not found`）。修复后必须**开新对话**验证，探针方法：新对话里
  派发任意带白名单的代理，让其 Read 一个文件 + Bash `echo probe` 并回报实际工具清单。
- 无法识别的条目（如外部 MCP 的 `dbx/dbx_*`）脚本会原样保留并告警——它们同样会被
  Kimi Code 过滤掉，需对照所连 MCP 的实际工具名（`mcp__<server>__<tool>`）人工确认。
- `mcp-servers:` 等 Copilot 专属 YAML 字段 Kimi Code 会忽略，对运行时无影响，可留可删。
- `agents/zcode/*.md`（ZCode 格式）是另一套运行时，工具名规范不同，本脚本不覆盖；
  若 ZCode 侧也搬了 Copilot 配置，需另行核对。
