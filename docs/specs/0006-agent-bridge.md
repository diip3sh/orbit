# Agent bridge

> Let coding agents (Claude Code, Codex, OpenCode, Cursor, Gemini CLI, Claude Desktop, Grok Build)
> record a web page with Reco from just its address. Built on the scripted web recordings of spec 0005.

## Why

Reco can render a scripted take of a web page, but a person has to build the script: pick targets,
place clips, press Render. An agent can do that from a sentence ("record apple.com, hover Buy, click
it, scroll to the specs"), if it can look at the page and drive Reco. Every agent listed supports
MCP over stdio, so one local MCP server covers all of them.

## Expected outcome

- **Settings → Agents** lists the agents found on the Mac, each with Connect, Disconnect or
  Reconnect, and shows whether the server is listening, how many agents are connected and the latest
  render.
- Connecting adds a server named `reco` to the agent's own settings; nothing else in them changes.
- Three MCP tools:
  - `inspect_page`: loads a page and lists its visible links, buttons, inputs and headings with
    selectors and boxes;
  - `record_page`: renders hovers, clicks and scrolls on that page into a movie with telemetry, and
    opens it in the editor;
  - `render_status`: follows a render that takes longer than an agent will wait.
  - `export_recording` (added by spec 0009): exports a take as MP4, MOV or GIF and returns the file's path.
  `record_page` also takes `type` steps and a `show` selector per cursor step, the element the video zooms on (spec 0009).
- The user gives a site address and asks to record it; the agent inspects, writes the steps, records
  and reports the movie's path. If Reco isn't running, the agent's `--mcp` process starts it.

## Research

### MCP Swift SDK

Sources: <https://github.com/modelcontextprotocol/swift-sdk> (`Package.swift`, `Package.resolved`, tag 0.12.1).

- Latest tag 0.12.1 (29 Apr 2026), `swift-tools-version:6.1`, macOS 13+.
- The `MCP` product links swift-system, swift-log and `eventsource`. swift-nio, swift-atomics,
  swift-collections and the docc plugin are for its executables and docs and aren't linked into the app.
- Server transports: `StdioTransport`, `NetworkTransport` (starts the connection itself and sends
  heartbeats, so not usable on an accepted connection), two HTTP transports without a listener, and
  `InMemoryTransport`. `Transport` is an actor protocol, so our own is a small actor.
- `Logging` isn't re-exported by `MCP`; `import Logging` works because swift-log is a resolved
  package of the target.

### Agents

| Agent | Config (home-relative) | Shape | Tool-call timeout |
|---|---|---|---|
| Claude Code | `~/.claude.json`, top-level `mcpServers` | `{"type":"stdio","command","args","env"}` | long |
| Codex CLI | `~/.codex/config.toml` | `[mcp_servers.<name>]` with `command`, `args`, `env` | 60 s default |
| OpenCode | `~/.config/opencode/opencode.json`, key `mcp` | `{"type":"local","command":[exe,…],"environment":{},"enabled":true}` | not documented |
| Cursor | `~/.cursor/mcp.json`, `mcpServers` | `{"command","args","env"}` | not documented |
| Gemini CLI | `~/.gemini/settings.json`, `mcpServers` | `{"command","args","env"}` | 600 s |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json`, `mcpServers` | `{"command","args","env"}`, stdio only | 60 s |
| Grok Build (`grok` CLI) | `~/.grok/config.toml` | `[mcp_servers.<name>]` with `command`, `args`, `env` | not documented |

Windsurf is left out: it was renamed Devin Desktop and its config path couldn't be verified.

## Approach

### Architecture

```
agent --stdio--> Reco --mcp  --Unix socket-->  Reco app (AgentBridgeServer + MCP Server per connection)
```

- The server is the main binary in `--mcp` mode (`RecoMain` dispatches before SwiftUI starts), so
  there is no second target. That process only pipes bytes: stdin to the socket and the socket to
  stdout. All MCP logic lives in the app.
- The socket is `~/Library/Application Support/com.diip3sh.Reco/agent.sock` (`URL.recoSupport`),
  found through the password database's home, not `$HOME`. The server creates the folder first. The
  path takes 61 bytes plus the user name, which fits a Unix socket's 104 for names up to about 40
  characters. No HTTP server and no TCP port. The app stopped being sandboxed on 2026-10-01 (spec 0007), so
  any process of the same user can reach the socket; the token is the guard.
- The first line a connection sends is the per-install token (`RECO_BRIDGE_TOKEN`, in the agent's
  `env`). A wrong one closes the connection; what was received is never logged. After it, newline-delimited
  JSON-RPC goes to a fresh SDK `Server`, with our own `AgentSocketTransport`.
- If the socket isn't there, `--mcp` starts Reco with `NSWorkspace.openApplication` (not activating)
  and retries every 250 ms for 20 s.

### Paths

No entitlements are needed (the app isn't sandboxed, spec 0007). The agents' settings are read and
written at their fixed home-relative paths (`AgentKind.configPath`). `CODEX_HOME`, `GROK_HOME`, XDG
variables and `OPENCODE_CONFIG` could now be followed, but aren't.

### Editing agents' settings

- Only the `reco` entry is touched, only for an installed agent (file or folder exists), and nothing is
  created for an uninstalled one. Contents are never logged.
- JSON: `JSONSerialization`, then written sorted and pretty, so key order changes. Files with comments
  don't parse and are refused (`notPlainJSON`) rather than rewritten. A non-object top level or servers
  value is refused. Foundation reads trailing commas as plain JSON (measured on macOS 27), so those
  are normalised away.
- TOML (Codex, Grok): line-based. Our `[mcp_servers.reco]` table and sub-tables are replaced where they
  are, or appended after a blank line. Dotted keys, inline tables and `reco` keys under `[mcp_servers]`
  are refused. Everything else stays byte for byte.
- Writes go to a temporary file next to the target (`.<name>.reco-<UUID>`, so on the same volume), then
  `rename(2)` over the target, keeping its permissions (0600 for a new file, since it holds the
  token). Symbolic links are refused.
- Connecting from a translocated copy is refused: its path changes on every launch.

### Tools

Errors are returned as `isError` text for the model to act on; only protocol failures throw.

1. `inspect_page` `{url, viewport?}` returns `{title, url, viewport, page_height, elements[{selector, role, text, box}], truncated}`
   in page CSS pixels at scroll 0. At most 200 elements; selectors are the ones pick mode makes
   (`WebPickScript.selectorFunctions`). A password's or checkbox's value is never used as text.
2. `record_page` `{url, viewport?, scale?, duration?, steps[{action, selector?, y?, start?, duration?}]}`
   returns a `RenderStatus {render_id, status, progress, movie?, telemetry?, unmatched_selectors?, warnings?, error?}`.
   Steps without a start follow the previous one by 0.8 s (first at 1 s); the take ends 1.5 s after the
   last step, at most 120 s (spec 0008 changed these from 0.5, 0.5 and 1, and added `warnings`). Same-lane overlaps are errors; a hover may overlap a scroll. A scroll to a
   selector brings it near the top, leaving 15% of the viewport above it (a guess for sticky headers,
   not measured).
3. `render_status` `{render_id}` waits and reports the same.

Limits:

- `record_page` and `render_status` wait at most 45 s and then return `status: rendering` with the
  progress, so they stay under the 60 s tool timeout of Codex and Claude Desktop; the agent asks again.
  There are no progress notifications.
- `inspect_page` gives up after 40 s.
- One render at a time: a second `record_page` while one runs is an immediate error naming the running
  `render_id`. Only the latest render is remembered.

## Phases

1. **Core** (done): requests, plans, config editors, token, line buffer, catalog, with tests.
2. **Server** (done): socket, transport, tools, `--mcp` client, inspect and take reuse of the web renderer.
3. **Settings** (done): Settings → Agents.
4. **Later:** Windsurf; a TOML parser; cancelling an agent's render; progress notifications; screenshots
   or element crops back to the agent; copy fallback across volumes.

## Verify

- Unit tests: `AgentJSONConfigTests`, `AgentTOMLConfigTests`, `AgentKindTests`, `AgentTokenTests`, `LineBufferTests`,
  `RecordPageRequestTests`, `RecordPlanTests`, `AgentToolCatalogTests`, `AgentConfigStoreTests`,
  `AgentToolsTests` (a refused page fails the render with a reason; status; no blocking after a failure).
- `WebPageRendererTests`: `inspect` on local pages (roles, text, boxes, hidden elements, the 200 limit).
- `AgentBridgeServerTests`: the test host is Reco, so its server listens on the real socket. A client
  sends the token, `initialize`, `notifications/initialized` and `tools/list` and gets the three tools;
  a wrong token gets the connection closed; bad calls come back as error texts; the socket path fits 104 bytes.
- `AgentBridgeClientTests`: the real `--mcp` process (another copy of the test host) lists the three
  tools over the host's socket and ends with its stdin; without a token it exits 1 and points to Settings → Agents.
- By hand, with a signed build:
  - Settings → Agents shows each installed agent; Connect, restart the agent, then `claude mcp list`,
    Codex `/mcp`, `grok mcp doctor`, Cursor's MCP settings.
  - Ask an agent to inspect and record apple.com: the movie opens in the editor.
  - Disconnect keeps the agent's other servers.
  - With Reco quit, the agent's first tool call starts it.

## Open questions

1. **Gatekeeper:** agents run Reco's binary directly. Does an un-notarized build run on another Mac?
2. **LaunchServices:** if it treats a `--mcp` process as Reco already running, launching needs
   `createsNewApplicationInstance`.
3. **Concurrent writes:** a running Claude Code rewrites `~/.claude.json`, so a connect may be lost.
   The UI says to restart the agent; Reconnect fixes it.
4. **Two renders:** the Web Recording window and agent renders aren't coordinated, and an agent's render
   can't be cancelled except by quitting.
5. **Tests take over the socket:** the test host's app listens on `agent.sock` and takes it from a
   running Reco; harmless, but the running copy stops serving until relaunched.
