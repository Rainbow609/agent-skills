# deveco-codegenie MCP 的 tools/list 并发丢包缺陷与本地 guard 修复

> 适用：以 stdio 接入 `@deveco-codegenie/mcp`（DevEco codegenie MCP，鸿蒙工具链封装）的任意 AI 客户端。
> 实测环境：2026-10-18，macOS arm64 + ZCode 0.16.9 + `@deveco-codegenie/mcp` 0.2.6（rmcp 0.12.0，Mach-O 原生二进制）。
> 上游状态：截至 2026-10-18 未见修复；npm `stable` 1.1.11 同缺陷且功能更少（见文末「版本注意」）。
> 文内结论均为实测（样本与命令在文中给出），非训练记忆。

## 症状

- 客户端日志：`MCP server deveco-codegenie tool listing timed out after 30000ms`——该 server 的工具一个都注册不上（ZCode 侧表现为全局工具数只统计到其他 server 的数量）。
- **单会话手工直连却完全正常**：initialize ≈0.2s，`tools/list` ≈0.1s，15 个工具全返回。
- 服务端日志（macOS：`~/Library/Application Support/codegenie-mcp-server/logs/`）停在
  `mcp/src-server/src/lib.rs:90 - IDE Info: <client> <ver>`，此后无任何输出（正常实例在 1ms 内会打印 roots 结果）。

## 根因

服务端收到 `initialize` 后，**由主线程用同步阻塞 read 等待自己发出的 `roots/list` 请求的响应**；该 read 与 rmcp 的 stdin 协议读取循环**竞争同一个管道**，谁先被唤醒谁拿到数据。客户端紧随 `notifications/initialized` 发出的 `tools/list` 一旦被同步 read 抢先取走，即被当作 roots 响应丢弃——该消息永久丢失，`tools/list` 永不响应。

触发条件：**并发多实例**（客户端每会话一个连接时高发）。触发率随并发规模上升——实测 8 并发 8/24（33%）、12 并发 6/12（50%）卡死；单实例 4/4 通过。

## 排查手法（可复用）

1. **并发隔离**：单实例正常、8 并发约 1/3 卡死 → 是竞争而非配置/环境问题。
2. **sample 抓栈**：`sample <pid> 3 -file out.txt`。卡死进程主线程 100% 停在 `read`，无 flock/信号量等待 → 排除锁竞争与网络假设。
3. **超时重发判性质**：30s 超时后重发同一 `tools/list`，0.05s 内成功 → **消息被吞（进程活着）**，不是死锁。实测重发 3/3 成功。
4. **延迟对照**：initialize 响应后延迟 500ms 再发仍卡 → 与发送时机无关，排除「初始化时序窗口」假设。
5. **模拟修复验证**：客户端先应答 roots 再发 tools/list → 0/8 卡死，反向确认竞争对象是 roots 往返。

## 与 MCP 配置的关系（易误判，实测隔离）

同一份配置下呈**概率性**（单实例 4/4、8 并发 33%、12 并发 50%），说明不是配置错误。但两个配置项确实影响触发概率与可用性：

| 配置项 | 实测事实 |
| --- | --- |
| `PROJECT_PATH`（可选 env） | 设了之后服务端**不再发 roots 请求**（单实例实测：日志 `project_path: Some(...)`，server→client 消息无 roots）。但**只降低不消除**：8 并发 8/8 侥幸全通、12 并发仍 3/12。且会把默认工程路径写死，多项目下 `build_project` 有指错工程的风险 → 不作修复方案 |
| `DEVECO_PATH` | 官方 README 的 macOS 示例值 `.../DevEco-Studio.app/Contents` 实测让 5 项工具链检测（SDK/Java/Node/Hvigor/Emulator）全部 not found（靠 `smart_find` 回退到 `.app` 兜住）；改为 `/Applications/DevEco-Studio.app` 后检测全绿。与卡死率无关（7/8 vs 8/8 同水平） |

## 本地修复：guard 代理（透明包装，约 180 行，仅标准库）

思路：拦截服务端发出的 `roots/list` 请求并**本地以 `-32601` 应答**（客户端 capabilities 无 roots 时与真实行为等价），把客户端在该应答被消费前发出的消息暂存，保证 FIFO 顺序上主线程的同步 read 只可能取到应答本身；另加读循环健康探测与兜底释放。对客户端完全透明（stdin/stdout 原样对接，stderr 直通，exit code 透传）。

安装：把客户端 MCP 配置的 `command` 从 `codegenie-mcp-server` 指向本脚本（env 不变），脚本内 `CODEGENIE_REAL_SERVER` 默认即原命令。

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""codegenie-mcp-guard — 修复 deveco-codegenie MCP server 的 tools/list 丢包缺陷。

【缺陷】服务端（@deveco-codegenie/mcp 0.2.6 / stable 1.1.11，rmcp 0.12.0）在收到
initialize 之后，会由主线程用同步阻塞 read 等待自己发出的 roots/list 请求的响应；
该 read 与 rmcp 的 stdin 协议读取循环竞争同一个管道。客户端紧随
notifications/initialized 发出的消息（典型是 tools/list）若被主线程的 read 抢先取走，
会被当作 roots 响应丢弃 → 服务端日志停在 `IDE Info`，此后 tools/list 永不响应
（ZCode 侧表现为 30s tool listing 超时、工具注册不全、codegenie 全部工具丢失）。
单实例不易触发；并发多实例（ZCode 每会话一个连接）实测约 25%~40% 概率触发。

触发条件（2026-10-18 实测）：未设环境变量 PROJECT_PATH 时，服务端才走 roots/list
协议向客户端取工程根目录；设了 PROJECT_PATH 则不再发 roots 请求。但 PROJECT_PATH
只是降低触发概率而非消除（8 并发侥幸 8/8，12 并发仍 3/12），且会把默认工程
路径写死在本机配置里。本 guard 不依赖 PROJECT_PATH，任何项目下都成立。

【修复】拦截服务端发出的 roots/list 请求，立即以 -32601 Method not found 本地应答
（ZCode 的 initialize capabilities 中 roots=None，等价于真实行为）；客户端在此应答
被消费前发出的消息先暂存，保证 FIFO 顺序上主线程的同步 read 只可能取到应答本身。
roots 请求不再转发给客户端。

【回滚】把客户端配置中的 command 改回 /opt/homebrew/bin/codegenie-mcp-server 即可。

环境变量：
  CODEGENIE_REAL_SERVER  真实服务端命令，默认 /opt/homebrew/bin/codegenie-mcp-server
  CODEGENIE_GUARD_GRACE  boot 阶段兜底释放秒数，默认 5（服务端未发 roots 时解锁）
  CODEGENIE_GUARD_DEBUG  置 1 时把拦截日志写 stderr
"""

import json
import os
import subprocess
import sys
import threading
import time

REAL = os.environ.get("CODEGENIE_REAL_SERVER", "/opt/homebrew/bin/codegenie-mcp-server")
GRACE = float(os.environ.get("CODEGENIE_GUARD_GRACE", "5"))
DEBUG = os.environ.get("CODEGENIE_GUARD_DEBUG") == "1"

PASS_THROUGH_IN_BOOT = {"initialize", "notifications/initialized"}


def dbg(*a):
    if DEBUG:
        print("[guard]", *a, file=sys.stderr, flush=True)


proc = subprocess.Popen(
    [REAL], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=None, bufsize=0
)

lock = threading.Lock()
state = {"phase": "boot"}  # boot → ready
held = []  # boot 阶段暂存的客户端原始行（bytes）
pong_seen = threading.Event()
PING_ID = 2026101800  # 探针专用 id，取大整数避免与客户端 id 冲突


def write_to_server(raw: bytes):
    try:
        proc.stdin.write(raw)
        proc.stdin.flush()
    except (BrokenPipeError, ValueError, OSError):
        pass


def release_held():
    with lock:
        pending, held[:] = list(held), []
    for raw in pending:
        dbg("release held:", raw[:80])
        write_to_server(raw)


def go_ready(because: str):
    with lock:
        if state["phase"] != "boot":
            return False
        state["phase"] = "ready"
    dbg("phase -> ready:", because)
    return True


def client_pump():
    """客户端 → 服务端。boot 阶段暂存非握手消息，避免抢在 roots 应答之前。"""
    for raw in sys.stdin.buffer:
        try:
            d = json.loads(raw)
            method = d.get("method") if isinstance(d, dict) else None
        except Exception:
            method = None
        if state["phase"] == "boot" and method not in PASS_THROUGH_IN_BOOT:
            with lock:
                if state["phase"] == "boot":
                    held.append(raw)
                    dbg("hold:", raw[:80])
                    continue
        write_to_server(raw)


def server_pump():
    """服务端 → 客户端。boot 阶段拦截 roots/list 请求并本地应答。"""
    for raw in proc.stdout:
        try:
            d = json.loads(raw)
        except Exception:
            d = None
        intercepted = False
        if isinstance(d, dict) and d.get("id") == PING_ID:
            pong_seen.set()  # 服务端读循环在正常处理请求 → 可以安全释放
            dbg("probe pong")
            intercepted = True  # 探针响应不下发给客户端
        elif (
            state["phase"] == "boot"
            and isinstance(d, dict)
            and d.get("method") == "roots/list"
            and "id" in d
        ):
            reply = json.dumps(
                {"jsonrpc": "2.0", "id": d["id"], "error": {"code": -32601, "message": "Method not found"}}
            ).encode() + b"\n"
            dbg("roots/list 拦截，本地应答 id=", d["id"])
            write_to_server(reply)  # 此刻管道里只有这条应答，主线程同步 read 必然取到它
            time.sleep(0.15)  # 留出同步 read 消费该应答的时间
            go_ready("roots answered")
            release_held()
            intercepted = True  # roots 请求不下发给客户端
        if not intercepted:
            sys.stdout.buffer.write(raw)
            sys.stdout.buffer.flush()
    # 服务端退出 → 收尾
    try:
        sys.stdout.buffer.flush()
    except Exception:
        pass


def grace_timer():
    """兜底：服务端未发 roots 请求时（版本差异）也要解锁，避免永久暂存。"""
    time.sleep(GRACE)
    if go_ready(f"grace {GRACE}s elapsed"):
        release_held()


def boot_probe():
    """读循环健康探测：若服务端能立即应答 ping，说明协议读取循环工作正常，
    暂存的消息可以安全释放（此时没有会吞消息的同步 read 在等）。"""
    time.sleep(0.6)  # 先给 roots 请求让路（正常路径 ~0.2s 内到达）
    if state["phase"] != "boot":
        return
    write_to_server(json.dumps({"jsonrpc": "2.0", "id": PING_ID, "method": "ping"}).encode() + b"\n")
    dbg("probe ping sent")
    if pong_seen.wait(1.0) and state["phase"] == "boot":
        if go_ready("ping pong: read loop healthy"):
            release_held()


t_client = threading.Thread(target=client_pump, daemon=True)
t_server = threading.Thread(target=server_pump, daemon=True)
t_grace = threading.Thread(target=grace_timer, daemon=True)
t_probe = threading.Thread(target=boot_probe, daemon=True)
t_client.start()
t_server.start()
t_grace.start()
t_probe.start()

t_server.join()  # 服务端结束即会话结束
try:
    proc.stdin.close()
except Exception:
    pass
try:
    proc.wait(timeout=3)
except Exception:
    proc.terminate()
sys.exit(proc.returncode if proc.returncode is not None else 0)
```

修复后的效果与实测：

- 正常路径（服务端发 roots）：守卫抢先本地应答 → 客户端 tools/list 0.16~0.22s 返回（拦截日志可见）；
- 异常路径（服务端未发 roots，主线程卡在别处）：`ping` 探测通过即 0.6s 释放，否则 5s 兜底释放——两条路径实测均成功；
- 最恶劣模式（客户端不回 roots、initialize 后立即发 tools/list）并发验收：**8 并发 8/8、12 并发 12/12**（对照无守卫时 33%~50% 卡死）；连测含 `PROJECT_PATH` 场景共 60+ 实例零卡死；
- 真实客户端（ZCode）热重连后工具数 46→61（该 server 15 个工具全量注册），`init_project_path` + `check_ets_files` 端到端返回真实 ArkTS 诊断。

## 版本注意

- 留在 **0.2.6**（npm 同时是 `latest` 与 `beta`）：默认 10 工具 + `ADDITIONAL_TOOL_GROUPS=ui_integration_test,emulator_manager` 追加 5 个（verify_ui / get_ui_verification_log / save_ui_screenshot / emulator_image_manager / emulator_instance_manager）。
- **不要升 1.1.11**（`stable`）：同缺陷，且仅 10 工具（丢 hilog 采集、知识库搜索、project_sync、两个 emulator 管理器），README 无 `ADDITIONAL_TOOL_GROUPS`——是功能收缩线。

## 给上游的反馈要点

- 同步 read 等 `roots/list` 响应与协议读循环抢管道 → 建议改为协议循环内按 id 匹配响应，或客户端 capabilities 声明无 roots 时直接跳过该请求。
- 复现：任意客户端并发 8 个 stdio 实例，各自 `initialize` → `notifications/initialized` → 立即 `tools/list`，约 1/3 实例无响应（同参数单实例必通）。
