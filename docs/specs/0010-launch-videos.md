# Launch videos from a URL

> **Superseded in part by spec 0011 (motion editor):** step 1 is still needed and lands in its
> phase 2; steps 2–5 are replaced there.

> Type a website's address, get a 30–60 s launch video ready to post: the product's real pages
> rendered frame by frame, with title cards, captions, music and the brand's look, in 16:9 and 1:1.
> Claude Code (or another agent) researches, writes and directs it through Reco's MCP tools; the
> editor and its chat finish it.

## Why

Spec 0009 got an agent from a URL to a finished walkthrough: research, a shot list, a take with a
zoom on every beat, an MP4 or GIF. A walkthrough isn't a launch video. What people post on X,
Product Hunt and LinkedIn tells a story in text on screen, opens on a hook, ends on the address,
plays over music, and looks like the brand. Today a take is a silent page on a slate gradient.

Cardboard (YC W26, cardboard.ai) is the closest product: an agentic video editor whose Mac app
(Sep 28, 2026) lets the user's own Claude or ChatGPT plan edit inside it, and which lists launch
videos as a use case. It cuts footage you bring and generates the rest (motion graphics, AI video,
voice, music, B-roll, captions in 9 styles). It can't film a product: you record the UI yourself
first. The URL-to-video tools (Frame24, AIDemo, Demosmith, Arcade) are cloud, paid, voice-led, and
work from screenshots or real-time capture; the motion tools (Remotion skills, HyperFrames) have no
real UI. Nobody pairs a free, local, frame-exact render of the real pages with launch-style
finishing, driven by the agent the user already pays for. Cardboard is also a good test site, since
its own page is mostly video.

## Measured (cardboard.ai, this Mac, 2026-10-06, HEAD f050908, through the MCP bridge)

- `inspect_page`: 8.3 s, 133 elements, page 13,276 px tall. `render_cost` 2.5 at 1×, 6.1 at 2×:
  a 45 s video at 2× renders in about 4.5 minutes.
- A 6 s take at 2× (one hover on the prompt box) took 47.8 s end to end.
- **The page's videos are frozen.** The page has 61 `<video>` elements (hero tiles autoplay, the
  "Made with Cardboard" marquee, the use-case tiles). In the take every hero tile shows one frame
  for all 6 s: the shoe tile's crop at 0.2 s and 5.8 s differ by encoding noise only (PSNR 47.8 dB),
  stuck on the source's 3 s frame, where the clock froze. The clock script steps rAF, timers, `Date`
  and Web Animations, but not media. The typewriter heading and the floating tiles do play.
- The product itself is behind `/signup`. Without a signed-in session a take can show only the
  marketing site; its in-page editor mockup ("Make videos the way you do everything else", y ≈ 5,100)
  is the only product UI reachable.
- Selectors from Tailwind pages are long `nth-of-type` chains
  (`div.hidden.items-center.gap-2 > a.inline-flex…`): fine within a take, fragile across re-renders.

## Expected outcome

- **Record with AI Agent…** has a **Launch Video | Walkthrough** switch. Launch Video takes the
  address and an optional line ("we just shipped X", "for designers"). Record. Five to ten minutes
  later the editor opens on the finished video and `<name>-launch.mp4` (16:9, 1080p, H.264) and
  `<name>-launch-square.mp4` are next to it.
- The video: opens on the product with a hook line over it (no logo intro: feeds autoplay muted
  and viewers decide in 3 s); three or four beats, each with a caption of a few words over the
  page, the page's own videos and animations playing; an end card with the logo, the address and
  the call to action; music that fades out on the last frame; a background and type taken from the
  site. The captions alone tell the story with the sound off.
- Everything the agent made is editable: captions and cards on a Text lane, music on the Audio
  section, the canvas in Style. The chat changes text, music and style without rendering again
  ("shorter intro", "say 'free on Mac'"); only new footage re-renders.
- **Sign In…** in the bar opens the page in Reco's browser; once signed in, takes show the real
  product (cookies are already shared, spec 0008).
- The agent checks its own video before it reports: it gets a contact sheet of frames and Reco's
  warnings (a banner over the page, text over a shown element, a frozen or blank stretch).

## Approach

Six steps, each to the quality bar in CLAUDE.md, each re-run on the benchmark (step 0) before the
next. Steps 1–2 are what make it a launch video; 3–5 make it good without a person.

### 0. Benchmark (S)

- Three sites: cardboard.ai (video-heavy, dark, serif), linear.app (slow to paint, 18 s a second at
  2×), supabase.com (fast). One fixed request each, run through `reco://record-agent`.
- A rubric, scored from frames and the run's log: no frozen media, no banner or loading state, each
  caption readable on a phone (cap height ≥ 3% of the frame at 1080p), every beat's shown element
  in view, total 30–60 s, run under the time limit, cost per run.
- Today's scores recorded here before step 1.

### 1. Footage that looks right (M)

- **Media on the take's clock.** The clock script keeps every `HTMLMediaElement` really paused and
  plays it itself: `play()` records when it started on the page's clock; each frame sets
  `currentTime` (looping, at its `playbackRate`) for the elements in view and waits for `seeked`,
  up to a limit like images (5 s once, then not again). `paused`, `ended`, `timeupdate` and
  `requestVideoFrameCallback` keep working. Lazy `preload="none"` videos wait for their first frame.
  Measure the cost per frame on cardboard.ai (up to six videos in view); seeking forward 1/60 s
  should decode one frame. Acceptance: the shoe tile at output time *t* matches the source mp4 at
  *t₀ + t* frame for frame.
- **Clean page.** `inspect_page` lists fixed and sticky overlays (cookie banners, chat launchers,
  announcement bars) with selectors; `record_page` takes `hide: [selectors]`, injected as
  `visibility: hidden` before the first frame. No built-in blocklist.
- **Signed-in pages.** **Sign In…** opens the Web Recording window's preview on the address; the
  prompt tells the agent the user may be signed in and to try the app's address (`/app`,
  `/dashboard`, the Get Started link) before falling back to the marketing pages. `localhost`
  (A5) gets its test.
- **Page changes.** A click that opens a page cuts today. The renderer holds the old page's last
  frame and blends into the new one over 0.4 s (crossfade, or a short zoom-through), in the frames
  it writes; telemetry is unchanged.

### 2. Story layer: text, cards, music (L; spec 0009 A3, widened)

- **Text lane** in the editor timeline, like the zoom lane, source time, cut with the recording.
  Two kinds:
  - **Caption:** a few words over the video, top or bottom of the canvas, big and bold.
  - **Card:** a full-canvas title (headline, optional line under it, optional logo) on the brand
    background, or over the page dimmed and blurred. The end card, and a hook over the page.
- Drawn once per plan as images, like `KeystrokeChip`; per frame only transform and opacity, so the
  8 ms budget holds. Three entrances (fade up, word by word, scale in) with the editor's springs; a
  card leaves by revealing the page under it.
- Type: SF Pro (sans pages) or New York (serif pages), from the page's computed `font-family` class;
  web fonts aren't downloaded.
- A card needs time with nothing happening under it: the agent leaves the page still (no step) for
  the card's length. The clock still runs, so the hero's animations are already alive when the card
  reveals it. Frames wholly under an opaque card could skip their snapshot (later).
- **Music:** one track on the Audio section, from the user's file or a track Reco can legally
  offer (open question 1), trimmed to the video, fade in 0.5 s, out over the last 2 s, volume. Web
  takes have no other audio, so it's the export's only track. Cutting beats on the music's bars
  (2 s at 120 BPM) is later.
- **Keys:** **T** adds a caption at the playhead. Inspector: text, kind, position, entrance.

### 3. The brand's look (M)

- `inspect_page` returns `brand`: the page's background and text colors, the main call to action's
  background (accent), serif or sans, and the logo's selector and box (the home link's image).
- The launch style built from it: canvas gradient from the background toward the accent, cards on
  the background with the text color, the logo cropped from a 2× snapshot of its box.
- **Browser frame** (canvas option): a window title bar with the three buttons and the page's host,
  drawn once into the backdrop. Launch videos of web products usually show one.

### 4. The agent finishes and checks the video (M)

- **`edit_recording`** (spec 0009 A4): captions, cards, music, canvas, brand style, aspect, zooms;
  writes `.edit.json`, no render. Validated like `record_page` (a caption needs 0.3 s a word, cards
  at least 1.5 s, nothing outside the take).
- **`preview_recording`**: a contact sheet of the edited video (a frame per beat, card and caption,
  12 at most) as MCP image content, plus warnings: text over a shown element, a frozen stretch
  (identical frames under a playing video), a near-uniform frame, a hidden selector that matched
  nothing. Claude Code reads the image; agents without images get the warnings only.
- **`export_recording`** gains `aspect` (16:9, 1:1, 9:16), so one take gives each format.
- **Launch playbook** (`AgentRecordingRequest.launchPlaybook`):
  1. Research as now, plus the pitch: who it's for, what's new (the line the user gave first).
  2. Script: a hook over the product in the first 3 s (≤ 6 words), three beats with a caption each
     (≤ 7 words, 2–4 s a shot), an end card (address and call to action). 30–45 s, at least half
     of it the product working.
  3. Record once with shows, `hide` for overlays, the page still under cards.
  4. Edit with `edit_recording`: brand style, browser frame, captions, cards, music.
  5. Preview; fix text and style as often as needed, re-record at most once, for footage.
  6. Export 16:9 and 1:1; reply with the pitch it used.
- The chat's change playbook chooses `edit_recording` for text, music and style, `record_page` only
  for footage.

### 5. Formats and the bar (M)

- **Reframe** for 1:1 and 9:16: the canvas fills with the video instead of fitting it, and the
  camera keeps the shown element (or the cursor) in the crop with the same spring.
- **Bar:** the Launch Video | Walkthrough switch, Sign In…, the run's steps in the footer
  ("Researching cardboard.ai", "Recording 42%", "Editing", "Checking", "Exporting"). The run's limit
  becomes 20 minutes for launch videos (a 45 s cardboard.ai take is ~4.5 minutes of render).
- A notification when it's ready: **Edit**, **Reveal**.

### The cardboard.ai video this should produce (acceptance, not hard-coded)

| Time | Shot | Text |
|---|---|---|
| 0–3 s | Hero, tiles playing, page dimmed under a serif hook | "Make any video you can think of" |
| 3–10 s | The cursor types "a launch video for my startup" into the prompt box, zoomed | "Describe it" |
| 10–16 s | "Made with Cardboard" marquee, videos playing | "Made with Cardboard" |
| 16–24 s | "Everything you need": hover Generate, Clone your voice; the panel shows each | "Build the story" |
| 24–32 s | The editor mockup (Dashboard, Library, timeline), or the real app when signed in | "Edit by chatting" |
| 32–38 s | End card: logo, address | "cardboard.ai — Get started" |

## Order

1 (media clock) → 2 (text and cards, then music) → 4 (`edit_recording`, `preview_recording`,
playbook) → 3 (brand, frame) → 5. Step 1 first because a video-heavy page is unusable without it;
the first impressive demo is after step 4 with SF type on the default canvas.

## Open questions

1. **Music source.** The user's own file always. Beyond that:
   - Apple Loops can't be shipped as music beds (their licence forbids it); users can still make
     a track in GarageBand. FreePD (CC0) closed in 2025; Pixabay forbids redistribution.
   - Commissioned buy-out tracks (a handful, by mood) are the clean way to bundle.
   - ACE-Step 1.5 (MIT, ~4 s for 30 s of music on Apple silicon, BPM and key) generates on device,
     but the model is 7 GB: an optional download at most.
2. **Voiceover: not in this spec.** Feeds autoplay muted, so captions carry the story. And Apple's
   system voices and Personal Voice are licensed for personal, non-commercial use only (macOS 26
   licence §2F), so they can't narrate a published video. If it's ever wanted: Kokoro-82M
   (Apache-2.0) on device.
3. **Cards as HTML?** HyperFrames-style: the agent writes the card as HTML/CSS (the site's own web
   fonts, any motion) and the web renderer renders it frame-exact. Brand-perfect, but a second
   source in the composition and uneven quality. Native first; revisit after the benchmark.
4. Captions also as SRT, or burned in only (spec 0009 A3's question)?
5. Render time: 6 s of render per second at 2× on cardboard.ai, plus media seeking. Is 1× with
   zoom capped at 2× acceptable when `render_cost` is high?
6. No agent connected: Foundation Models (macOS 26, ~3B, structured output) could write the hook
   and captions from `inspect_page` text, with a fixed shot plan. Later.

## Research

Sources (2026-10-06):

- Cardboard: cardboard.ai, /desktop, /changelog, /hard-problems;
  ycombinator.com/launches/PM3-cardboard-agentic-video-editor.
- Launch videos: screenhance.com/blog/product-hunt-launch-video-guide (30–60 s, real UI in the
  first 3 s, no logo intro), speedrun.substack.com/p/how-to-make-a-viral-launch-video (half or
  more product walkthrough, speed up repetition), flowjam.com/blog/30-best-launch-video-examples-checklist
  (16:9, 1:1, 9:16 and a GIF; 9:16 cuts 15–30 s), postfa.st/sizes/x/video (X: up to 2:20, autoplays
  muted), moonb.io/blog/product-launch-video (Linear, Warp, Raycast),
  studiomaydit.com/blog/linear-vercel-raycast-aesthetic (near-greyscale, one accent, real UI as the
  hero, big type).
- URL to video: frame24.app (MCP for Claude Code, cloud, $39–399/mo), aidemo.video, demosmith.ai,
  arcade.software, tella.tv/changelog (Claude connector, edits existing recordings), cap.so,
  screencraft.live, github.com/heygen-com/hyperframes (agent-written HTML to deterministic MP4).
- Music and voice: support.apple.com/en-us/102034 (Apple Loops), freepd.com,
  pixabay.com/service/license-summary, huggingface.co/ddalcu/ACE-Step-1.5-XL-Turbo-MLX-Serve-8bit,
  apple.com/legal/sla/docs/macOSTahoe.pdf §2F, developer.apple.com/forums/thread/812285,
  github.com/gabrimatic/kokoro-mlx.
