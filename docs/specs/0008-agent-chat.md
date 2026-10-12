# 0008 — Agent chat in the Web Recording window

Status: built 2026-10-02 (`feat/ui-polish`). Follows specs 0005 (web recordings), 0006 (agent bridge) and
0007 (agent recording).

## What

The Web Recording window's right column switches between **Inspector** and **Agent**, like an AI IDE's
side panel. The Agent tab is a chat with a coding agent about the window's page:

- The user describes the video; the agent records it with Reco's three MCP tools.
- The chat shows what the agent says and each tool it uses ("Looking at buildonto.dev", "Recording 6
  steps", "Rendering the video") as it happens, and the render's progress.
- While it works, the window shows it: the elements `inspect_page` found light up on the preview for 4 s,
  and the plan `record_page` made becomes the timeline (one undoable step, "Agent's Script") and plays
  once in the preview at its real pace while the render runs. Following the render itself lagged and
  jumped (it runs slower than real time and unevenly, and moved the live page on every tick).
- When it's done the clips stay: the user changes them and presses Render (takeover), or sends a
  follow-up ("slower scroll"), which continues the same agent conversation and records again.
- **AI Agent** in the toolbar opens the tab. The menu bar's floating bar still works, and its runs show in
  the chat too.

## How

| Piece | Where |
|---|---|
| Stream parsing, Claude Code and Cursor | `AgentRecording/Model/AgentStreamEvent.swift` |
| The chat's entries and the conversation ID | `AgentRecording/Model/AgentTranscript.swift` |
| Lines as they're printed | `AgentProcess.run(…, onOutputLine:)` (a `LineBuffer` per run) |
| Flags | `AgentInvocation`: Claude `--output-format stream-json --verbose`, Cursor `--output-format stream-json`, both `--resume <id>` for a follow-up |
| Follow-up prompt | `AgentRecordingRequest.resuming`, `prompt` ("Change the recording of …") |
| Chat intents | `AgentRecordingViewModel+Chat.swift`: `send(_:about:)`, `streamingTranscript`; `startNewChat()` |
| What the window shows | `AgentTools.onInspected` / `onPlanned` (wired in `AppDelegate`), `WebRecordingViewModel` `// MARK: - Agent` and `// MARK: - Playback`, `WebStage`'s `WebAgentHighlights` |
| Views | `AgentChatView`, `AgentChatRow`, `AgentChatComposer`; the tab in `WebRecordingView` |

The live canvas comes from Reco's own tools, not the agent's text, so it is exact for every agent. The
transcript comes from the agent's stream, so only agents that stream (Claude Code, Cursor) show steps;
the others still record, with only the request and the outcome in the chat.

## Measured

Stream formats were read from real runs on 2026-10-02 (Claude Code with Haiku, cursor-agent 2026.09.10,
both inspecting example.com); the test lines in `AgentStreamEventTests` are cut from them. Claude prints
hook events, `thinking` blocks and `rate_limit_event`s, all skipped; Cursor first looks a tool's schema up
(`getMcpToolsToolCall`), which isn't a call. `--verbose` is required for Claude's stream-json in print mode.

## Not yet

- Not yet tried by hand in the app: a full chat run, follow-ups, the live highlights and timeline.
- A plan adopted while the user has their own script replaces it (undo brings it back).
- Claude keeps its sessions now (no `--no-session-persistence`), so runs appear in `claude --resume`.
