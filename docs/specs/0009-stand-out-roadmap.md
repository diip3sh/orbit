# Stand-out roadmap

> What to build next and in what order, after an October 2026 look at the market: finish the
> editor's missing basics from spec 0004, and put the agent and web recording work in front, because
> that is where Reco is different.

## Why

Spec 0004 listed what recorders have in common (N1–N21). None of it is built yet except freeze-screen
selection (N17) and web recordings (N22). Since then the market moved:

- **Auto-zoom is no longer a difference.** OpenScreen reached 40k GitHub stars as a free Screen
  Studio alternative (Electron; archived by its owner in June 2026, continued as a community fork).
  Cap has ~23k. Screenize is paused. Zoom, cursor smoothing, backgrounds, motion blur, captions and
  GIF are what every one of them lists.
- **Agents record now.** Fetch (GPL, macOS) is an MCP server that records a real window in real
  time and captions it. An unofficial Screen Studio MCP drives apps with real clicks and edits the
  take (46 tools; narration goes to a cloud voice service). `demo-recorder` and Pagecast record
  Playwright sessions to MP4/GIF without any polish. Arcade and Clueso do "URL to demo" in the cloud,
  paid, with AI voices.
- **What nobody else has together:** a page rendered frame by frame on its own clock (exact 60 fps
  at 2× whatever the page costs, identical every time), with exact telemetry, finished by a native
  editor (zoom, cursor, canvas), on-device, free, and driven by the agent the user already pays for.
  The others record in real time (dropped frames, notifications, a real cursor fighting the user) or
  give raw Playwright video.

So the order changes: the agent loop first (it is the reason to pick Reco), then the basics people
check a recorder for before they trust it.

## Expected outcome

- An agent can go from "record a demo of this page" to a finished MP4 or GIF on disk without a
  person touching the editor, and can fill in forms on the way.
- The editor has the basics every competitor lists: GIF, motion blur, cursor loop, crop, click
  sounds, voice cleanup, captions, silence removal, speed, masks.
- A recording can be cancelled or restarted.

## Approach

One item at a time, each finished to the quality bar in CLAUDE.md (pure core with tests, lint clean,
docs updated, frame budget measured) before the next starts. Details of the N items are in spec
0004; only what changed is repeated here.

### Track A — the agent loop (what makes Reco different)

| # | Feature | Size | Notes |
|---|---|---|---|
| A1 | `export_recording` MCP tool | S–M | The agent exports its take (format, size, GIF once N10 lands) and gets the file's path. Reuses `ExportService`; long-polls like `record_page`. Without it an agent's take ends in a window a person must click through |
| A2 | Type steps in web takes | M | A `type` step: text into the focused or selected field, key by key on the page's clock, with key telemetry so the keystroke overlay works. Demos of search, sign-up and forms are impossible today |
| A3 | Text callouts on a timeline lane | M | A title or caption for a time range, drawn once per plan like `KeystrokeChip`. Agents give them per step in `record_page` ("Pick a plan", "Check out"); people add them with **T**. A silent demo that explains itself, no AI voice |
| A4 | `edit_recording` MCP tool | M | Zooms, cuts, canvas shape and style on an existing take, as the chat does by re-recording today, but without the render |
| A5 | Localhost and auth | S | Document and test `http://localhost` takes for "record the feature I just built" from a coding agent; cookies already carry over from the preview |

### Track B — basics from spec 0004, in this order

| Order | Item | Why here |
|---|---|---|
| 1 | N2 cursor: loop to start, stop before end, tilt | Small, pure, makes GIFs loop |
| 2 | N10 GIF export, copy frame | The most asked-for output; A1 needs it for PR and README demos |
| 3 | N20 cancel and restart a recording | Small |
| 4 | N1 motion blur | The largest visible step |
| 5 | N11 crop | |
| 6 | N3 click sounds, N4 enhance voice | Share the derived-audio cache |
| 7 | N6 silence removal, then N5 captions (macOS 26) | |
| 8 | N7 speed per part | Changes `TimeMap`; its own spec |
| 9 | N8 masks, N9 sensitive info | |
| 10 | N12 fill, N13–N16, N18 screenshots, N19 camera | Own specs for the L items |

The session order interleaves them: N2 → N10 → A1 → N20 → A2 → N1 → A3 → the rest of track B.

### Stand-out ideas kept for later (need their own spec)

- **Step guide from a take:** a frame per click with the element's text, as Markdown. Exact for web
  takes, since the script knows the element.
- **Re-render on change:** a saved web script rendered again from the command line or CI
  (`reco://render?script=`), so a product's demo video never goes stale. Nobody offers this free.
- **Variants from one script:** the same take at desktop, tablet and phone viewports, light and
  dark (`prefers-color-scheme` set on the web view), in one run.
- **Native Mac apps from a script** (spec 0004 N22 "later"): possible now the sandbox is gone
  (Accessibility targets), but real-time and far less exact than web takes.

## Status

| Item | Status |
|---|---|
| N2 cursor loop, stop before end, tilt | Done. Checked in an exported take's frames; the inspector's controls not yet seen in the app |
| N10 GIF export, copy frame | Done. A real 7 s take exported in 1.3 s. Each frame is spliced from ImageIO's single-image GIF, since ImageIO holds a whole animation in memory (3.1 GB for 750 frames). No dithering yet |
| A1 `export_recording` | Done. Run in-process on a real take; not yet called by a real agent |
| N20 cancel and restart | Done. Not yet tried on a real recording |
| A2 type steps | Done. Tested on a local form (input events, Enter submits); real sites not yet tried |
| N1 motion blur | Done for the camera and the cursor. 8 samples in the preview, 16 in exports; at the 8 ms budget on an M5 on the default canvas, unmeasured on an M1 |
| A3 text callouts | Todo, next |
| A4 `edit_recording`, A5 localhost | Todo |
| N11, N3, N4, N6, N5, N7, N8, N9 | Todo, in that order |

## Open questions

- Spec 0004's open questions 1–6 still stand.
- A3: are callouts burned in only, or also exported as SRT?
- Pricing and source: free and open source is the growth path the 40k-star projects took; decide
  before a public launch (see the survey's licence notes in CLAUDE.md).

## Research

- [OpenScreen](https://github.com/siddharthvaddem/openscreen) (39.9k stars, archived June 2026),
  [Screenize](https://github.com/syi0808/screenize) (paused May 2026)
- [Fetch](https://getfetch.fyi/), [Screen Studio MCP (unofficial)](https://glama.ai/mcp/servers/tolimarchuk/screenstudio-mcp),
  [demo-recorder](https://github.com/khang-nyb/demo-recorder)
- [Arcade vs Clueso](https://trainn.co/blog/arcade-vs-clueso/),
  [Arcade's 2026 guide](https://www.arcade.software/post/ai-video-generation-2026-guide)
- [Screen Studio alternatives, 2026](https://supademo.com/blog/screen-studio-alternatives)
