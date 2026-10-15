#!/usr/bin/env python3
"""校验 / 修复 .agent.md 的 tools 白名单（Copilot 工具名 → Kimi Code 工具名）。

背景：从 VS Code Copilot 搬来的自定义子代理配置里，tools: 白名单写的是 Copilot
工具名（codebase、runCommands、editFiles……），这些名字在 Kimi Code 里不存在，
会被整体过滤成空列表——子代理一个工具都挂不上，只能靠 select_tools 反复尝试后
报"受阻"。`harmonyos-tester` 因为没有 tools: 字段、继承默认全集，所以一直正常。

用法：
    python3 check_agent_tools.py [目录]        # 只校验，发现未知工具名退出码 1
    python3 check_agent_tools.py [目录] --fix  # 按映射表改写 tools: 与正文残留引用

默认目录：本仓库 agents/universal/（运行时落盘到 ~/.agents/agents/，经 install.sh 第③步）。
改完源文件后部署：cp agents/universal/*.agent.md ~/.agents/agents/（与 install.sh 第③步同语义）。

映射约定（按意图一一对应，保留各代理的只读/可写边界）：
    codebase/searchResults → Grep, Glob, Read     runCommands → Bash
    usages/findTestFiles   → Grep, Read           editFiles   → Edit, Write
    problems/changes       → Read, Bash           testFailure → Bash
    "execute"              → Bash                 "read"      → Read
    "search"               → Grep, Glob           "edit"      → Edit, Write
无法识别的条目（如外部 MCP 的 dbx/dbx_*）原样保留并给出警告——它们可能被运行时过滤，
需对照所连 MCP 的实际工具名（Kimi Code 形如 mcp__<server>__<tool>）人工确认。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Kimi Code 子代理可用的内建工具名（见会话注入的 Agent 工具定义）
KNOWN_TOOLS = {
    "Bash", "Edit", "Glob", "Grep", "Read", "ReadMediaFile", "Skill",
    "TodoList", "WebSearch", "FetchURL", "Write", "Agent",
}

COPILOT_TO_KIMI: dict[str, list[str]] = {
    "codebase": ["Grep", "Glob", "Read"],
    "searchResults": ["Grep", "Glob"],
    "usages": ["Grep", "Read"],
    "findTestFiles": ["Grep", "Glob"],
    "problems": ["Read", "Bash"],
    "changes": ["Read", "Bash"],
    "testFailure": ["Bash"],
    "runCommands": ["Bash"],
    "editFiles": ["Edit", "Write"],
    "execute": ["Bash"],
    "read": ["Read"],
    "search": ["Grep", "Glob"],
    "edit": ["Edit", "Write"],
}

# 正文里残留的 Copilot 工具名引用（精确短语替换，先于通用 token 替换执行）
BODY_FIXUPS: list[tuple[str, str]] = [
    ("codebase／usages／Read", "Grep/Glob／Read"),
    ("codebase／searchResults", "Grep/Glob"),
    ("用 codebase 搜索与 read 读出", "用 Grep/Glob 搜索与 Read 读出"),
    ("用 codebase／runCommands 验证或排除", "用 Grep/Glob、Bash 验证或排除"),
    ("runCommands", "Bash"),
    ("editFiles", "Edit/Write"),
]

# 末项可能无换行（frontmatter 捕获会把列表最后一行的 \n 留给 --- 分隔符），故末行 \n 可选
TOOLS_RE = re.compile(r"^(tools:\n(?:  - .+\n)*  - .+\n?)", re.MULTILINE)
DESC_TOOLS_RE = re.compile(r"\(Tools:[^)]*\)")


def parse_frontmatter(text: str) -> tuple[str, str] | None:
    """拆出 YAML 头与正文；无头或头内无顶层 tools: 时返回 None。"""
    m = re.match(r"\A---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return None
    return m.group(1), text[m.end():]


def rewrite(text: str) -> tuple[str, list[str], list[str]]:
    """返回（新文本, 改写条目, 保留的未知条目）。无 tools: 则原样返回。"""
    parsed = parse_frontmatter(text)
    if parsed is None:
        return text, [], []
    fm, body = parsed
    m = TOOLS_RE.search(fm)
    if not m:
        return text, [], []

    old = [ln.strip().lstrip("- ").strip().strip('"').strip("'")
           for ln in m.group(1).splitlines()[1:]]
    mapped: list[str] = []
    kept: list[str] = []
    mcp_converted: list[str] = []
    for name in old:
        if name in COPILOT_TO_KIMI:
            for t in COPILOT_TO_KIMI[name]:
                if t not in mapped:
                    mapped.append(t)
        elif name in KNOWN_TOOLS:
            if name not in mapped:
                mapped.append(name)
        elif name.startswith("mcp__"):
            if name not in mapped:
                mapped.append(name)  # Kimi Code MCP 工具名（mcp__<server>__<tool>），合法
        elif re.fullmatch(r"[\w-]+/[\w-]+", name):
            # Copilot 的 server/tool 写法 → Kimi Code 的 mcp__<server>__<tool>
            t = "mcp__" + name.replace("/", "__", 1)
            if t not in mapped:
                mapped.append(t)
                mcp_converted.append(f"{name} → {t}")
        else:
            kept.append(name)  # 其余无法识别的名字，原样保留

    new_list = "".join(f"  - {t}\n" for t in mapped + kept)
    fm = fm[: m.start()] + "tools:\n" + new_list + fm[m.end():]
    # description 里的 (Tools: ...) 括注同步成新名单
    desc_line = next((ln for ln in fm.splitlines() if ln.startswith("description:")), "")
    if "(Tools:" in desc_line:
        new_desc = DESC_TOOLS_RE.sub(f"(Tools: {', '.join(mapped + kept)})", desc_line, count=1)
        fm = fm.replace(desc_line, new_desc, 1)
    # 正文残留引用
    for old_s, new_s in BODY_FIXUPS:
        body = body.replace(old_s, new_s)
    fm = fm.rstrip("\n")  # new_list 自带尾换行，末项可选换行也可能已被吃掉，统一去掉再补
    return (f"---\n{fm}\n---\n{body}",
            [f"{o} → {'/'.join(COPILOT_TO_KIMI[o])}" for o in old if o in COPILOT_TO_KIMI] + mcp_converted,
            kept)


def validate(path: Path) -> list[str]:
    """返回未知工具名列表（空 = 通过）。"""
    parsed = parse_frontmatter(path.read_text(encoding="utf-8"))
    if parsed is None:
        return []
    fm, _ = parsed
    m = TOOLS_RE.search(fm)
    if not m:
        return []
    names = [ln.strip().lstrip("- ").strip().strip('"').strip("'")
             for ln in m.group(1).splitlines()[1:]]
    return [n for n in names if n not in KNOWN_TOOLS and not n.startswith("mcp__")]


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--fix"]
    fix = "--fix" in sys.argv
    target = Path(args[0]) if args else Path(__file__).resolve().parent.parent / "agents" / "universal"
    files = sorted(target.glob("*.agent.md"))
    if not files:
        print(f"未找到 .agent.md：{target}")
        return 1

    bad = 0
    for f in files:
        text = f.read_text(encoding="utf-8")
        if fix:
            new, changed, kept = rewrite(text)
            if new != text:
                f.write_text(new, encoding="utf-8")
                print(f"✔ {f.name}")
                for c in changed:
                    print(f"    {c}")
                for k in kept:
                    print(f"    ⚠ 保留无法识别条目：{k}（若是 MCP 工具，请核对运行时实际工具名）")
        else:
            unknown = validate(f)
            if unknown:
                bad += 1
                print(f"✘ {f.name}: 未知工具名 {unknown}")
            else:
                print(f"✔ {f.name}")
    if not fix and bad:
        print(f"\n{bad} 个文件的 tools 白名单含未知工具名，加 --fix 修复")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
