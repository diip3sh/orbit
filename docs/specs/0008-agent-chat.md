# Agent chat and reliable web takes

> Talk to the agent from the editor: a web take opens with the conversation that made it, and
> "slower", "also click Buy" or "end on the footer" records it again with the change. Takes an agent
> writes are checked like Playwright checks its actions, and the problems go back to the agent.

## Why

Spec 0007 records a page from one sentence, but the result was final: changing anything meant
writing the whole request again in the panel, and the agent started from nothing. And takes went
wrong in ways nobody saw until watching them. Measured on a 60 s apple.com script (M5, macOS 26.5.2):

- **Targets out of view.** The agent scrolled to a heading, then clicked the gallery's dots 50 px
  below the viewport: the cursor clicked at y 945 of a 900 px view and nothing happened.
- **Blind clicks.** A selector that matched nothing (a banner's close button, already dismissed by a
  cookie) clicked the middle of the page instead, which opened another page; every later step
  missed.
- **Covered targets.** Hovering the iPhone menu left its flyout open (the cursor passed over it), and
  the next hover landed on the flyout, not the button under it.
- **Zooms that pop.** Auto-zoom timed a stop at its arrival only, so a 2.5 s hover got a 2 s zoom
  that left while the cursor still pointed; the editor's spring then trailed the scripted cursor
  by 160 ms, so hover effects showed before the drawn cursor arrived.
- **Agents not found.** Reco connects Claude Code in `~/.claude.json`; with `CLAUDE_CONFIG_DIR` set
  (this Mac) Claude reads another file, and the agent had no `reco` tools at all.
- **Unreachable pages.** On macOS 26.5 a refused connection commits `about:blank` and finishes
  instead of failing, so `http://localhost:1` "loaded" and rendered a blank take.

## Expected outcome

- A web take's editor has a **Style | Agent** switch at the top of the inspector. Agent shows the
  conversation (the user's messages on the right, the agent's replies, failures), how a run is going
  ("Looking at apple.com…", "Recording… 42%", Cancel), and a message box with the agent, the model
  and **Record** (↩ sends, ⌥↩ adds a line).
- Sending records the take again: the agent gets the take's steps, the conversation and the new
  message, changes only what was asked, and the window shows the new take, in the same canvas,
  cursor, click and keystroke style, with the conversation. The old take stays in the folder.
- A take made from the Record with AI Agent panel opens on the Agent side, its request and the
  agent's reply already there. A take recorded by hand in the Web Recording window has the chat too,
  starting empty.
- A failed chat run shows its reason and Retry in the chat (no notification); sending something else
  keeps the failed request in the conversation, so the agent knows what didn't work. Cancel puts the
  message back in the box.
- Claude Code (and Cursor) work from the panel and the chat without Settings → Agents, whatever their
  own settings say.

## Research

Sources (2026-10-02): playwright.dev/docs/actionability, /docs/locators, /mcp/snapshots,
pptr.dev/guides/page-interactions, browser-use's system prompt, Stagehand's observe service,
github.com/CapSoftware/Cap (recording.rs), getopenscreen/openscreen PRs 765 and 873,
syi0808/screenize (GenerationSettings.swift), ashrafchowdury/programatic-demo (camera.ts),
MacKenzie 1992 (Fitts's law for mice), code.claude.com/docs/en/headless and /cli-reference,
bugs.webkit.org 161450 and 198107, screenshotone.com/docs/options.

- **Actionability:** Playwright scrolls an element into view before acting, and acts only when it is
  visible, stable and *receives events* (the hit test at the point finds it, not an overlay).
- **Lazy content:** screenshot services scroll to the bottom and back before capturing.
- **Pacing:** Cap zooms 2× from 0.3 s before a click to 2.5 s after; Screenize fills 70% of the frame;
  programatic-demo opens on a 0.6 s wide shot and holds at least 1.3 s after a click. Fitts's law puts
  an 800 px mouse move to a 40 px target at about 0.96 s.
- **Claude Code headless:** `--mcp-config <file>` with `--strict-mcp-config` loads only the given
  servers; `--resume <id>` continues a session; `stream-json` output needs `--verbose`.
- **Snapshots:** `takeSnapshot` paints on the CPU; video and WebGL may come out black (WebKit 198107).

## Approach

### Takes (`WebRecording`, `AgentBridge`)

- **Aimed live.** `ScrollClip.target` (a selector and `top` or `intoView`): the take finds the
  element again on the clip's first frame, on the page as it is then (a banner closed, a click opened
  another page), and scrolls to it. Not found, the scroll stays put and is reported.
- **Into view first.** `RecordPlan` puts an `intoView` scroll before every hover and click, up to 1 s
  long, after the previous cursor clip and scroll, where the Scroll lane has at least 0.2 s free. It
  moves only as far as needed (`scrollIntoView`'s "nearest", 15% from the edge) and not at all when
  the element is wholly in view. A scroll to a selector the first page lacks is allowed after a click.
- **No blind clicks.** A click whose selector the inspected page lacks, with no click before it, is
  an error for the agent. In the take, a press on an element that isn't there is left out.
- **Checked at arrival.** On the first frame of each cursor clip the clock script hit-tests the
  cursor's point; `WebTakeIssues` reports a target that wasn't on the page, was outside the view, or
  was covered (named with its text: `a.globalnav-submenu-link ("iPhone Privacy")`). `record_page`
  returns them as `warnings`, and the tools' instructions say to fix the steps and record again.
- **Cursor:** stays inside the viewport like a mouse, and glides in from the middle of the view
  before the first clip (up to 1 s), so a take opens wide and its first stop is an arrival.
- **Inspect:** scrolls down the page in 0.8-viewport steps every 100 ms (at most 40) and back first;
  leaves out elements off to the sides (a carousel's other slides); gives links their `href`, to
  inspect the page a click opens.
- **Defaults:** first step at 1 s, 0.8 s between steps, 1.5 s per hover or click, 2 s per scroll,
  1.5 s after the last; the tool description gives the agent the same pacing.
- **Unreachable pages:** a navigation that finishes on `about:blank` fails the load.
- **Script sidecar:** `<name>.web.json` (`WebTake` v1): the script, and the conversation.

### Editor

- **Zooms:** `AutoZoomGenerator.Configuration(for:)` holds a web take's rests for as long as the
  cursor stays (`holdsRests`), counts every stop (`restTravel` = `restRadius`), doesn't group across a
  scroll, and ends a zoom 0.3 s after the page starts scrolling. Web telemetry records scrolls (every
  frame the page moved, as a wheel's delta); scroll starts are the first events after 0.25 s without.
- **Cursor:** a web take's path isn't smoothed by a spring; Movement is disabled with a note.
- **Look:** a take replacing another in its window starts with its canvas, cursor, click and
  keystroke style (`EditorProject.styled(like:)`), saved at once.

### Agents (`AgentRecording`)

- `AgentRecordingRequest` carries the take (`RecordPageRequest(script:)`, without Reco's own
  `intoView` scrolls) and the conversation; the prompt asks to change only what's asked, reuse the
  selectors, and reply in a sentence or two. Any agent can do it: no session of its own.
- `AgentRecordingViewModel` stays the one runner (one run at a time, menu bar, Cancel). A run's take
  goes to `onRecorded` as an `AgentRecordedTake` (movie, the take it replaces, the conversation with
  the reply, colors stripped and the token redacted); `EditorWindowManager.open(_:)` shows it in the
  window it replaces, or a new one. While a run of Reco's own goes, a finished render doesn't open by
  itself: the run's end opens it, so a re-recorded take doesn't leave a window per attempt.
- Claude Code's run gets Reco's server from `AgentRun/reco-mcp.json` with `--strict-mcp-config`
  (the token in the file, not on the command line, and no other MCP servers started); Cursor already
  got its workspace's. Both are offered once their command line is on the login shell's `PATH`.
- `AgentChatViewModel` per editor window: reads the sidecar, builds requests, shows the runner's
  state when the run is its own, folds a failure into the conversation, saves it with the take.
- The swap loads the new take first, then gives the same hosting controller a new `EditorView`; the
  stage, timeline and inspector content are `.id`'d by the take. Measured: a new controller resized the
  window to itself (1335×875 to 1286×754), showing the loading placeholder shrank it to its minimum
  (560×492), and an `.id` around `.inspector` laid the split out at 1495 pt in a 1335 pt window.

## Measured (M5, macOS 26.5.2, Debug)

- A 60 s apple.com take at 2× renders in 81–91 s; `inspect_page` takes 2.6–3.3 s.
- Claude Code (default model) from the prompt above, asked for "a 1 minute demo of apple.com…":
  207 s, 6 turns, $0.72. It inspected, recorded 60 s with 3 s hovers and 2 s scrolls, got the flyout
  warning, added a hover on the Apple logo to close the menu, and recorded again with no warnings.
  Every step showed what it should (menus, hovers, the gallery's slides switching).
- With the inline server config a `claude -p` call to `inspect_page` returned in 9.3 s.
- From the editor's chat (sent through accessibility): "Make it a 12 second video: hover the Mac menu for
  3 seconds, then the iPhone menu…" took 48 s; "Hover the iPhone menu too…" 86 s, with one re-record after
  the flyout warning ("I also added a brief one-second stop on the Apple logo… because the open iPhone
  menu was covering the button"); "Hold the Mac menu hover a bit longer" 21 s, keeping a 1:1 canvas and a
  color background set on the take before. Each swapped into the same window at the same size.

## Verify

- Unit tests: `ScrollClip` aiming and clamping, the cursor clamp and glide-in (`WebScriptTests`),
  `RecordPlanTests` (into-view scrolls and their room, blind clicks, later pages),
  `RecordPageRequestTests` (defaults, the script round trip), `WebTakeIssuesTests`, `WebTakeTests`,
  `WebTakeTelemetryTests` (scrolls), `AutoZoomGeneratorTests` (held rests ended by a scroll),
  `CursorPathTests` (no spring for web takes), `EditorProjectTests` (`styled(like:)`),
  `AgentRecordingRequestTests` (the chat prompt), `AgentInvocationTests` (Claude's server file),
  `AgentRecordedTakeTests`, `AgentRecordingViewModelTests` (availability, `onRecorded`, a chat's
  failure without a notification), `AgentChatViewModelTests`.
- `WebPageRendererTests`: a scroll aimed at an element a late banner moved, and a covered target plus
  a missing one whose click is left out, on local pages.
- By hand: the chat in the app (Style | Agent, sending, Cancel, Retry, the window swapping to the new
  take with its look), the panel's take opening on Agent, Reduce Motion, VoiceOver.

## Open questions

1. **Superseded takes:** an agent that records again leaves its first take in the folder.
2. **Hover menus:** the warning tells the agent a menu covered its target; Reco could close menus
   itself by moving the cursor off them, but which way is "off" depends on the menu.
3. **Video and WebGL:** snapshots may show them black (WebKit 198107); a `<video>` isn't seeked to the
   clock either (spec 0005).
4. **Cookie banners:** DuckDuckGo's autoconsent (MPL-2.0) could dismiss them before a take; it's a
   third-party script, so not added without asking.
5. **Sessions:** Claude's `--resume` would let it remember the page it inspected; the stateless prompt
   works for every agent and costs one `inspect_page` a turn.
