#!/usr/bin/env python3
"""Project EverOS user profiles into one Magpie Memory digest (idempotent).

EverOS keeps the ledger (episodes, atomic facts, per-project ``user_profile``).
Magpie keeps the short digest that every agent loads at session start. This
script is the one-way bridge: it reads the profiles from the EverOS HTTP API
and upserts a single ``profile`` memory in Magpie Memory, tagged
``everos-profile-digest``.

    everos-profile-digest.py            # update the digest
    everos-profile-digest.py --dry-run  # print the text, touch nothing
    everos-profile-digest.py --print-id # print the memory id it wrote

Both sides speak JSON over localhost; no agent, no MCP client library needed.
Secrets: none. Run by ``~/Library/LaunchAgents/local.magpie.profile-digest.plist``
nightly, or by hand.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

EVEROS_URL = "http://127.0.0.1:8000"
MCP_URL = "http://127.0.0.1:3425/mcp/magpie/memory"
USERS_DIR = Path.home() / ".everos/default_app/default_project/users"

TAG = "everos-profile-digest"
MARKER = "EverOS profile 自动投射"  # identifies the digest entry
KIND = "preference"
SCOPE = "global"
MAX_TEXT = 320
MAX_FACT = 80
MAX_TRAITS = 3
MIN_TRAIT_EVIDENCE = 5


def log(msg: str, *, quiet: bool = False) -> None:
    if not quiet:
        print(msg, file=sys.stderr)


def post_json(url: str, payload: dict, timeout: float = 20.0) -> dict:
    body = json.dumps(payload, ensure_ascii=False).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


def rpc(method: str, params: dict | None = None) -> dict:
    """One JSON-RPC call to the Magpie Memory MCP endpoint.

    The endpoint answers as an SSE stream; the reply is the ``data:`` line
    carrying our id (other ids belong to the client's own ``roots/list``).
    """
    payload: dict = {"jsonrpc": "2.0", "id": 1, "method": method}
    if params is not None:
        payload["params"] = params
    body = json.dumps(payload, ensure_ascii=False).encode()
    req = urllib.request.Request(
        MCP_URL,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30.0) as resp:
        raw = resp.read().decode()
    # jsonrpsee may answer with JSON or with an SSE stream; handle both.
    for chunk in raw.splitlines():
        chunk = chunk.strip()
        if not chunk or chunk.startswith(("event:", "id:", ":")):
            continue
        if chunk.startswith("data:"):
            chunk = chunk[5:].strip()
        try:
            msg = json.loads(chunk)
        except json.JSONDecodeError:
            continue
        if isinstance(msg, dict) and msg.get("id") == 1:
            if "error" in msg:
                raise RuntimeError(f"MCP error: {msg['error']}")
            return msg.get("result", {})
    raise RuntimeError(f"no JSON-RPC reply in MCP response: {raw[:300]!r}")


def tool_text(result: dict) -> str:
    return "\n".join(
        part.get("text", "") for part in result.get("content", []) if isinstance(part, dict)
    )


def user_ids() -> list[str]:
    if not USERS_DIR.is_dir():
        raise SystemExit(f"EverOS users dir not found: {USERS_DIR}")
    return sorted(p.name for p in USERS_DIR.iterdir() if p.is_dir() and not p.name.startswith("."))


def fetch_profile(user_id: str) -> dict | None:
    resp = post_json(
        f"{EVEROS_URL}/api/v2/memory/get",
        {"user_id": user_id, "memory_type": "profile", "page_size": 1},
    )
    profiles = resp.get("data", {}).get("profiles") or []
    if not profiles:
        return None
    return profiles[0].get("profile_data") or {}


def shorten(text: str, limit: int) -> str:
    text = re.sub(r"\s+", " ", str(text)).strip()
    text = text.rstrip("。．.；;，, ")
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


PUNCT = re.compile(r"[\s。．.，,；;：:、]+")


def norm(text: str) -> str:
    return PUNCT.sub("", str(text))


def merge_facts(facts: list[str]) -> list[str]:
    """Collapse facts that restate each other, keeping the longer wording.

    Profiles store the same statement twice (``summary`` and the
    ``explicit_info`` entry it was condensed from), so containment on
    punctuation-stripped text is enough — no fuzzy matching needed.
    """
    kept: list[str] = []
    for fact in facts:
        key = norm(fact)
        if not key or any(key in norm(k) for k in kept):
            continue
        kept = [k for k in kept if norm(k) not in key]
        kept.append(fact)
    return kept


def build_digest(today: str) -> tuple[str, int]:
    users: list[tuple[str, dict]] = []
    for uid in user_ids():
        profile = fetch_profile(uid)
        if not profile:
            log(f"  {uid}: no profile, skipped")
            continue
        users.append((uid, profile))

    if not users:
        raise SystemExit("no EverOS profiles found — nothing to project")

    multi = len(users) > 1
    facts: list[str] = []
    traits: list[str] = []
    for uid, profile in users:
        for item in profile.get("explicit_info") or []:
            desc = shorten(item.get("description") or "", MAX_FACT)
            if desc:
                facts.append(f"{uid}：{desc}" if multi else desc)
        if profile.get("summary"):
            facts.append(f"{uid}：{shorten(profile['summary'], MAX_FACT)}" if multi
                         else shorten(profile["summary"], MAX_FACT))
        for trait in profile.get("implicit_traits") or []:
            name = str(trait.get("trait") or "").strip()
            strong = len(trait.get("evidence") or []) >= MIN_TRAIT_EVIDENCE
            if name and strong and name not in traits:
                traits.append(name)

    merged = merge_facts(facts)
    traits = traits[:MAX_TRAITS]

    head = f"{MARKER}（{today}）："
    tail = ("。证据充分的习惯：" + "、".join(traits) + "。") if traits else "。"
    budget = MAX_TEXT - len(head) - len(tail)
    body, kept = [], 0
    for fact in merged:
        piece = ("；" if kept else "") + fact
        if len("".join(body)) + len(piece) > budget:
            break
        body.append(piece)
        kept += 1
    if not body:
        raise SystemExit("profile has no facts to project")
    return head + "".join(body) + tail, kept


def find_existing() -> str | None:
    result = rpc(
        "tools/call",
        {
            "name": "memory_search",
            "arguments": {"query": MARKER, "tags": [TAG], "limit": 10},
        },
    )
    for line in tool_text(result).splitlines():
        if "[" in line and "]" in line:
            ident = line[line.index("[") + 1 : line.index("]")]
            if ident.startswith("m_"):
                return ident
    return None


def main(argv: list[str]) -> int:
    global EVEROS_URL, MCP_URL
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true", help="print the digest, write nothing")
    ap.add_argument("--print-id", action="store_true", help="print the memory id written")
    ap.add_argument("--everos", default=EVEROS_URL)
    ap.add_argument("--mcp", default=MCP_URL)
    args = ap.parse_args(argv)

    EVEROS_URL, MCP_URL = args.everos.rstrip("/"), args.mcp

    text, n_traits = build_digest(dt.date.today().isoformat())
    if args.dry_run:
        print(text)
        log(f"(dry run: {len(text)} chars, {n_traits} facts)")
        return 0

    existing = find_existing()
    arguments: dict = {
        "text": text,
        "kind": KIND,
        "scope": SCOPE,
        "tags": [TAG, "auto"],
        "why": "由 scripts/everos-profile-digest.py 每晚从 EverOS profile 投射，勿手工编辑",
    }
    if existing:
        arguments["id"] = existing
    result = rpc("tools/call", {"name": "memory_save", "arguments": arguments})
    reply = tool_text(result)
    if result.get("isError"):
        raise SystemExit(f"memory_save failed: {reply}")
    log(f"{'updated' if existing else 'created'} digest ({len(text)} chars, {n_traits} facts): {reply}")

    if args.print_id:
        match = re.search(r"m_[0-9a-f]{12}", reply)
        print(match.group(0) if match else "")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (urllib.error.URLError, TimeoutError) as exc:
        log(f"cannot reach EverOS or Magpie: {exc}")
        sys.exit(1)
