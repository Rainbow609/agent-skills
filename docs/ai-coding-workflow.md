# AI Coding 工作流参考（初始化三件套 / giscus 实战）

> **来源**：Ruixe《我在 2026 年中旬的 AI Coding 工作流》 https://blog.ruixe.net/zh/posts/ai-coding-workflow-2026-mid （2026-09 发布）
> **复核**：2026-10-16。giscus `data-strict` 机制已回 [giscus 官方 ADVANCED-USAGE.md](https://github.com/giscus/giscus/blob/main/ADVANCED-USAGE.md) 逐句核对（§3，一手 ✅）；其余为对原文的转述提炼，未逐条实测处以「存疑」标注。模型型号与价格类内容不收录（额度单价速查见 `coding-plan-quota-and-pricing.md`）。

## TL;DR

1. **项目初始化三件套**：Skills（`npx skills` / skills.sh 市场）＋ MCP 常驻（browser / search / fetch 三类）＋ AGENTS.md（全局 → 项目 → 子目录三层）。
2. **giscus `strict=1` 的真实机制**：不是严格匹配标题字符串，而是**把标题做 SHA-1 后在 Discussion 正文里搜哈希**——启用前必须保证目标 Discussion 正文含该哈希，否则一律 not found（官方只在 ADVANCED-USAGE.md 写了这一点）。

## 1. 项目初始化三件套

### 1.1 Skills

- 安装：`npx skills add <owner>/<repo>`；裸 `npx skills` 打开 [skills.sh](https://skills.sh) 技能市场（带热度榜）。
- 技能装到 `~/.agents/skills` 后由各家 Coding Agent（Claude Code / Codex / ZCode 等）共享加载。
- 🌟 **全角标点坑**：从网页复制安装命令时，全角括号/引号/冒号混入会导致命令静默失败——粘贴后先过一遍标点。

### 1.2 MCP 常驻三类

| 类别 | 作用 | 典型 |
| --- | --- | --- |
| browser | 驱动浏览器做 UI 操作 / 取证 | Playwright MCP、chrome-devtools MCP |
| search | 联网检索 | 搜索类 MCP（如 Exa） |
| fetch | 抓取网页正文 | fetch / web-reader 类 MCP |

原则：给 agent 配齐「自己查证」的工具，减少凭训练记忆作答与来回追问。

### 1.3 AGENTS.md 写法原则

- **三层结构**：全局层（个人偏好、跨项目规则）→ 项目根层 → 子目录层（嵌套生效、就近覆盖）。
- **写什么**：约束、踩坑、项目特有惯例、验证命令；**不写什么**：常识与「新人 5 分钟能自然学会」的东西。
- `/init` 全量重生成的时机：Coding Agent 大版本升级后、项目架构明显变化后；平时只做增量修补。
- 与本仓 [`agents-md-best-practices.md`](./agents-md-best-practices.md) 互证；写作细则以该文档为准。

## 2. 提示词模板（择要）

1. **意图澄清模板**（任何非平凡任务动手前）：
   > 先不要写代码。复述你理解的任务目标；列出你做出的全部假设与未知项；给出可选方案与你的推荐；等我确认后再开始。

   一轮往返换掉整段返工，适合作为任何非平凡任务的固定开场。
2. **Git 提交模板**：约束 commit message 格式（`<type>(<scope>): <描述>`）、按变更性质分组提交、提交前先自查 diff。

## 3. giscus 评论系统：strict 机制与跨语言聚合（一手复核 ✅）

### 3.1 `data-strict="1"` 的真实机制

官方 ADVANCED-USAGE.md 要点（2026-10-16 核对）：

- 默认（strict=0）：giscus 用 term 去 GitHub **模糊搜索 Discussion 标题**，存在多个相似标题的 Discussion 时可能错配。
- `strict=1`：giscus **计算标题（term）的 SHA-1 哈希，改为在候选 Discussion 的正文（body）中搜索该哈希串**——搜索目标从标题换成了正文。
- **启用前提**：目标 Discussion 的正文里必须已包含其标题的 SHA-1 哈希。strict 特性上线前创建的存量 Discussion 需手动迁移：编辑 Discussion，把哈希补进正文任意位置（官方原文给出的迁移方法）。
- 存疑：strict=1 下由 giscus bot 新建的 Discussion 是否自动把哈希写入正文——官方文档未明说；实操时以 giscus.app 生成器默认行为＋一次真实评论实测为准。

实测记录（2026-10-16）：`sha1("ai-coding-workflow-2026-mid") = f411f523cada4555b268312b00577c230bef050e`；`giscus.app/api/discussions` 对原始 term 与 SHA-1 哈希（含 category 参数）均返回 `Discussion not found`——该文 Discussion 尚不存在（零评论），端到端匹配未复现，机制以官方文档为准。

### 3.2 跨语言评论聚合

- giscus 四种 mapping：`pathname` / `URL` / `title` / `specific`。多语言站点要让中英两页共用一个评论区，用 **`mapping=specific` ＋ 两种语言传同一个 `term`（如文章 slug）**。
- 迁移顺序硬约束：**先补存量（旧 Discussion 正文补哈希，或先按旧配置让每篇文章都建出 Discussion），再切换 strict=1 / specific**——giscus 没有 Discussion 合并能力，顺序错了旧评论就永久悬空。

### 3.3 工程落地形态

把 giscus 封装成单一组件（props 透传 repo / repoId / category / term / strict），多语言布局各自引用同一组参数——配置只有一处，聚合逻辑不散落。

## 4. 参考链接

- 原文：<https://blog.ruixe.net/zh/posts/ai-coding-workflow-2026-mid>
- giscus ADVANCED-USAGE：<https://github.com/giscus/giscus/blob/main/ADVANCED-USAGE.md>
- skills.sh：<https://skills.sh>
