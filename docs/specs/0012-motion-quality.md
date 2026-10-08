# Motion quality

> Make the launch videos look made by a top motion designer, not generated. The current videos read
> as AI-made for six reasons: flat look, fade-and-blur motion, system type, no brand assets, no sound,
> and no direction. Fix them in that order: research is in the craft rules and the renderer, assets
> come in through a tool, and direction comes from skill files the agent loads.

## Why

Spec 0011 phases 0–4 work end to end: from an address, the agent makes a 20–40 s motion video of the
real UI with clean lint. The user's verdict on the Supabase, Cardboard and Linear videos (2026-10-07):
"pretty basic… anybody can do these with Opus 5.5… nothing to wow about." Phases 5–7 (music, editing,
formats) wait until this is fixed.

Measured against the research below, the gap isn't the grammar's timing. It is everything around
it. A Reco frame today:
- **Flat look.** A solid near-black background with no light, no grain and no texture. Every
  pixel is 8-bit with no dither.
- **Template motion.**
  - Entrances are fade-ups and blur-ins, the first tell on everyone's list.
  - There is no motion blur, though spec 0011 promised a 180° shutter.
  - There are no masks other than the text reveals, and no velocity-matched cuts.
  - Every move eases out to rest the same way.
- **System type.** SF Pro, New York or SF Mono in four weights, with fixed tracking, whatever
  the brand.
- **No brand assets.** The logo is whatever element can be lifted from the page. The agent
  can't bring in a file: it has no download tool and no Write.
- **No sound.**
- **No direction.**
  - The playbook goes research → script → shots in one pass.
  - There is no arc, no chosen direction and no signature move.
  - There is no time-coded storyboard and no review by an independent eye.

## Expected outcome

- Three products (supabase.com, cardboard.ai, linear.app) made from their address alone:
  - **A blind side-by-side.** People shown one of these next to an official launch film of a
    comparable product (Linear Diffs, Ask Attio, Raycast) at phone size don't reliably pick
    which is ours (≤ 65% correct over 10 viewers).
  - **No two alike.** The three videos differ in palette, type, motion register and signature
    move.
- Every video carries:
  - the brand's real logo and typeface (or the closest open one);
  - a lit, textured background derived from the brand's colours;
  - masked reveals;
  - motion blur at speed peaks;
  - velocity-matched cuts;
  - one hero moment;
  - music and sound effects placed on the picture.
- The agent works like a studio: brief → arc → three directions, kill two → storyboard → build →
  critic → fix. The method lives in skill files the run loads, not in a growing prompt.
- Still true: the agent names what happens and the grammar does the motion (spec 0011, *Taste in
  the grammar*). Quality comes from a richer grammar and better direction, not from the agent
  writing keyframes.

## Research

From the background research of 2026-10-07: four parallel reports on craft, launch films,
other tools' skills and Reco's code. Tags:
- **[P]** a primary source states the number.
- **[S]** a secondary source.
- **[U]** practitioner norm, a starting value to tune by eye.

### What the admired films do

| Film | What makes it |
|---|---|
| Linear Agent, Linear Diffs (2026) | Masked type "out from behind invisible edges, no scaling or blurring", long holds, slow drift over dark UI, shallow depth of field in macro shots, a match cut from issue to diff [S impractical.ai] |
| Raycast "It's out", Cursor 2.0, Framer 3.0 | Hard cuts on the beat, punch-ins isolating one control, zoom-throughs *through* panels, "fast attack, long high-friction tail" [S] |
| Ask Attio, Dia | Typed query, 2.5D drift over layered dark UI, stark statements by masked reveal [S] |
| Figma Config 2025 (Relay) | Deliberately 15 fps for a handmade feel; a brand motion library with "expressive" and "functional" type [P figma.com blog] |
| Vercel Ship 2025 (basement) | Animated "on twos", EXR passes, graded in Resolve [P basement.studio] |
| Apple "Power to the Pro" (BUCK) | 250 frames, each a finished style frame before anything moved [P buck.co] |

Common to all of them:
- Real UI is the hero, with no abstract AI metaphors.
- Type does the narration; there is no voiceover.
- Easing is a fast attack with a long tail, and nothing bounces.
- Two editing modes: snappy (cuts on the beat, punch-ins) and calm (masked type, holds, drift).
  Spec 0011 measured the same split.

### The tells of AI motion (and the fix)

| Tell | Studio fix |
|---|---|
| Every element fades up 20–40 px and blurs in | Masks: text rises 100–110% of its line height from behind a hard edge, no opacity [U]; blur-in only with a 105–110% → 100% scale settle |
| One ease on everything, settling in ~20 frames | Registers per brand; premium settles take 30–33 frames at 30 fps, the last 5% of travel a third of the time [S launch-video-clone] |
| Lockstep groups, constant stagger | Eased stagger: the offsets shrink (×0.84 per item, HyperFrames waterfall) |
| Shots ease in from rest after a cut | Cut in already moving; the speed matches across the cut ("cut-the-curve": ±230 px on power4 either side ≈ 3,070 px/s) [S HyperFrames] |
| No motion blur; teleporting moves | 180° shutter; 270–360° or 40–80 px directional blur only in the middle frames of a whip [U] |
| Crossfades between busy UI | Hard cut, camera move or shared-element morph; crossfades ≤ 8 frames [U] |
| Flat #0B0B0F or purple-blue gradient | Brand-derived OKLCH field: 2–3 stops within 60° of hue, lightness spread ≤ 25, chroma under the accent, off-centre light, vignette 10–25% [U]; tint neutrals to the brand [S HyperFrames] |
| Banding | Grain at the threshold of notice ("if you notice it, halve it") [P instantgradient]; re-seeded at 12 Hz, not per frame (per-frame grain took the file from 9 to 85 MB) [S AbubakrChan] |
| Glow on everything, sheen spilling past corners | Bloom only on the top 5–10% of luminance, ≤ 2–3% of the frame height; one glint per shot, on the hero, clipped to its radius [S video-shotcraft Q4] |
| System or "safe" fonts | The brand's face (OFL or first-party), or its closest open match |
| Invented labels, generated logos | Real files only: the site's header SVG, `favicon.svg`, `apple-touch-icon`, press kit; never drawn [S launch-video-clone, 30x-video] |
| Constant shot lengths, slideshow (front-load then freeze), screensaver (everything drifting) | Long-short-short-long rhythm; reveals spread into the back half; one hero moment at 60–75% then 1–2 s of stillness [U] |
| Camera shake, whole-frame slam on every beat | No shake on UI; ≤ 3 whole-frame impacts per film, ≥ 16 beats apart [S video-shotcraft R4] |
| No self-review | A clean-context critic looks at frames with frame numbers [S video-shotcraft, EveryInc] |
| Same look for every brand | Three written directions, two killed, one signature move from a brand asset [S AbubakrChan] |

### Craft numbers

| Parameter | Value | Source |
|---|---|---|
| Productive (UI beats) | cubic-bezier(0.2, 0, 0.38, 0.9) | IBM Carbon [P] |
| Expressive entrance (hero) | (0, 0, 0.3, 1) | Carbon [P] |
| Emphasized decelerate | (0.05, 0.7, 0.1, 1) | Material 3 [P] |
| Exit | (0.4, 0.14, 1, 1); ~15% shorter than its entrance | Carbon [P], Material [P] |
| Spring bounce | 0 by default; 0.15 barely felt; ≤ 0.3 only for things arriving with momentum | WWDC23 [P] |
| Overshoot | 5–10% of travel, once, then settled; never on fades or text | [S], [U] |
| Anticipation | 2–4 frames, 2–5% of travel, once or twice per film | [U] |
| Follow-through | Content lands 1–3 frames after its container | [U], launch-video-clone measured ~1 frame |
| Stagger | 2–4 frames, eased, spread ≤ 40% of the move | Jitter [P], [U] |
| Shutter | 180°; whips 270–360° | AE default [P] |
| Whip pan | 10 frames, 5 either side of the cut, blur peaking at the cut | [S photofocus] |
| Zoom-through | Out 1→1.2, blur 10 px (text) / 18–20 (surfaces), 0.2 s power3.in; cut at peak; in from 0.75, expo.out 0.5 s; the inverse (0.8 / 1.25) for arrivals | HyperFrames cut catalog [S] |
| Line mask | 12–18 frames a line at 30 fps, lines 3–5 frames apart, no fade | [U] |
| Tracking breathe | +10–20% → 0 over 1–2 s, or +2–5% drift across a hold | [U] |
| Read text | ≥ 5.2% of frame height (56 px at 1080p); text is either read or texture, never between | video-shotcraft Q11 [S] |
| Reading rate | ≤ 17 characters/s, ≥ 20 frames per text | Netflix [P] |
| Parallax | Background 0.2–0.4×, hero 1×, foreground 1.3–2×; ≤ 3 planes | [U] |
| UI tilt | rotateX 10–25°, Y/Z ±5–15°; > 30° only while moving; dense information seen straight on | [U], video-shotcraft Q6 |
| Lifts | ≥ 2× the shown size; never past 1:1 without a sharper capture; depth of field never hides soft text | HyperFrames, video-shotcraft Q2 [S] |
| Grain | 2–6% luminance, monochrome, 1–1.5 px at 1080p | [U] |
| Chromatic aberration | ≤ 1–2 px at the corners, or only on whip frames; never uniform | [S], [U] |
| Beat | frames = 60 × fps / BPM; cut 1–2 frames before the transient | [S], [U] |
| SFX | whoosh peaks at the move's speed peak; alternate two samples, stepping down 0.40 → 0.25; compensate AAC priming (~1.3 frames at 30 fps) | video-shotcraft S1–S5 [S] |

Brand → motion register:
- **Precise or technical** (Linear, Vercel, Supabase):
  - expo/quint-out, 10–18 frames, no overshoot
  - cuts and push-throughs, mono typing
  - hairline grids, almost no grain, no glow
- **Premium or calm** (Apple, Stripe):
  - long tails, 20–36 frames, long holds
  - dolly with depth of field, match cuts, tracking-out type
  - soft fields, grain, one light sweep
- **Playful** (Notion, consumer):
  - spring bounce 0.2–0.35
  - pops from 80–90%, never from 0
  - brand-shape wipes, saturated palette
- **Bold** (launch hype):
  - expo in-out, whips of 8–10 frames with a long shutter
  - big type crops, cuts locked to the music

How studios derive the register:
1. Pick three adjectives.
2. Give each a speed, a curve, a shape vocabulary and a transition family.
3. Make a signature move from a brand asset: the logo's geometry as the wipe, the corner radius as
   the mask, the accent as the sweep.
4. Ban whatever contradicts the adjectives.

### How the best agent skills are organised

| Skill | Structure worth taking |
|---|---|
| HyperFrames `product-launch-video` (Apache-2.0) | Capture → design system → story (one arc: PAS, demo loop, before-after-bridge, feature-benefit cascade; each beat tagged with a persuasion move and an emotion) → time-coded shots → build → finalize. A `## Video direction` block written once (palette, motion grammar, holds, negative list); shots hold only deltas. Names both failure modes: *slideshow* and *screensaver* |
| video-shotcraft | Styleframe before storyboard. One technique per shot; each technique is the hero only once per film. Err slower ("every note said slow down"). A clean-context subagent reviews with frame numbers |
| launch-video-clone | Measures a reference film and grades the render against its curves. A logo source order. "Out of the box, Opus 5.5 makes the generic AI motion look" |
| AbubakrChan/product-launch-motion | "No house style: write three directions, kill two, keep a signature move"; the accent rationed on a written budget; re-render to a new file after each critique |
| EveryInc/product-launch-video | Four parallel critics (layout, readability, pacing, brand) on ~20 rendered frames |
| 30x-video | "Scrape first, design second"; an asset audit records every file as USE or SKIP before any shot uses it |

### Assets and licensing

- **Logo.** In order:
  1. inline SVG inside `header`/`nav`/`[role=banner]` (found structurally: class names caught 0
     of 32 on heygen.com);
  2. `favicon.svg`;
  3. `apple-touch-icon`;
  4. press kit;
  5. simple-icons (CC0 data, the trademark still the owner's).

  Two services are out:
  - Brandfetch's Logo API requires hotlinking and forbids downloading, so it can't feed a stored
    bundle.
  - Clearbit's API shut down on 2025-12-08.
- **Fonts.**
  - Google Fonts are OFL: fine to render into video, fetched from `github.com/google/fonts`.
  - A site's own `@font-face` file is usually web-licensed, and video needs another licence. So
    use it only when the user owns the brand (they say so in the bar), else the closest OFL face.
- **Images and video.** The site's own `og:image`, hero images and `<video>`s are first-party.
  Unsplash and Pexels require hotlinking plus attribution: out.
- **Icons.** Lucide (ISC), Phosphor (MIT).
- **Music and SFX.**
  - Pixabay bans commercial use of content showing trademarks, and some of its tracks raise
    Content ID claims.
  - Uppbeat's free tier excludes advertising.
  - Kenney SFX are CC0.

  So we bundle a small CC0 SFX set, take music from the user (a file) or a source whose licence
  covers ads, decided in the Q5 open question. (Superseded: spec 0013 generates every sound.)

### Agent wiring (verified 2026-10-07)

- `--tools WebSearch,WebFetch` hides the Skill tool: a headless run with a skill in
  `AgentRun/.claude/skills` said "I don't have a Skill tool".
- With `--tools WebSearch,WebFetch,Skill,Read --allowedTools … Skill "Read(./.claude/skills/**)"`
  the same run used the skill and read a file next to it.
- `--setting-sources project` is meant to keep the user's own skills and settings out. The run
  listed only Claude Code's bundled skills besides ours; still to confirm with a personal skill
  present.
- The scoped Read limits reading to our skill files, so the run still can't read the user's disk.
- WebFetch can't save bytes. Downloading is a Reco MCP tool (`fetch_asset`) that writes into the
  bundle, not Bash or Write.

### What Reco can't express today (audit)

- **Fills.** No gradients anywhere (shape, text or background).
- **Shapes.** Only a filled rounded rectangle: no ellipse, path, stroke or SVG.
- **Compositing.** No masks or mattes between layers, no blend modes.
- **Effects.**
  - No bloom, grain, vignette, grade, light sweep or chromatic aberration.
  - No motion blur.
  - Shadows are black and fall straight down.
- **Type.**
  - No font files and no family field; four weights.
  - Tracking is fixed at −1.2% and isn't animatable.
  - No colour animation.
- **Moves.** No easing on moves: only hand keyframes take one. A spring has no bounce.
- **Assets and sound.**
  - No way for the agent to add a file.
  - No image or video layer besides lifted UI.
  - No audio.
- **Output.** 8-bit BGRA with no dither, so dark gradients will band.

## Approach

Six phases, ordered by what moves the verdict most per effort. Each ends with the three sites
re-run from their address and the frames compared with the previous round's (kept in
`~/Movies/Reco/quality/<phase>/`).

| Phase | Size | Status |
|---|---|---|
| Q1 - Assets: `fetch_asset`, logos, fonts, images | M | Todo |
| Q2 - Look: fields, light, grain, 10-bit | M | Fields picked; build todo |
| Q3 - Motion: reel, rhythm, camera, blur, masks, registers, seams | L | Todo |
| Q4 - Direction: skill files, storyboard, critic | M | Todo |
| Q5 - Sound: SFX and music on the picture | M | Moved to spec 0013 |
| Q6 - New shots and the blind test | M | Todo |

**Order of work:**
1. The Q3 motion reel, so the user picks transitions and motion before any of it is built.
2. Q2 (the fields are picked).
3. Q3.
4. Q1 and Q4 together: the skills are text, and they name what Q2 and Q3 built.
5. Q5.
6. Q6.

**Progress log** (newest last; resume from the last line after a compact):
- 2026-10-07: started step 1, the motion reel (`docs/references/motion-reel/reel.html`).
- 2026-10-07: reel published: `claude.ai/artifact/FpneBQ15gRrmfMxJfzUUid`, source
  `docs/references/motion-reel/reel.html`.
  - 39 live frames: 12 transitions, 14 text reveals, 5 registers, 6 camera moves, 2 rhythms.
  - Each row pairs one of Reco's moves today, with its real timings from `MoveExpansion`,
    `SeamExpansion` and `ShotLayout`, against the proposal.
  - Checked headless at several times with no script errors.
  - Waiting for the user's picks; record them here.
- 2026-10-07: what today's videos do (read from the five `.motion` bundles in `~/Movies/Reco`).
  - Scenes run 2.5–4.5 s, except a feature sequence of 10–15 s.
  - Most seams are hard cuts. A zoom-through follows the hook; there is sometimes one cut on
    motion, and a fade into the end card.
  - Every shot drifts at 2% of the width a second, capped at 4% per scene, so 1% a second in a
    4 s scene.
  - Cut on motion carries only that drift speed, so it plays as a plain cut.
  - This is why "everything moves at the same speed": nothing in the grammar is ever fast. The
    seams already exist; what's missing is speed contrast, motion blur and masks.
  - Next: Q2 while the picks come in.
- 2026-10-07: the user's picks from the reel. They now define Q3's scope; see *Q3 - Motion*,
  *Picks*.
- 2026-10-07: Q2.1 (the four fields) done; see *Q2 - Look*, *Steps*. A real-content check
  showed the fields need placing around the type: next is Q2.1b, then Q2.2.
- 2026-10-07: the user rejected the Q2.1 result (`~/Movies/Reco/quality/Q2.1/`): the fields were
  ported and pasted behind the old video, "no progress at all". The four looks are a direction,
  not assets: find more work in that line and build animation of that quality. Q2.1b and the rest
  of Q2 are on hold. Next: links to the best launch films, grouped by direction, for the user to
  pick one; then rebuild the look against the picked films.
- 2026-10-07: 34 verified launch films in four directions given to the user:
  `docs/references/launch-films.md`. Waiting for their pick.
- 2026-10-07: the user picked **New Raycast**, **Nothing OS 5.0** and **3D UI layers**, and shared a
  guide to the "Opus 5.5 motion studio" method (reference → style guide → shot list → render →
  critique loop on its own frames), asking to use what helps but stay clear of the generated look.
  The four films were downloaded to `~/Movies/Reco/references/` and measured:
  `docs/references/style-guide.md` (cuts, camera speeds, levels, type, typing pace, and eleven tells
  of a generated video). Plan: *Direction (picked 2026-10-07)* below. Next: L1a.
- 2026-10-07: L1a–L1c built and checked against Raycast's frames; a 7.5 s Supabase shot (partner
  search typed "stripe", whip to the filtered card) is in `~/Movies/Reco/quality/L1/`
  (`raycast-vs-reco.mp4` side by side). What it took, beyond the satin field:
  - live mattes are the element's coverage: the translucent field's paint was only its placeholder's
    letters, so typed text showed through them alone (`MatteFill`);
  - the cursor hides from a typed key until it moves (`CursorPath`), the pointer rests once a clip
    types (`WebScript.pointerPosition`), and the renderer measures typed-into fields itself;
  - fields follow the camera at 15 % (`MotionFrameRenderer.fieldParallax`): pinned, the ground read
    as wallpaper behind the whip;
  - motion blur from a 180° shutter, the editor's sample rule (8 preview, 16 export).
  Critique against Raycast, worst first: the UI lacks its glass rim light and caret (WebKit's
  snapshots draw no caret); the satin's upper band is a broad even glow where Raycast's ground has
  distinct dark forms; the 3.7 s hold after the whip is dead; UI whites are full white (L1d);
  the results take baked at 7× is a 5684×6860 movie; card slots the filter empties show as dark
  boxes (the matte is the page as loaded). Next: L1d with the rim light, then L1e.
- 2026-10-07: the user's verdict on `raycast-vs-reco.mp4`: "really really bad". L1d and L1e are
  polish and wouldn't change that: no single frame of ours would pass next to a Raycast frame. The
  plan is changed: *Direction*, *Why L1 failed* and step **L0** below. What L1 built (satin,
  coverage mattes, the typing cursor rules, parallax, motion blur) stays; the shot itself is thrown
  away. Next: L0, stills only, shown to the user before anything moves.
- 2026-10-07: L0 for Raycast: two stills in `~/Movies/Reco/quality/L0/` (`ours-raycast-2.0s.png`,
  `ours-raycast-5.0s.png`, each stacked under its Raycast frame in `*-vs-ours.png`), waiting for the
  user's approval. Composited in numpy (`scratchpad/l0/still.py`, `specs.json`) from real lifts, every
  part something Core Image can draw, to port once approved:
  - **Content:** supabase.com/docs's ⌘K search, the same beat as Raycast's: empty (`Search docs...`,
    Inter 15 px, lifted at 14×, cap height 14 % of the frame, as Raycast's) and typed `auth` with
    its results, the first selected, green matches the only colour (8×, shown at 7.5×). Lifted
    alone with the dialog's own fill, border and shadow removed (it sits in a portal, so the page
    lab hid everything else itself: `UILiftScript.isolate` left the page behind it). Also surveyed:
    cardboard.ai's prompt box ("Describe your video, or drop footage…", presets under it) is the
    next candidate; linear.app's hero was still empty 1 s after load.
  - **Glass** (Raycast's pill and panel, measured at 4K): a band 0.08 × the cap height wide (12 px
    at 14×); ~41 where it faces down or right, ~82 facing left; a bright line on its outer edge where
    it faces up (+120 near the key, fading over ~half the frame's width), ~3 px deep; a thin
    highlight on its inner edge facing left. The body is dark (10–12) with the ground seen through it
    (45 % in linear light, blurred 40 px), a soft sheen band from the key (+26–38 at its top, fading
    over ~450 px) and a pool (+16). A soft shadow below.
  - **Ground:** satin as finite folds (a crest, a length, a width on each side, a smooth warp so
    no line is ruled), shaded by sheen, lit by pools, gaps to black, defocused 8–9 px; fitted block
    by block to Raycast's light map. For 5.0 s, a matte slab in focus over it with a chamfered edge
    as measured (a groove 11–13 px in at −30 %, the lit bevel, a 7 px falloff, a 1 px drop) and lit
    cloth beside it. Grain ~2 levels at 1080p in the mid-tones, none in black.
  - Raycast's typed text and caret are pure white (253–254); only its secondary text is grey.
  Critique, worst first: the UI is the real one, so it has Supabase's 8 px corners, plain magnifier
  and equal-sized title and description where Raycast's was designed for the film; the ground is
  fitted to these two frames, so whether it still reads as cloth when it drifts is untested (the
  footage-or-plate question stays open until then); B's satin is a little brighter than Raycast's.
  Next: the user's verdict on the stills; then port (satin folds and slab kernels, the glass
  compositor for lifted UI, a caret), then L1's motion again.
- 2026-10-07: the user moved on from the stills ("okay so animate now and a longer video"). A 24 s
  film in that look: `~/Movies/Reco/quality/L1/supabase-docs-film.mp4`, and
  `supabase-docs-film-vs-raycast.mp4` (Raycast's first 24 s above ours). A look-dev render in Python
  (`scratchpad/anim/film.py`, 720 frames in 51 s on 10 cores), not yet Reco's engine, from real
  lifts of every UI state (the page lab in `RecoTests/DebugShotTests.swift`):
  1. 0–3.2 s: satin alone, the empty search bar cut in at 1.0 s, the caret blinking, a slow drift.
  2. 3.2–7.6 s, wider: "row level security" typed at 7.4 characters a second, slower into each
     word; the results arrive after "row", "row level" and the end, a real result set each, the
     green matches growing with the query.
  3. 7.6–10.2 s, the results at 10×: down two, back up to the first (its page is the next shot),
     the camera following each hop 0.06 s late with motion blur.
  4. 10.2–15.0 s: that page, its H1 held at 5.4×, a 0.35 s whip (up to 96 blur samples) down to
     its `create policy` block on glass, a slow pan along the code.
  5. 15.0–24.0 s: Raycast's closing in the docs' own Source Code Pro caps: SUPABASE and a product
     swapped every 0.42 s, SUPABASE DOCS sliding together, BUILD IN A WEEKEND, the wordmark.
  Measured on Raycast's film for it: the bar cuts in at 1.0 s with no fade; its caret blinks ~0.53 s
  on and off with soft edges; results come with the first key; the closing swaps a word every
  0.33–0.5 s, slides the pair together over ~2 s, and ends on the logo alone. Captures: the typed
  prefixes are the input row lifted alone, laid over the settled result sets, so results change only
  where a search would have settled; selection is the real cmdk's ArrowDown; the dialog lives in a
  portal, so the lab hides everything but `[role=dialog]`. Critique, worst first: shot 4's code
  has no event (every Raycast shot has a UI state change; a copy turning into a check would, but the
  first button found was word wrap); the results panel opens within two frames, a pop rather than
  an expansion (Raycast's pops too); no sound; the encode keeps part of the grain (44–51 dB against
  the frames). Next: the user's verdict, then the port into the engine (satin folds and slab, the
  glass compositor, the caret and typing pace, lifting UI that only exists after a click, the
  word-swap closing) so Reco makes this from an address.
- 2026-10-07: the user's verdict on the film: "this one was good" (a copy is on their Desktop).
  The look and grammar are approved. Next: the port into the engine, phase by phase, each checked
  against this film's frames.
- 2026-10-07: the port, phase 1 (the ground) done. `satin` is the film's cloth: its four shots' setups
  (`SatinSetup`), lit in linear light on a grid, blurred out of focus, encoded, the slab over the wide
  one, each scene over satin taking the next setup on its own clock; fields follow the camera's move
  since their scene began (15 %, the slab 35 %); the film's grain over satin frames. Checked against
  the film's ground (16 frames: four setups, three times, a moved camera): 50–64 dB, mean difference
  0.02–0.17 levels; with the film's half-pixel convention matched on the slab, 57–60 dB. Grain on
  grey: 2.339 levels and a neighbour correlation of 0.437 against the film's 2.339 and 0.439. Tests:
  each setup's levels, a shot's own clock, parallax, grain, setups in turn, the frame renderer's
  wiring; goldens for the macro and wide setups. Next: phase 2, glass for lifted UI.
- 2026-10-07: the port, phase 2 (glass and macro) done. A still asset with `"glass": true` is lifted
  bare (its fill, border and shadow stripped, its corner radius kept) and drawn on a panel of dark
  glass in its shape, in frame space through the inverse of the layer's projection: the field seen
  through it blurred, pool, sheen, the measured rim (0.87 CSS px) and shadow, each shot's light from
  its setup; the content is clipped to the panel. Small layers are drawn sharper than 4× and lifted
  past 8× while they fit 8,192 px. Checked against the film's four shots (its lifts seeded, its
  cameras keyed and held so neither has motion blur): 54.0 (macro), 47.5 (wide), 53.9 (results),
  41.0 dB (page, where the film shrank its lift bilinearly), with the film's half-pixel convention
  matched. Found on the way: `CIPerspectiveTransform` maps an image's extent out to whole pixels, so a
  lift stretched to 5800.3 px drew 0.6 px off; lifts are drawn at whole pixels (existing goldens
  moved by sub-pixel edges, two got sharper). Supabase's code block captured from the live page with
  `glass` is identical to the film's lift (largest difference 0). Next: phase 3, the caret and human
  typing.
- 2026-10-07: the port, phase 3 (typing) done, as the film did it rather than as a live take (which
  would need video with alpha for glass, would show results on the network's timing, and has no
  caret): a still asset's `typing` (field, text) and a `ui` layer's `typingStart`; the engine owns
  the rules (`HumanTyping`): a person's pace, results 0.22 s after each word, the caret's blink, the
  field growing to its results on a spring. The layer composes the last settled element, the row as
  typed and the caret each frame, at its lifts' own scale; its glass grows with it. Checked against
  the film's shots 1 and 2 with the engine's key times (16 frames, still cameras): 53.3–55.1 dB, no
  shift (44 dB until the typed field was drawn at its lifts' whole scale). Tests: pace, settles,
  blink, growth, the plan's typing, results once settled, a golden mid-growth. Next: phase 4,
  capturing UI that exists only after a click (the search dialog) and the typing states.
- 2026-10-07: the port, phase 4 (capture) done. A still's `before` steps (click, type) run once its
  page loads; a typing asset is typed a character at a time at the video's pace, its row lifted each
  time, the whole element once each word's results settle (DOM quiet and finite animations ended,
  after at least 1.2 s), where the text ends measured each time. Supabase's search from its docs
  page (`before` clicking `button[aria-haspopup="dialog"]`, `[role=dialog]`, typing into `input`)
  captured in 27.8 s; against the film's lab lifts: identical (largest difference 0) for the empty
  field, rows 3, 4, 9, 10, 18 and the results at "row" and at the end; the rest differ by the
  input's endless shine and cmdk's selection at "row level", both the site's own state. Frames drawn
  from the live capture: 53–54 dB against the film, 33 dB where that selection shows. Fixed on the
  way: isolation now hides everything inside hidden siblings (the docs heading showed through), bare
  stripping is inline `!important` (a stylesheet rule kept the dialog's border); `liftVersion` 3.
  Tests: a local dialog opened by a click and typed into, with a self-showing heading and a forced
  border under it; still-only validation. Next: phase 5, selection (arrow keys) and the camera's
  grammar (cut-ins, holds and whips, following the UI a beat late).
- 2026-10-07: the port, phase 5 (selection, follow, whip) done. A typing asset's `select` lifts its
  results with the selection moved down once, twice… (the down arrow on the field, the selected
  result found by `aria-selected` or cmdk's `data-selected`); a `ui` layer's `presses` move it, and
  the scene's camera follows each move 0.06 s late over 0.3 s, one additive track per press. Motion
  exports sample blur every 3 px up to 96, as the film. Checked against the film's shot 3 (its 10×
  selection lifts, the same follow and blur): 50.5–50.9 dB on nine frames, three of them mid-follow;
  and its whip (the engine's camera keyed on the film's at 120 Hz): 49.8–57.7 dB through the
  96-sample frames, 42–44 dB after it on the code's text (the lift shrunk 8× to 7× by ImageIO, not
  bilinearly). Cut-ins (an opacity `hold` keyframe), holds and whips are already keyframes; naming
  them for the agent is phase 8. Tests: selection and follow, the selected lift drawn, blur spacing,
  a local list selected by the down arrow. Next: phase 6, the closing.
- 2026-10-07: the port, phase 6 (the closing) done: a `closing` shot (text the name, items the
  words, detail a second line, ui the logo) laid out by the film's rules (`ShotLayout+Closing`).
  Against the film's last 9 s, by where each line of type is: the name's left edge (616) and the
  words' right edge (1302) exact, caps 525–554 against 524–554, the same word at all ten moments, the
  slide, lockup, second line and logo within 1–3 px. The type is SF Mono, 8 % narrower than the
  Source Code Pro the film lifted from the docs; the brand's own font waits for Q1. Next: the whole
  film from one engine document, checked against the approved film's frames.
- 2026-10-07: the whole film from one engine document (`scratchpad/port/film_document.py`): five
  scenes with the film's cameras, six assets the app captured live from supabase.com (the dialog
  waiting, typed, and selectable; the docs article down to its code, `bare` with a `region`; the code
  on glass; the wordmark), exported at 1080p 30 fps in 89–95 s, 12 s once captured. Added for it:
  `bare` stills (no fill: the article's text straight on satin; filled, it showed as a dark box),
  `region` (part of a long element; the article is 19,916 px tall), empty `typing` text (a field
  waiting with its caret), and the film's follow share (the camera keeps 95 % of the selection's
  move). Against the approved film, read through AVFoundation: the bar, the typing, the page and
  its code at 32–45 dB; the differences are the site's state (cmdk's selection, the input's shine),
  the engine's own key times, the closing's type, and the results shot's camera by a few pixels.
  ffmpeg decodes AVFoundation's BT.709 export 1.7–2.4 levels darker than AVFoundation itself does;
  a browser may show it so (open: phase 7, the finish, with 10-bit export). Files:
  `~/Movies/Reco/quality/port/supabase-docs-film-engine.mp4` and `engine-over-film.mp4`. Next: the
  user's verdict on the engine's film; then the agent writing such documents (the grammar's names
  for these shots, the playbook) and the finish (10-bit, levels).
- 2026-10-08: L4 and Q4 for the Raycast look. The user found the agent's Linear film (Linear 6:
  plain black, cards sliding in, centred titles) "very basic" next to the Supabase film, and asked for
  the app to make films like it, with the shader ground, motion that makes sense from shot to shot, and
  a skill the in-app agent loads when it wants. What was built:
  - **`macro`.** One control so close the frame cuts it off. Its `view`s are what the frame shows, in
    CSS px from the element's top-left corner. The camera frames each, holds, creeps 3 % closer and
    whips (0.35 s on (0.7, 0, 0.15, 1)) to the next.
    - The video's first scene opens on 1 s of ground, then pulls back 4.5 %.
    - A typing asset types 0.65 s after it shows, or is shown typed when an earlier macro typed the
      same text.
    - A `select` asset steps through its results and back, as the film did.
  - **A `whip` seam**, the camera streaking across the cut; the `whip` camera move.
  - **Typing into mockups.** Marketing pages draw prompt boxes that aren't fields: Reco empties one and
    types into it, measuring the caret from the laid-out text.
  - **The `material` lint.**
  - **`inspect_page` `selectors`.**
  - **The `reco-launch-film` skill.**
    - What it holds: the bar, the never-list, finding the product's real moments, assets, shots, timing,
      style, checking, and chat changes.
    - How it reaches agents: copied into Claude Code's run folder with the Skill tool allowed, or put in
      the prompt for other agents.
    - The launch playbook it replaces is deleted.

  The approved film rebuilt from four macro shots and its closing, without one camera keyframe, frames
  as the film did; only the page's whip lands 0.6 s later, holds being even.

  The first linear.app run from the address alone (Launch Video, no instructions, Claude Code) took
  9.2 min and made a 31.5 s 4K film (`~/Movies/Reco/Linear 7-edited.mp4`):
  - the homepage's prompt mockup typed "@Linear create issues and assign to me";
  - whips across the issue board, an issue, and its diff;
  - a nine-word closing.

  Everything is on glass over satin, the type 4–8 % of the frame's height and sharp. Two flaws, fixed
  after it:
  - The caret fell a third behind the mockup's text: its computed font isn't what draws it.
  - It opened on the empty mockup, a dark box with a caret: the skill now opens on an empty field only
    when something in it reads.

  The next run (Linear 8) put the caret 13 px above the text before the first key: an empty line has no
  height, so the empty inline box sat at its top. A zero-width space now stands in while it's measured.
  The run after (Linear 9, 6.9 min, 32.3 s) is clean: it opens on the empty prompt with its toolbar,
  types with the caret on the text's end, and tours the board, an issue the agent took and its diff.
- 2026-10-08: Looks. The user found every film the same (black satin, glass, whips) and asked for Paper's
  shaders and more like them, animated, with transitions that animate into something else of the same
  aesthetic, in the app and the skill. Their picks stay directions, not samples: the fields act
  on the content under glass and in the seams, not pasted behind it. What was built:
  - **Three looks, one a film.** Satin; light (the grain gradient: `ember`, `sunlit`, and its blob, sphere
    and ripple as `bloom`, `orb`, `ripple`); dither (`matrix`, and its warp, swirl and wave as `warp`,
    `swirl`, `tide`). The `look` lint keeps a film in one; the skill chooses from the brand.
  - **Seams in a look's language**, over the whole frame: `glow` (a grainy front of light out of the next
    scene's field's shape), `dither` (the frame turned to the brand's dots from its edges in, the UI drawn in
    them, then into the next scene, stepping at 15 fps) and `ring` (a ring of smoke opening from the middle,
    the closing inside). Designed in a lab on real film frames first (`scratchpad/lab2`).
  - **Glass in colour**, so the ground tints it.
  - A Core Image bug found on the way: two images of one kernel moved differently in one frame drew one as
    streaks; fields take the camera's move as an argument now.

  Look-dev: the Linear 9 film re-grounded in light and dither. Then two runs from the app, no instructions:
  - **supabase.com** (5 min, 26 s at 4K): the agent chose dither, green on matrix, warp, tide, swirl, a
    `dither` seam from the results to the docs page (its heading drawn in dots) and a `ring` into the closing.
    Its bare page text didn't read over swirl, and the frame-filling dithers were too bright: `material` now
    lints bare text over light and dither, and those dithers light their dots at 0.55.
  - **lovable.dev** (light, pink, `bloom` → `ember` → `sunlit`, `glow`, `ring`): the look reads, but Lovable's
    UI is light. The agent left the white prompt box unglazed, and a card's 7× lift lost its animated list (a
    white panel on screen). Its 4K export failed: WebKit's GPU process quit lifting the prompt at 11×; it gave
    1080p. Open: glass for light UI; lifts of animated content; that WebKit limit.
  - **bolt.new** (8 min, 27 s at 4K): light in Bolt's blue, `bloom` → `ember` → `sunlit` → `ripple`, a whip
    and a `glow`, `ring` into the closing. Its dark UI on glass with the blue light through it reads as its
    own film: the prompt typed, the agent and model picker, the design-system and scale cards.

- 2026-10-08: Looks, round 2, from the user's notes on bolt.new's film: the caret sat a line under the typed
  text; the 4th macro's start was "really bad" (the glow flooded the frame cyan, then the design card came up
  olive); the start had no transitions or animation, only cuts; the 3rd macro's ground (sunlit's blue, violet and
  pale grey) was "really good". Fixed:
  - **Caret**: an empty rich-text field's probe goes in its last block (after ProseMirror's paragraph it made a line);
    a textarea's line is its first, not its middle (a later run got bolt.new's other hero, a two-line textarea).
  - **Typing** goes to the field marked when it's measured: an agent's field selector that repeated the element's
    found nothing joined to it, and a run shipped bolt.new's prompt untyped. Such a field now fails its capture.
  - **Glow** ordered mostly by place, a band of light from the palette's palest stop to the brand's hue, over the
    order's own range, eased out (the ring too): before, a third of each seam showed nothing, then crossed in 0.2 s.
  - **Backdrops**: bare and glass lifts drop a picture laid over an element's whole back (bolt.new's lime theme
    preview under its card's heading, turned to mud by the glass).
  - **The opening**: the ground swells in from black; the control arrives in the look's seam (light out of the
    blob's own outline, then a halo; dots from the edges). A cut keeps the ground (lint, skill).
  - `bloom`, `orb`, `ripple` take sunlit's palette.

  From the app, no instructions, four bolt.new runs (5–11 min each, 22–29 s at 4K). The first: the blob swells in, light
  traces it and the prompt box lands on glass, the caret on the text's line through the typing; Build now, a whip to
  Slides, a wave of light up into the agent and model picker, the ring into the closing. The next two found the
  textarea caret and the joined-selector typing failure (one shipped its prompt untyped). The last, with both fixed
  (`Bolt 5`): the prompt typed with the caret on its line, a glow up into the model picker, a whip to the 1000× and
  98 % cards, the ring into the closing.

### Direction (picked 2026-10-07)

Today's Linear video against Linear Agent (`scratchpad/refs/today`): ours shows the whole app at
0.6 % text height, unreadable, still, on flat black, under a centred caption. The films crop to one
control (text 2.5–4 % of the height), something real happens in it (typing, a menu, a result
streaming in), it's lit, and the camera holds then moves with intent. So the lever is the shot,
not the background; the fields of Q2.1 stay as one ingredient.

**Why L1 failed** (its frames against Raycast's at the same moments, worst first):
1. **Animated before a still matched.** Motion was built on frames that were wrong at rest. The
   article's own gate (stills → animatic → full pass) was skipped.
2. **UI as a screenshot, not a material.** Raycast's pill is glass: the satin shows blurred through
   its fill, a rim of light runs round its outline (brighter at the top left), a soft shadow under
   it. Ours is the page's element as WebKit paints it: an opaque flat field with a grey hairline.
3. **Too small.** Raycast's focal text is ~17 % of the frame's height, one control filling 60 % of
   the width. Ours was ~7 %, so it reads as a page, not a hero object.
4. **The ground reads as CG.** The satin is a smooth procedural gradient; Raycast's ground has real
   fold forms, highlights with shape, and texture. A shader may not get there: footage or a
   rendered plate may be needed (licensing is the user's call).
5. **No choreography.** Raycast chains UI states in one take (typed → results → menu → hotkey →
   saved) with the camera following; ours was two unrelated beats and a dead 3.7 s hold.
6. **Content.** Supabase's partner page offers a plain search box and cards. Each product needs its
   most cinematic real interaction found first (prompt boxes, command menus, toggles, dashboards).
7. Small: no caret (WebKit snapshots draw none), machine-even typing, full-white UI type.

Built and checked one at a time against the films' frames, side by side, with a scored critique
(hook, readability at phone size, motion, composition, brand, the eleven tells) until each scores 8.
0. **L0 Look-dev gate: stills before motion.** For each direction, two stills of ours at
   1920×1080, each next to the reference frame it answers, until they could pass in the same film.
   The user approves the stills before any animation is built for that direction. For Raycast, the
   frames at 2.0 s (the search pill in macro over satin) and 5.0 s (typed, results below). What
   the stills need, built only as far as a still shows it:
   - **glass for lifted UI:** the element lifted without its fill, the ground under its coverage
     blurred and tinted through it, a rim light along its outline from the matte's edge, a soft
     shadow, so a real control reads as a lit object;
   - **hero scale:** one control at 12–20 % text height, with shallow depth of field from a slight tilt;
   - **a better ground:** first a richer satin (shaped highlights, fold detail); if it still reads as
     CG, ask the user about footage or a rendered plate;
   - **the right content:** for each of supabase.com, linear.app, cardboard.ai, the one or two real
     interactions worth a macro shot, found with `inspect_page` before any shot is designed;
   - a caret and the low-key grade (old L1d), once the rest passes.
1. **L1 Raycast — dark satin.** The parts built so far are kept; the shot is redone after L0.
   - **Done:** L1a `satin` field: black satin folds under one slow, broad key light, out of focus,
     monochrome; levels as measured (median 11–25, crests to ~45 %).
   - **Done:** L1b a macro live shot: a real input typed into, shown at 2.5–3× and cut off by the
     frame edge; built by hand as a document, rendered through the plan, compared with Raycast's
     1–5 s. Still to do: a human pace (8–15 characters a second with pauses; takes type an even
     12.5) and depth of field (the plane was flat).
   - **Done:** L1c hold and whip: the camera holds, then moves to the next element in 0.25–0.4 s
     with motion blur from sub-frame samples (the editor's way).
   - L1d low-key grade: UI whites at 70–75 %, blacks at 0, dither.
   - L1e the closing: tiny mono caps on black, a word swapped every 0.5 s, a pair closing up, the logo.
2. **L2 Nothing — dot screen and callouts:** a gradient under a fixed dot screen (pitch 0.83 % of the
   width, dot 0.1 %); a dot-matrix title with a scramble reveal; callouts with a crosshair and a
   leader line to a real element, named in mono caps; the inline-icon lockup.
3. **L3 3D layers:** a UI exploded isometrically into its parts (each a lift), separating in depth
   and settling; Linear's single plane in the dark, lit by a falling-off pool of light, text streaming
   in line by line.
4. **L4 into the grammar and the agent:** the shots and moves L1–L3 proved, named; the eleven tells as
   lint and design checks; the critique loop in the agent's playbook.

### Q1 - Assets (M)

- **`fetch_asset(bundle, url, kind)`**, an MCP tool. `kind` is logo, font, image or video. It
  downloads into `assets/fetched/` and replies with the stored path, size, format and the
  licence note it applied.
  - Only `https`. ≤ 50 MB. One redirect chain, no `file:`.
  - Content sniffed, so the extension can't lie.
  - Fonts only from `fonts.gstatic.com` / `github.com/google/fonts`, or the product's own site
    when the brand is the user's.
- **`inspect_page` → `brand`** gains `logos` (structural header/nav SVGs, ranked favicons,
  `apple-touch-icon`, `og:image`), `fonts` (the computed families of the headline and body, their
  `@font-face` sources) and `media` (hero `<video>` and image sources). The agent fetches from
  this list, not from a search.
- **SVG** is drawn by WebKit at the scale shown (the lift path: one page, snapshot with alpha), so
  logos stay sharp at any zoom.
- **Fonts.** `TextContent.font` names a font asset. It is registered for the process with
  `CTFontManagerRegisterFontURLs` (`.process` scope) when a plan is built. The face falls back to
  `face` if it fails.
  - Weights 100–900.
  - Tracking and line height become fields.
- **Image and video layers.** An image layer takes any fetched file. A `video` layer plays a
  fetched clip, muted, on the scene's clock: the live-take track, without a page.
- **Asset audit.** `edit_motion` lists every asset with whether a scene uses it. The skill makes
  the agent record USE or SKIP with a reason before writing scenes.
- **Done when:** the three sites' end cards carry their real logos (SVG for Supabase and Linear),
  their headlines are set in the brand face or its named OFL substitute, and no file outside the
  bundle was written.

### Q2 - Look (M)

- **Steps.** Built and verified one at a time; each ends with the tests passing and lint clean.
  1. **Q2.1 Fields: done (2026-10-07).**
     - `canvas.field` and `scene.field` (`ember`, `matrix`, `halo`, `sunlit`, `plain`).
     - `set_canvas` and `set_scene` take it; `edit_motion`'s reply gives each scene's field.
     - The Scene inspector has a Field picker.
     - `FieldPalette` derives the colours from `style.accent` (see *Built* below).
     - Each scene draws its own field under its layers, on the video's clock.
  2. **Q2.1b Field placement (next).** A real check (a copy of the Supabase video with `matrix`,
     and `halo` on its end card, rendered through the plan;
     `scratchpad/supabase-fields.png`) drew right, but composed badly:
     - matrix's lit sphere sits dead centre, right behind the hook's and title's centred headlines,
       so the type reads busy;
     - halo's smoke covers the end card's name. The tile picked had the logo inside the ring and
       the name below it.

     To build:
     - the end card on `halo`: the logo inside the ring, the name and detail below it, as picked;
     - a field's lit mass kept off the text: the sphere moves to a side when the shot's text is
       centred;
     - a design check for text whose contrast against the field under it falls below 4.5:1.
  3. **Q2.2 Grain and vignette:** a whole-frame pass after everything, so grain sits on the UI too.
  4. **Q2.3 Grade and bloom.**
  5. **Q2.4 Half-float frames, dither to 8-bit, 10-bit HEVC and ProRes,** and the banding check.
  6. **Q2.5 Light:** coloured, offset shadows; rim; the `sweep` move.
  7. **Q2.6 Gradient fills** on shapes and text, and the gradient-headline lint.
- **Built (Q2.1).**
  - **Kernels.** `Reco/Motion/Render/FieldKernels.metal.txt` holds the GLSL ported to Core Image
    stitchable kernels; `FieldRenderer` draws them.
    - They're compiled at run time by the system's Metal compiler, about 8 ms once. Xcode 26
      builds `.metal` files only with a separately downloaded Metal Toolchain, which every builder
      and CI would need.
    - Each kernel is compiled alone. Compiled together, Core Image drew only whichever sampling
      kernel it drew first; the other came out transparent (macOS 26.5).
  - **Fidelity.** Each look is drawn as the 1280×720 gallery tile it was picked on, at a pixel
    ratio of 2, scaled to the frame.
    - Against Paper Shaders' WebGL at u_time 4 and 1280×720: ember 50.8 dB, matrix 72.0, halo
      64.8, sunlit 56.3, with mean differences of at most 0.15 code values.
    - The grain gradient's `fwidth` is taken as a GPU does, to the other pixel of the 2×2 quad.
      Forward differences everywhere gave 27–33 dB: the same grain, different speckles.
  - **Colours.** Each stop keeps its picked OKLCH lightness and its hue offset from the lead. The
    lead takes the brand's hue, and its chroma up to the picked one's. A brand with chroma under
    0.03 gets cool greys.
  - **Cost** (M5, Debug, p50):

    | Field | 1080p whole | 1080p preview | 4K export |
    |---|---|---|---|
    | ember | 2.7–4.1 ms | 1.5 ms | 9.8 ms |
    | halo | 3.0 ms | 1.6 ms | 11.1 ms |
    | sunlit | 2.6 ms | 1.4 ms | 9.7 ms |
    | matrix | 0.35 ms | 0.3 ms | 0.65 ms |

    The preview (`MotionPlan.isPreview`) draws the soft looks at most at 720p and scales them up;
    exports draw them whole, for crisp grain. Matrix is always drawn whole.
  - **Push seam.** A push now moves whole frames, each with its own field. Before, a scene's UI
    wider than the frame showed through the incoming scene's empty background (golden
    `motion-grammar-12100` redrawn).
- **Fields picked (2026-10-07).** Source, settings and porting notes: `docs/references/paper-shaders/`. Picked from a live gallery of 12 (`gallery.html` there), these
  [Paper Shaders](https://github.com/paper-design/shaders) 0.0.81 looks (Apache-2.0: keep its NOTICE in
  the app's acknowledgements), ported from their GLSL to Metal kernels for Core Image:

  | Field | Shader and settings | Use |
  |---|---|---|
  | `ember` | grain gradient, corners; three shades of the brand hue on #050405; softness 0.6, intensity 0.35, noise 0.3, speed 0.4 | Bold brands; type in the dark gap |
  | `matrix` | dithering, sphere, 4×4 ordered, 2 px; the brand hue on near-black; speed 0.35 | Technical brands (databases, APIs, dev tools) |
  | `halo` | smoke ring; white and the brand hue on black; radius 0.3, thickness 0.65, noise 3 × 8, speed 0.3 | The end card's logo moment |
  | `sunlit` | grain gradient, wave; three warm tones of the brand on a dark ground; softness 0.7, intensity 0.15, noise 0.5, speed 0.35 | Calm or playful title cards |

  Not picked: ink mesh, light from above, neural glow, dot grid, peach swirl, light paper mesh.
  Frames are deterministic (`time = frame / fps`), so preview and export match; the shader's own
  noise texture goes into the app as a resource.
- **Background field.** `canvas.background` can be a field instead of a colour:
  - 2–4 colour points, interpolated in OKLab, drifting ≤ 5% of the frame per 10 s;
  - a light (position, radius, intensity) and a vignette.
  - Derived from `brand` by rule: neutrals tinted toward the brand hue, chroma under the
    accent, lightness spread ≤ 25. The agent picks a field by name (`ember`, `matrix`, `halo`,
    `sunlit`, or a plain colour), never numbers.
- **Gradient fills** on shapes and text (linear, radial). Lint flags gradient text in a headline:
  a tell.
- **Light.**
  - Shadows get colour and an x offset.
  - A `rim` light on a UI plane: a thin edge highlight that follows its tilt.
  - A `sweep` move: one specular band crossing a layer once, clipped to its shape, additive
    ≤ 40%. Lint: one sweep per scene, three per film.
- **Bloom.** Thresholded at the top ~8% of luminance, radius ≤ 2.5% of the height, on the
  whole frame.
- **Grade.** One per document: lifted blacks, a slight tint toward the brand, saturation held
  under the accent.
- **Grain.** Monochrome, about 4%, re-seeded at 12 Hz, applied after the grade.
- **Pipeline.**
  - Frames drawn in half-float (the HDR compositor's path).
  - Dithered to 8-bit for H.264.
  - 10-bit for HEVC and ProRes, so dark fields don't band.
- **Design check** adds banding (steps wider than 4 px in a smooth field) and bloom clipping.
- **Done when:**
  - The three sites' frames show no banding at 4K H.264 and 1080p HEVC (measured: no luma step
    over 1 code value across 8 px in the field).
  - Mean luma stays in the measured 12–24 band.
  - A 4K frame with field, bloom, grade and grain renders within the 8 ms preview budget at
    display size (exports may take longer).

### Q3 - Motion (L)

- **Picks (2026-10-07).** Picked from the motion reel (`docs/references/motion-reel/reel.html`,
  the ids below are its frames'). Q3 builds these and only these; where a bullet below names
  something not picked, the picks win.
  - **Seams:**
    - `morph`: shared element; the card flies, grows and straightens into the next shot's panel;
      0.65 s on (0.2, 0, 0, 1); the panel's rows follow 2 frames apart, ×0.84.
    - `inverseZoomThrough`: out 1 → 0.8 power3.in 0.2 s, in 1.25 → 1 expo.out 0.5 s, blur 10 px.
    - `matchCut`: the camera dives 4× into a named layer and comes out of the next scene's at the
      same place and size; speeds matched across the cut.
    - `shapeWipe`: the next scene grows from a rounded square with the brand's corner radius,
      expo.in-out 0.8 s, settling from 108%.
  - **Text:**
    - `blurWipe` stays the default headline reveal for sans faces. Mask rise is not adopted.
    - `type` gets a human pace (55 ms ± 25 ms a key) and a caret that blinks at rest.
    - `roll` becomes masked: in from below, out above, no fade, every 0.75 s.
  - **Camera:** `punchIn`: to 3.2× on one control in 0.32 s expo.in-out, creeping 4%, then a hard
    cut back wide.
  - **Rhythm:** both picked. Today's even pacing and the energy curve are both offered;
    the brand or the storyboard chooses between them, so the energy curve is not forced on every
    video.
  - **Not picked:**
    - seams: cut the curve, whip, masked push, nor today's crossfade, blur cut, push, zoom-through
      or cut on motion;
    - text: mask rise, per character, masked word by word, rise and settle, tracking breathe;
    - camera: parallax truck, push with orbit, rack focus, nor today's drift or push;
    - registers: none of the four.

    Today's unpicked moves stay in the grammar until replaced; the new ones above are what Q3
    adds.
  - **Open:** were the registers rejected, or just not chosen yet? Until the user says, Q3 doesn't
    build `style.motion`.
- **Motion reel first.** Done (see the progress log). Before building, a live gallery like the backgrounds' one (HTML and
  WebGL, the same UI card and headline in every frame), so the user picks by eye. Picks are
  recorded here, with their source saved in `docs/references/`.
  - **Transitions:** cut-the-curve, whip, zoom-through and its inverse, match cut, shape wipe in
    the brand radius, mask reveal, plus today's fade and blur cut for comparison.
  - **Text reveals:** maskRise, per-character, tracking breathe, scale settle, typing, roll,
    against today's blur-in.
  - **Registers:** the same 6 s shot played precise, calm, playful and bold.
  - **Camera:** drift, push, orbit with parallax, rack focus, punch-in.
  - **Rhythm:** one 15 s sequence paced flat, as today, against paced with an energy curve.
- **Rhythm.** Today every move and scene runs at about the same speed, so nothing lands.
  - The storyboard gives each beat an energy level from 1 to 5, along a curve:
    1. a calm open;
    2. rising through the features;
    3. the hero at 60–75%, fastest and biggest;
    4. 1–2 s of stillness;
    5. a calm end card.
  - Energy sets the scene's length, its moves' speed (duration scale 0.6–1.5×), its seam (cuts
    and whips when high, match cuts and drifts when low) and whether the camera moves.
  - Moves inside a shot contrast too:
    - a fast attack with a long tail;
    - one element fast and the rest following;
    - holds where nothing moves.
  - Lint: the fastest beat must be at least 3× the slowest in move speed, as scene length
    already is.
- **Camera.** It moves for a reason and carries energy between shots.
  - Up to 3 planes at parallax 0.3×, 1× and 1.5×.
  - An orbit of 3–8° yaw while pushing, never a pure straight push.
  - A rack focus over 12–20 frames.
  - A punch-in to one control.
  - Velocity carried across cuts.
  - No shake on UI.
- **Motion blur.**
  - 180° shutter per layer and camera, sampled across the shutter as the editor does
    (`blurOffsets`): 8 samples in the preview, 16 in export.
  - Only frames with speed get sampled, so still frames cost nothing.
  - Whip seams use 300°.
- **Masks.**
  - A layer can be masked by another layer's shape or alpha (`matte: <layer id>`,
    alpha or inverted).
  - A group can clip its children to its bounds.
  - From these come the reveals:
    - `maskRise`: text or UI rising from behind an edge, no fade. It becomes the default
      headline reveal for sans faces, replacing `blurWipe` as the default.
    - `shapeWipe`: the brand's corner radius growing to reveal the next layer.
    - Type through a UI card.
- **Registers.**
  - `style.motion` is `precise | calm | playful | bold`, set from the brand, never per move.
  - It picks:
    - the enter, exit and move curves (the Carbon and Material values above);
    - the duration scale;
    - the stagger curve;
    - whether a single overshoot is allowed on arrivals with momentum (`playful`, `bold`
      only, bounce ≤ 0.3).
  - Moves keep their names. Their timings come from the register, so two brands don't move
    alike.
- **Settles and staggers.**
  - Scale settles in log-quartic over 30–33 frames at 30 fps (`calm`, `precise`), 18–24
    (`bold`).
  - Staggers shrink ×0.84 per item.
  - Containers lead their content by 1–2 frames (follow-through).
- **Seams.**
  - `cutOnMotion` becomes "cut-the-curve": the outgoing shot accelerates on power4.in and the
    incoming one starts at the same speed and direction.
  - `whip`: 10 frames, a long shutter at the cut.
  - `inverseZoomThrough` for arrivals.
  - `matchCut`: the next scene's named layer starts where the previous scene's named layer
    ended, in position and scale.
  - `fade` is limited to 8 frames between UI scenes.
- **Type moves.**
  - `track` (tracking from +15% to 0, or a slow +3% drift through a hold).
  - `settle` (from 108% with a mask).
  - `weight` (variable axis, for fonts that have one).
  - `crop`: a huge word at 2–4× the frame width, panning slowly, used as texture.
- **Lint additions:**
  - every element entering within 2 frames of another;
  - all shots the same length (±15%);
  - an overshoot outside `playful`/`bold`;
  - a fade between UI scenes > 8 frames;
  - text shown under chars/17 + 0.5 s or under 20 frames;
  - more than one sweep per scene;
  - no hold of ≥ 1 s after the hero;
  - a scene whose reveals all fall in its first quarter (slideshow);
  - every layer drifting (screensaver).
- **Done when:**
  - A frame-by-frame measurement of the rebuilt Linear Agent recreation (spec 0011 phase 0)
    matches the reference's move curve with correlation ≥ 0.95, the launch-video-clone test.
  - The cut speed across seams matches within 10%.
  - Golden frames cover each new seam and reveal.

### Q4 - Direction (M)

- **Built first (2026-10-08):** one skill, `reco-launch-film`, for the approved Raycast look
  (`Reco/AgentRecording/Skills/`). It is copied to `AgentRun/.claude/skills/` for Launch Video runs and
  motion chats, with `Skill` added to `--tools` and `--allowedTools`. `--setting-sources project` isn't
  used: it hid the user's personal skills, but it would also drop their settings. The five skills below
  wait for a second look to direct.
- **Skills.** Shipped in the app (`Reco/AgentRecording/Skills/`) and copied into
  `AgentRun/.claude/skills/` before each run, like `reco-mcp.json`. The run gets
  `--tools WebSearch,WebFetch,Skill,Read`, `--allowedTools … Skill "Read(./.claude/skills/**)"`
  and `--setting-sources project`.

  | Skill | What it holds |
  |---|---|
  | `launch-director` | The method: brief and one promise → pick one arc (PAS, demo loop, before-after-bridge, feature-benefit cascade) → beats with a persuasion move and an emotion → three directions in a sentence each, kill two, keep a signature move → `## Video direction` block (palette, register, type, holds, negative list) → time-coded storyboard → build with `edit_motion` → critic → fix once → export |
  | `motion-craft` | The craft numbers and tells above, as rules with reasons; which reveal, seam and shot fits which beat; err slower |
  | `brand-motion` | Attributes → register, field preset, type treatment and signature move; worked examples for a technical, a calm and a playful brand |
  | `brand-assets` | Where logos, fonts and media come from, in order; the licence rules; the USE/SKIP audit |
  | `critic` | How to read a contact sheet: frame-numbered findings against the tells list, legibility (5.2% height), one hero, rhythm, brand fit. Run as a second, clean-context `claude -p` by Reco after the first preview: it sees only the sheet, the storyboard and the skill, and returns findings the first run then fixes |

- **Playbook.** The launch playbook shrinks to pointing at `launch-director`. `edit_motion`'s
  description keeps the grammar reference.
- **Storyboard.** The run writes it into the bundle (`storyboard.md`, through `edit_motion`'s
  new `set_notes`). It shows in the chat, so a person sees the plan the video was built from.
- **Done when:**
  - Each of the three runs leaves a storyboard with an arc, three directions and a signature
    move, and a critic pass whose findings were fixed.
  - The three videos differ in register and field preset.
  - Run time stays under 8 minutes.

### Q5 - Sound (M)

Moved to spec 0013 (motion sound), which replaces the bundled CC0 effects with sound generated on device from
the plan's events, after Raycast's measured soundtrack and the Supabase film's six rounds with the user.

### Q6 - New shots and the blind test (M)

- **New shots:**
  - `punchIn`: one control at 3–6×, lifted at that scale, depth of field on the rest.
  - `heroReveal`: the 60–75% moment; a full action arc of spotlight → push → rim light →
    settle, then stillness.
  - `bigType`: a statement set huge, masked, cropped.
  - `stat`: a counter that counts.
  - `finale`: earlier elements land in place around the wordmark.
- **The blind test** from *Expected outcome*, with the scores recorded here.

## Risks

- **More knobs, more ways to look generated.** The register, field presets and lint keep choices
  few. The agent never sets a curve or a colour stop.
- **Render time.** Motion blur, bloom and grain are per frame. The preview may drop to half
  resolution during playback; exports are offline.
- **Licences.** Fonts and logos follow the rules above. When in doubt, use the OFL substitute and
  the site's own files.
- **Critic cost.** A second run adds about 1 minute. It is skipped on chat edits.

## Open questions

1. Music: user file only, or a licensed library through an API (Artlist, Epidemic) at the
   user's cost?
2. Should the bar ask "is this your brand?" so the site's own font and media can be used directly?
3. Animating on twos (12 fps characters over 24/60 fps camera), as Config and Vercel did: a
   `cadence` per register, or not at all?
