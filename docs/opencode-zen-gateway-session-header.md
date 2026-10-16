# opencode Go 网关的 x-opencode-session 会话头

> 适用前提：把 opencode Go（OpenAI 兼容端点 `https://opencode.ai/zen/go/v1`，官方 docs 另列
> `/inference/go/...` 族）接给**只能配 BASE_URL / API_KEY / MODEL 三件套、不能配自定义请求头**的
> 本地工具（MCP server、原生二进制、闭源 CLI 等）。
> 本文为 2026-10-16 实测：curl 实打 + `codegenie-mcp-server`（Mach-O）strings 分析 + 官方
> `docs/go` 页口径，非训练记忆。网关行为可能变化，引用前先跑一遍「判定流程」。

## 现象

请求返回 400，鉴权正确也拦：

```
{"type":"error","error":{"type":"MissingSessionID","message":"Request is missing x-opencode-session and cannot be routed efficiently. Please see https://opencode.ai/docs/go/#where-can-i-use-it"}}
HTTP_STATUS:400
```

## 硬事实

1. **网关强制要求 `x-opencode-session` 请求头**，缺失即 400，与 key 是否有效无关。
2. **无豁免端点**：`/zen/go/v1`、`/inference/go/openai/v1`、`/inference/go/v1` 三条路径实测全部拦截；
   官方 docs 未描述该族之外的任何 base URL。
3. **头的值任意稳定字符串即可**（实测 `manbo-verify-ui-test` 直接 200）。官方动机：同一会话固定
   同一 id 供路由优化与 prompt caching；且声明对流量做滥用监控——不要每次随机换值。
4. **谁天然能过**：官方 docs 口径，Go 能识别部分客户端的原生会话头（ZCode、Claude Code、Codex）；
   已知有问题的客户端清单：DeepSeek Harness、GitHub Copilot Chat、Kimi Code、MiMo Code。
5. **谁过不了**：只发标准 OpenAI 头（Authorization / Content-Type）的实现。实例：
   `@deveco-codegenie/mcp` 的 `codegenie-mcp-server` 是 Mach-O 原生二进制，LLM 配置只有
   `UI_VERIFY_BASE_URL / UI_VERIFY_API_KEY / UI_VERIFY_MODEL_NAME` 三件套（兜底别名 `RC_*`），
   strings 分析确认无任何自定义头配置点——端点拼接写死为 `baseURL + "/chat/completions"`。

## 判定流程（30 秒定方案）

```bash
# ① 不带头打：400 MissingSessionID → 有头墙；200 → 不用折腾
curl -sS https://opencode.ai/zen/go/v1/chat/completions \
  -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
  -d '{"model":"<model>","messages":[{"role":"user","content":"say OK"}],"max_tokens":200}'

# ② 带任意稳定字符串头再打：200 → 确认缺头是唯一障碍
#    追加 -H "x-opencode-session: any-stable-id"

# ③ 看你的工具能否配自定义请求头：能 → 直接配头收工；不能 → 下一节代理
```

## 通用解法：本地会话头注入代理

约 40 行、无第三方依赖的 node（≥18）转发脚本，唯一职责 = 注入 `x-opencode-session` 后原样转发：

```javascript
// ~/.local/bin/opencode-session-proxy.js
// 🌟 上游含 /zen/go 前缀：代理收到的 /v1/chat/completions 原样拼接即成完整上游 URL
const http = require("http");
const { Readable } = require("node:stream");

const PORT = parseInt(process.env.PROXY_PORT || "8787", 10);
const UPSTREAM = process.env.PROXY_UPSTREAM || "https://opencode.ai/zen/go";
const SESSION_ID = process.env.PROXY_SESSION_ID || "my-agent-session";

const HOP_BY_HOP = new Set(["host", "connection", "content-length", "transfer-encoding", "keep-alive", "upgrade"]);

http.createServer(async (req, res) => {
  try {
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const body = Buffer.concat(chunks);
    const headers = {};
    for (const [k, v] of Object.entries(req.headers)) {
      if (!HOP_BY_HOP.has(k.toLowerCase())) headers[k] = v;
    }
    headers["x-opencode-session"] = SESSION_ID;
    const upstream = await fetch(UPSTREAM + req.url, {
      method: req.method,
      headers,
      body: body.length ? body : undefined,
    });
    const outHeaders = {};
    upstream.headers.forEach((v, k) => {
      if (!HOP_BY_HOP.has(k.toLowerCase())) outHeaders[k] = v;
    });
    res.writeHead(upstream.status, outHeaders);
    if (upstream.body) Readable.fromWeb(upstream.body).pipe(res);
    else res.end();
  } catch (e) {
    res.writeHead(502, { "content-type": "application/json" });
    res.end(JSON.stringify({ proxy_error: String(e) }));
  }
}).listen(PORT, "127.0.0.1", () => {
  console.log(`opencode-session-proxy on 127.0.0.1:${PORT} -> ${UPSTREAM} (session=${SESSION_ID})`);
});
```

macOS launchd 常驻（KeepAlive 崩溃自动拉起；`node` 建议写绝对路径，launchd 的 PATH 很瘦）：

```xml
<!-- ~/Library/LaunchAgents/com.rainbow.opencode-session-proxy.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.rainbow.opencode-session-proxy</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/node</string>
    <string>/Users/<you>/.local/bin/opencode-session-proxy.js</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/opencode-session-proxy.log</string>
  <key>StandardErrorPath</key><string>/tmp/opencode-session-proxy.err</string>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.rainbow.opencode-session-proxy.plist
# 验证：经代理打一发，200 即通
curl -s http://127.0.0.1:8787/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -d '{"model":"<model>","messages":[{"role":"user","content":"say OK"}]}'
# 卸载
launchctl bootout gui/$UID/com.rainbow.opencode-session-proxy
rm ~/.local/bin/opencode-session-proxy.js ~/Library/LaunchAgents/com.rainbow.opencode-session-proxy.plist
```

工具侧照常配三件套，BASE_URL 指代理即可（代理不碰 key，只加会话头，key 原样透传）：

```
BASE_URL = http://127.0.0.1:8787/v1    # 工具自己拼上 /chat/completions
```

## 实战案例：@deveco-codegenie/mcp 的 verify_ui

`~/.zcode/cli/config.json` → `mcp.servers.deveco-codegenie.env`：

| 变量 | 值 | 说明 |
| --- | --- | --- |
| `UI_VERIFY_BASE_URL` | `http://127.0.0.1:8787/v1` | 指向本地注入代理 |
| `UI_VERIFY_API_KEY` | opencode Go 的 key | 🌟 密钥只落本机 config.json，不入任何仓库 |
| `UI_VERIFY_MODEL_NAME` | `deepseek-v4.1-flash` | 视觉判定类任务优先带视觉的模型 |

🌟 **install.sh 覆盖坑**：agent-skills 的 `install.sh` 用 `mcp/zcode-mcp.json` 对 config.json 做
按 server 合并——同名 server 条目**整体替换**（env 全量覆盖）。重跑 install.sh 后必须把
`UI_VERIFY_*` 三个变量补回 config.json，否则 verify_ui 退回「环境变量未设置」报错。

🌟 改 env 后必须重启会话（MCP server 进程随会话拉起，不热加载）。

## 备选路线

- **换端点**：接一个无头要求的标准 OpenAI 兼容服务，三件套直配，零基础设施。
- **MCP sampling**：codegenie 检测到宿主具备 `sampling.tools` 能力且未配 key 时，自动
  `Setting up SamplingOpenAI` 走宿主模型（宿主的原生会话头天然合规）。依赖宿主支持，当前
  ZCode 未暴露该能力，故现实路线仍是代理。
