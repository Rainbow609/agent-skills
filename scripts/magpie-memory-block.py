#!/usr/bin/env python3
"""Render magpie's injected Memory block from the memory store's md files (source of truth)."""
import re, sys, pathlib

STORE = pathlib.Path.home() / ".config/magpie/memory"
TARGETS = [pathlib.Path.home() / ".claude/CLAUDE.md",
           pathlib.Path.home() / ".codex/AGENTS.md",
           pathlib.Path.home() / ".omp/agent/AGENTS.md"]
KIND_HEADER = {"preference": "Preferences:", "rule": "Rules:", "fact": "Facts:"}
KIND_ORDER = ["preference", "rule", "fact"]
CAP = 400
INTRO = ("\n\nWhat is known from earlier conversations with the user. Follow it unless the user says "
         "otherwise now. The project's own instruction files (AGENTS.md and the like) and docs come "
         "first: where a memory disagrees with them, follow the project's files and tell the user "
         "which memory is out of date. A rule or fact of one project belongs in that project's files; "
         "memory keeps what holds for the user across projects. When a memory_search tool is at hand, "
         "search it for more before asking the user again, and save what they ask to be remembered "
         "with memory_save.\n")


def parse(path):
    text = path.read_text()
    head, _, body = text.partition("\n---\n")
    meta, dirs = {}, []
    for raw in head.splitlines():
        line = raw.rstrip()
        m = re.match(r"^([a-z_]+): (.*)$", line)
        if m:
            val = m.group(2).strip().strip('"')
            if val.startswith("[") and val.endswith("]"):
                val = [t.strip() for t in val[1:-1].split(",") if t.strip()]
            meta[m.group(1)] = val
        d = re.match(r"^\s+- dir: (.*)$", line)
        if d:
            dirs.append(d.group(1).strip().strip('"'))
    meta["dirs"] = dirs
    meta["text"] = body.strip()
    return meta


def load():
    out = []
    for path in sorted(STORE.glob("m_*.md")):
        m = parse(path)
        if m.get("status") != "active" or m.get("kind") not in KIND_HEADER:
            continue
        scope = m.get("scope") or "global"
        group = None
        if scope.startswith("project:"):
            group = m["dirs"][-1] if m["dirs"] else scope[len("project:"):]
        out.append((group, m))
    return out


def line(m):
    text = " ".join((m.get("text") or "").split())
    if len(text) > CAP:
        text = text[:CAP].rstrip() + "…"
    why = " ".join((m.get("why") or "").split())
    return "- " + text + (f" (why: {why})" if why else "")


def well(kind, items):
    return KIND_HEADER[kind] + "\n" + "\n".join(line(m) for m in items) + "\n"


def render(entries):
    body = [INTRO]
    for kind in KIND_ORDER:
        items = sorted((m for g, m in entries if g is None and m["kind"] == kind),
                       key=lambda m: m.get("created", ""), reverse=True)
        if items:
            body.append("\n" + well(kind, items))
    proj = {}
    for g, m in entries:
        if g is not None:
            proj.setdefault(g, []).append(m)
    for folder in sorted(proj):
        body.append(f"\nWhen working in {folder}:")
        for kind in KIND_ORDER:
            items = sorted((m for m in proj[folder] if m["kind"] == kind),
                           key=lambda m: m.get("created", ""), reverse=True)
            if items:
                body.append(well(kind, items))
    return "\n".join(body)


def splice(text, block):
    i = text.index("## Memory")
    j = text.index("<!-- magpie:end -->", i)
    return text[:i] + "## Memory" + block.rstrip("\n") + "\n\n" + text[j:]


def main():
    block = render(load())
    if "--dry-run" in sys.argv:
        print("## Memory" + block)
        return
    for p in TARGETS:
        old = p.read_text()
        if "## Memory" not in old or "<!-- magpie:end -->" not in old:
            print(f"no memory block in {p}, skipped")
            continue
        new = splice(old, block)
        if new == old:
            print(f"unchanged {p}")
            continue
        bak = pathlib.Path("/tmp/mem-block-bak") / p.name
        bak.parent.mkdir(parents=True, exist_ok=True)
        bak.write_text(old)
        p.write_text(new)
        print(f"rewrote {p}")


if __name__ == "__main__":
    main()
