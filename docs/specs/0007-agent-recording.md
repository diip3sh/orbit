# Agent recording

> Record a web page by typing its address and what the video should show into a Spotlight-style bar.
> Reco runs a coding agent (Claude Code, Codex, OpenCode, Gemini CLI, Grok Build, Cursor) headlessly
> on it, which records the page through the agent bridge of spec 0006 and opens the result in the editor.

## Why

Spec 0006 lets an agent record a page, but only when the user starts the agent and asks it. Web
recording then has two ways in: **manual** (the Web Recording window of spec 0005, where you place
clips yourself) and **with an agent**, where you say what you want and wait. The second needs no
terminal and no knowledge of selectors: address, a sentence, Return.

## Expected outcome

- **Record with AI Agent…** in the menu bar, and a global shortcut (Settings → Shortcuts → Web Recording,
  no default), open a bar near the top of the screen under the pointer, like Spotlight. Two fields:
  the website address and a description of the video. Below them: an agent picker, a model picker
  and **Record**.
- Return runs it. ⌥Return adds a line to the description. Esc, or a click anywhere else, closes the
  bar; a run carries on without it.
- While it runs, the bar's footer reads "Claude Code is recording… 42%" with Cancel, and the menu bar
  shows a sparkle with "AI", then the render's percent. The menu offers **Cancel Agent Recording**.
- When the render finishes the editor opens with the movie (the bridge does that already).
- On failure the bar shows why, with **Retry**, and a notification says the same (Retry again, and a
  click opens the bar in its failed state). The bar never reopens by itself.
- Only agents Reco found connected (spec 0006) with a command line on the login shell's `PATH` are
  offered; Claude Code and Cursor need only the command line, since their runs bring Reco's server
  (spec 0008). Without one, the bar says what to do and has **Set Up Agents…**, which opens Settings → Agents.

## Decision: remove the App Sandbox (2026-10-01)

Why:

- Agent command lines need the user's environment: their `PATH` (nvm, Homebrew, `~/.local/bin`),
  their logins and settings, their keychain items. A sandboxed parent's children inherit the
  sandbox, so a sandboxed Reco could not run `claude` as the user does.
- The sandbox already needed `temporary-exception` entries for seven agents' files, which grow with
  every agent supported.

What changed:

- `ENABLE_APP_SANDBOX = NO` (Debug and Release); `ENABLE_USER_SELECTED_FILES` is gone.
- `Reco.entitlements` keeps only `device.audio-input` and `device.camera` (the hardened runtime
  needs them). Gone: the app sandbox, user-selected files, movies and pictures, `network.client`, both
  home-relative exception lists, Sparkle's mach-lookup exception and the audio analytics one.
- `Info.plist` loses `SUEnableInstallerLauncherService`, which is for sandboxed apps only.
- Paths: `URL.userHome` (from `getpwuid`, which ignores `$HOME`) and `URL.recoSupport`
  (`~/Library/Application Support/com.diip3sh.Reco`), which holds `WebScript.json` and `agent.sock`.
  Recordings still go to `~/Movies/Reco` and screenshots to `~/Pictures/Reco`.
- `SettingsStore.setCustomOutputDirectory` and the stale-bookmark refresh used to give up when
  `startAccessingSecurityScopedResource()` returned false. Unsandboxed, a plain `NSOpenPanel` URL
  returns false, so "Change…" would silently do nothing. They now keep going whatever it returns.
- `ContainerMigration` runs once on the first launch with no settings of its own: it copies the old
  container's preferences (the agent token included, so connected agents keep working) into the
  defaults and its `Application Support` files (symbolic links skipped) into `recoSupport` where they
  are missing. It never deletes the container. If macOS refuses to let Reco read it, nothing is
  copied: settings start fresh and agents need Reconnect.
- The tests' `UserDefaults` suites come from `TemporaryDefaults`, named by a path in the temporary
  folder. Unsandboxed, the 592 `com.diip3sh.RecoTests.<UUID>.plist` files the suites left in the
  container would have gone to `~/Library/Preferences`; removing a plain-named suite doesn't help, since
  the preferences daemon writes its empty file back afterwards (measured: 62 per run).

What we gave up:

- The container's isolation. A bug in Reco, or in a page it renders, now reaches the user's files.
- The agent socket is reachable by any process of the same user (it was, by Reco's processes only).
  The per-install token, checked first on every connection, is the only guard.

## Research

Sources (2026-10-01): code.claude.com/docs/en/permissions, learn.chatgpt.com/docs/non-interactive-mode,
learn.chatgpt.com/docs/config-file/config-reference, learn.chatgpt.com/docs/models,
opencode.ai/docs/config/, /agents/, /permissions/, /mcp-servers/, geminicli.com/docs/reference/policy-engine,
geminicli.com/docs/cli/model, docs.x.ai/build/features/permissions, cursor.com/docs/cli/reference/permissions,
sparkle-project.org/documentation/sandboxing/, and the local `--help` of claude 2.1.286, opencode
1.18.7, gemini 0.52.0, grok 1.0.41 and cursor-agent. Codex isn't installed here, so its command is
untested.

### Running each agent headlessly

All of them run as a `Process` with the resolved absolute executable, arguments as an array (user text
never goes into a shell string), nothing on stdin, in an empty working folder
`recoSupport/AgentRun/` where the run's support files are written, with the login shell's environment.
The prompt always starts with "Record", so no command line can read it as a flag. In the table `[…]`
is only there when a model is chosen.

| Agent | Arguments | Why only Reco's tools run |
|---|---|---|
| Claude Code `claude` | `-p <P> --tools "" --allowedTools mcp__reco__* --permission-mode dontAsk --no-session-persistence [--model M] --output-format text` | `--tools ""` turns every built-in tool off; `dontAsk` denies what isn't pre-approved; the glob approves Reco's tools. `--tools` and `--allowedTools` take any number of values, so the prompt goes right after `-p`. |
| Codex `codex` | `exec --skip-git-repo-check --ephemeral --sandbox read-only -c mcp_servers.reco.default_tools_approval_mode="approve" [-m M] <P>` | `exec` never asks, so MCP calls are rejected unless the server's approval mode is `approve`; the shell stays read-only. The `-c` value is one argument, quotes included. |
| OpenCode `opencode` | `run [-m provider/model] <P>`, with `OPENCODE_CONFIG_CONTENT={"permission":{"*":"deny","reco_*":"allow"}}` | The inline config merges over the user's; the last matching rule wins; an MCP tool is `<server>_<tool>`. |
| Gemini CLI `gemini` | `--skip-trust --allowed-mcp-server-names reco --policy <W>/reco-policy.toml -o text [-m M] -p <P>` | The policy denies `*` at priority 100 and allows `mcpName = "reco"` at 200. |
| Grok Build `grok` | `-p <P> --permission-mode dontAsk --allow MCPTool(reco__*) --disable-web-search --no-subagents --output-format plain [-m M]` | `dontAsk` runs only what is pre-approved. Grok's read-only built-in tools stay (accepted). |
| Cursor `cursor-agent` | `-p --trust --approve-mcps --output-format text [--model M] <P>`, plus `<W>/.cursor/cli.json` | The workspace's `cli.json` allows exactly the three Reco tools and denies `Shell(*)`, `Write(**)` and `WebFetch(*)`. |

Claude Desktop has no command line and isn't offered. All the arguments are built by one function,
`AgentInvocation.make`, so a CLI changing a flag is a change in one place.

### The login shell

An app started from the Dock has a minimal environment, without the user's `PATH`. Reco runs the user's
shell (`getpwuid(getuid()).pw_shell`, else `/bin/zsh`) with the constant arguments
`-l -i -c "printf '\n__RECO_ENV__\n'; /usr/bin/env -0"`, stdin on `/dev/null` and a 10 second limit, and
reads the NUL-separated `KEY=VALUE` pairs after the marker (what the startup files print before it is
ignored). Nothing the user typed is ever part of a shell command. Measured on this Mac: 0.86 s,
30 variables. Each agent's executable is found by walking that `PATH`. The environment is passed on
unchanged (OpenCode also gets its permission variable) and read again each time the bar opens, with
the last result shown meanwhile. If `-i` hangs on an unusual startup file, the limit makes it a clear
reason, and `-l` alone is the fallback.

### Models

`AgentModelCatalog` lists, as of 2026-10-01 (they go stale: refresh them from each CLI's own list
command): Claude Code `opus`, `sonnet`, `fable`; Codex `gpt-6-astra`, `gpt-6.1-sol`, `gpt-6-luna`;
Gemini `gemini-3-pro-preview`, `gemini-3-flash-preview`; Grok `grok-4.6`, `grok-4.5`. OpenCode wants
`provider/model` from the user's providers and Cursor's list is per account, so both only offer
Default. Every agent also has **Default**, which passes no model argument.

## Approach

```
panel --> AgentRecordingViewModel --> AgentProcess --> agent CLI --stdio--> Reco --mcp --socket--> AgentTools
                  ^                                                                                     |
                  +------------------ watches AgentTools.job (the render) ------------------------------+
```

- **Core** (`AgentRecording/Model`, pure): `AgentRecordingRequest` (the prompt), `AgentInvocation`,
  `AgentModelCatalog`, `AgentRunOutcome`, `OutputTail`, `LoginEnvironment`.
- **Service**: `AgentProcess` runs a command line with pipes, a time limit and cancellation. The
  output handlers only touch a `Mutex` around the last 16 KB; the result comes back through a
  continuation. A cancel or time-out sends SIGTERM, then SIGKILL after 3 s. On exit it reads what is
  left in the pipes without waiting for them to close, since a process the agent left running holds
  them open (`readToEnd()` would hang on it). Only the exit status and the duration are logged, never
  output.
- **View model**: `AgentRecordingViewModel` keeps the fields, the choice of agent and model (remembered),
  and the run's state. It never talks to the render itself: it reads `AgentTools.job`.
- **A run:** it remembers the bridge's latest render, loads the environment, writes the support
  files, runs the command with a 15 minute limit, and, if the agent exits while its render still goes
  on, waits for it. Then `AgentRunOutcome.classify` decides, in order:
  1. cancelled: cancelled;
  2. a new render is `done`: success, even if the agent exited badly (the editor has already opened,
     and Retry would record again);
  3. time-out: "The agent didn't finish within 15 minutes.";
  4. launch failure: its message;
  5. exit status other than 0: "Claude Code exited with status N: <last lines of output>";
  6. exit status 0 and a new render `failed`: the render's error;
  7. exit status 0 and no new render: "The agent finished without recording." and the output.

  A render is the run's when its id differs from the one that was there before. The reason is the last
  five lines of stderr (stdout if there is none) with colours removed, cut to the last 300 characters,
  with the bridge token replaced by "…".
- Cancel stops the command line only; a render it started carries on. Quitting the app cancels a run.

### UI

`AgentRecordingPanelController` shows a borderless, non-activating panel (`QuickAccessPanel`, which
takes key without activating Reco, so the app in front stays in front). `.floating`, on the active
Space and over full screen apps, dark appearance, the screen under the pointer, 600 pt wide, centred, its top
edge 22% of the way down. It closes when it loses key and on Esc. The SwiftUI view measures its own
height and the controller keeps the top edge fixed as it grows.

The view uses `EditorTheme` and `editorGlass` (Liquid Glass on macOS 26; a material and a hairline
before; solid `EditorTheme.stage` with Reduce Transparency). Rows: globe + address (`.title3`), a
hairline, the description (three lines), a hairline, an optional failure row, then the footer.

The apple-design skill's rules, as applied:

- **Respond at once:** the buttons light on press (`EditorButtonStyle`); Return and ⌥Return act on the
  keystroke; focus lands in the address, or in the description if the address is set.
- **Interruptible, symmetric motion:** the panel arrives and leaves the same way, fading and settling
  from 97% anchored at its top, with a spring without bounce (`.spring(duration: 0.3, bounce: 0)`). It
  is driven by one flag (`isPresented`), so a close during the entrance, or a reopen during the exit,
  turns round from where the panel is. The window itself isn't animated (`animationBehavior = .none`).
  The failure row and the running footer change with `editorMotion`.
- **Reduce Motion:** a 0.15 s cross-fade, no scaling. **Reduce Transparency:** solid ground.
  **Increase Contrast:** hairlines and the key hint in the dim tone.
- **Feedback:** status ("AI", then the percent, in the menu bar and the footer), completion (the
  editor opens), error (the bar, with Retry, and a notification), all without a modal. Cancel is always
  there while it runs.
- **Responsibility:** the agent can only use Reco's three tools (table above).
- **Labels:** direct ones ("Record with AI Agent…", "Cancel Agent Recording", "Set Up Agents…"); the
  pickers have titles for VoiceOver; buttons are at least 28 pt; Tab goes through the fields, the
  pickers and Record.
- **Menu bar:** the agent's state is one template image, a sparkle and text drawn at the width of
  "100%", so the status item's width never changes (the recording timer's technique, now shared).

## Phases

1. **Sandbox removal and migration** (done): project, entitlements, `Info.plist`, `URL+RecoPaths`,
   socket and script paths, `AgentConfigStore`'s temporary file next to the target, `SettingsStore`,
   `ContainerMigration`, `TemporaryDefaults`.
2. **Core** (done): request, invocation, catalog, outcome, output tail, login environment, with tests.
3. **Runner and view model** (done): `AgentProcess`, `AgentRecordingViewModel`, with tests that run
   real processes and fake the agent.
4. **Panel and menu** (done): the panel, menu entries, menu bar state, shortcut, notification.

## Verify

- Unit tests: `AgentRecordingRequestTests`, `AgentInvocationTests` (exact arguments of all six agents,
  with and without a model), `AgentModelCatalogTests`, `AgentRunOutcomeTests` (the seven rules),
  `OutputTailTests`, `LoginEnvironmentTests`, `ContainerMigrationTests`, `AgentProcessTests` (real
  `/bin/sh` and `/bin/sleep`: exit status and output, time-out, cancel, a missing executable, a
  process left holding the pipe), `AgentRecordingViewModelTests` (availability reasons, one run at a
  time, remembered choices, failure and Retry, the menu bar text), `AgentRecordingPanelControllerTests`,
  `AgentBridgeClientTests` (the `--mcp` process: now possible, since the host isn't sandboxed),
  `AgentBridgeServerTests` (the socket path fits 104 bytes).
- `TemporaryDefaults` leaves no `com.diip3sh.RecoTests.*` plist in `~/Library/Preferences` after a full run.
- Not covered by tests, by hand: the list below.
  - Update from the last sandboxed release: settings, shortcuts, custom folder, agents still
    Connected, permissions not asked again.
  - Choose a new output folder (Settings → General → Change…).
  - With each installed agent: the bar on example.com ("AI", then a percent in the menu bar; the
    editor opens). Ask an agent to run `ls ~` and see its shell tool denied.
  - Failures: an unreachable URL gives a notification with Retry; Cancel stops the command line; no
    stray `Reco --mcp` process remains.
  - The panel: Safari stays active, typing goes to the panel, Esc and a click away close it, Return
    and ⌥Return, a second display, a full screen Space, Reduce Motion, Reduce Transparency, Increase
    Contrast, VoiceOver, keyboard only, a picker menu opening without closing the panel.
  - Settings → Agents opens from "Set Up Agents…" (it sends `showSettingsWindow:`, the
    `openSettings` action being tied to a scene, which the panel has none of).
  - macOS 26 glass and the macOS 15 material.

## Open questions

1. **Exit statuses:** whether OpenCode and Grok exit non-zero when a tool call is denied or fails.
2. **Grok's read-only built-ins** stay available; there is no flag to turn them off.
3. **Cursor:** does it accept `Mcp(reco:*)`, and does it read the workspace `cli.json` from the
   working folder? If not, `AgentInvocation.executableName(for: .cursor)` returns `nil` and it is dropped.
4. **Other renders:** a render started by another agent at the same time is counted as this run's.
5. **Cancel:** a cancelled run's render keeps going, and blocks the next `record_page` until done.
6. **Rule 2** counts a finished render with a non-zero exit as a success.
7. **Codex** was not run (not installed).
8. **App Data protection:** if macOS asks the user to allow Reco to read the old container, the
   migration runs on a later launch only if the app still has no settings of its own.
