# Motion design films

> A second kind of launch film, after product motion design such as LordyVisuals' Spotify Jam concept. The UI is
> rebuilt as shapes, type and lifted parts. One object morphs from state to state, letters spring in, a pointer
> clicks, the frame floods and bursts, all cut to a beat. It ships as its own agent skill, read a file at a time,
> and combines with spec 0012's macro films for longer videos.

## Why

Every Reco film so far follows New Raycast: real UI in macro on glass. On 2026-10-08 the user pointed to a
second kind (`https://video.twimg.com/amplify_video/2107597628976336896/…/e42KoAaPFPjBMHy4.mp4`): Spotify's
Queue and Jam, rebuilt as motion design. The user wants three things:

1. Reco can make films like it.
2. The method lives in a separate skill that Claude loads only when a film calls for it (by the product, the
   user's words or the film's length), reading its references a file at a time so the context doesn't bloat.
3. A Spotify film of this kind, made from the app, with its movements named in the request.

The user keeps Reco's grounds (satin, light, dither): "video gradients are not that good, we can keep our".

## The reference, measured

The reference is 1024×576 at 30 fps, 30.4 s long. Its content ends at 19 s and the rest is black. A copy is at
`~/Movies/Reco/references/spotify-jam-lordyvisuals.mp4`. Times are seconds into it; sizes are at 1080p (×1.875).

| Time | What happens |
|---|---|
| 0–0.4 | A green glow sweeps up the ground. "Queue / Playing Songs … Clear" rises 107 px to rest. |
| 0.4–1.6 | Rows build in about 0.35 s apart. Each row's art fades and scales in, then its title types in (about 30 characters a second), then its icon pops. The list moves up as it grows. |
| 1.6–3.2 | The list scrolls fast, with motion blur, and rows build as they come into view. It eases to rest on the last three rows. |
| 3.37–3.77 | A green dot under the list grows into a pill: 340 → 590 px wide in 0.4 s, eased out. |
| 3.8–4.9 | "This is different" comes in word by word inside the pill. The pill rises to the middle and glows. |
| 4.5–4.9 | "This" drops and "different" lifts away. An icon draws in. |
| 4.87–4.97 | Hover: the pill grows 15 % in 0.1 s. "Start a Jam" springs in a letter at a time (11 letters in 0.4 s, 0.036 s apart, each overshooting). |
| 4.8–5.2 | An arrow pointer rises from below and becomes a hand over the pill. The press shrinks the pill back by 5.2 s. |
| 5.77–5.93 | The pill dips to 0.6 of its size (0.17 s). |
| 5.97–6.33 | Flood: the pill grows past the frame's corners in 0.37 s, fast then settling. A "Starting" chip stays in the middle. |
| 6.33–7.13 | All green. Lighter and darker rings open outward from the middle. |
| 7.13–7.33 | Iris: the green closes to an oval. A hard cut at 7.33 (on a beat) to a small pill. |
| 7.4–8.0 | The pill's fill drains to an outline. Three avatars slide in, blurred by their speed, then a "3". |
| 8.0–8.5 | The outlined pill moves left. "Invite" and then "Leave" slide out of it as their own outlined pills. |
| 8.4–9.2 | The hover's green outline moves from Invite to Leave. |
| 9.3–9.7 | Invite fills green and lifts. The others blur away. Invite shrinks to a dot, motion-blurred. |
| 9.8 | The dot stretches into a tall caret. A green pulse lights the ground. |
| 10.0–10.8 | "Black & Tan" is typed big and bold, about 13 characters a second. The newest letters are green, fading to white, behind a thick green caret. |
| 10.4–11.5 | A pointer arrives and clicks the words. The camera pushes in 25 %, and the caret goes. |
| 11.7–12.6 | The words become the song's row. The camera pans along it to a "+", which spins in. |
| 12.7–12.9 | Hover: a grey disc pops behind the "+" (overshoots to 1.6×, settles in 0.2 s). |
| 13.0–13.4 | The disc fills green from the middle. About 40 green triangles burst out and drift. A check draws in, and a ring pulses out. |
| 13.8–14.0 | The camera pulls back. The check becomes the row's icon in the queue. |
| 14.0–16.8 | The queue builds again under the song and scrolls fast to its end. |
| 16.9–18.0 | The Spotify logo sharpens up from under the list as the list leaves. |
| 18–19 | The logo fades out. |

What makes it good:

- **One object, not shots.** There is one hard cut in 19 s. Every other change is a morph: list → dot → pill →
  flood → chip → split pills → dot → caret → type → row → "+" → check → row → list.
- **Cut to the music.** The track is about 125 BPM (beat 0.48 s, kick autocorrelation). The hard cut lands on a
  beat (7.29), and so do the flood and the burst.
  - −14.3 LUFS integrated, 64 % of the energy under 200 Hz: a hip-hop track.
  - It ends with the logo, at 19 s.
- **Micro-interactions.** Hover, press, a pointer that turns to a hand, a selection outline that moves.
- **Overshoot.** Letters, pops and hovers overshoot and settle. Raycast's films never do; this kind always does.
- **Motion blur** on every fast move: the scroll, the slides, the dot.
- **Restraint.** Black, one brand green, white type, the UI's own art.
- **Weak:** its ground, a flat green gradient at the top. Reco's light and dither looks replace it.

## Expected outcome

- A document can hold this kind of film:
  - shapes that morph (size, corner radius, colour, outline, place) and glow;
  - letters that spring in;
  - kinetic typing behind an accent caret;
  - pops, presses, a pointer that clicks;
  - a flood, bursts, ripples;
  - a list that scrolls, its rows building as they come into view.
- Each piece is a named move with measured defaults. Agents never write keyframes for it.
- The sound marks the new events with the existing voices: pops, presses, the flood, bursts, keys.
- **`reco-motion-design`**, a second bundled skill. Its `SKILL.md` is the method in short. Five reference files
  are read only when needed: the film beat by beat, the moves, recipes, combining with macro films, and a whole
  example. Claude Code reads them with `Read`, allowed only inside `.claude/skills/`.
- Launch prompts let the agent choose a skill, or both for a longer film, from the product and the user's words.
- A Spotify film made from the app, whose request names its movements.

## Approach

### Document

- `ShapeContent`:
  - `stroke`: an outline that wide; none means filled.
  - `kind`: `rectangle` (the default) or `triangle`, for particles.
- `LayerShadow.color`: a shadow in a colour with no offset is a glow.
- Glyphs as shape `kind`s (not a new content type): plus, check, cross, arrow, search, play, pause, and a filled
  triangle for particles. They are drawn as strokes at any size. SF Symbols aren't licensed for use in third-party
  product films.
- New `MotionMove` fields: `size`, `radius`, `color`, `stroke`; `to` is reused for position.
- New moves:
  - `morph`: to a size, radius, colour, outline and place, chained.
  - `flood`: a dip, then out past the frame's corners.
  - `pop`, `press`, `click` (a pointer comes, turns to a hand, presses), `burst`, `ripple`.
  - `letters` (springing in) and `kinetic` (typed behind an accent caret).
  - `scroll`: to `to`, eased in and out. A group that cascades and scrolls builds its rows as they come into view.

### Plan and frames

- A shape with morphs gets a `ShapeMorph`, a chain of states resolved from its moves in start order. Its size,
  radius, colour and outline are generated per frame (`CIRoundedRectangleGenerator`, `…StrokeGenerator`), and
  so is its glow. Placements use the layer's size at that time.
- A morph's `to` and a scroll's become additive position tracks: each one is the difference from the place the
  one before left it.
- Bursts and ripples expand into particle and ring layers beside their source (`DocumentExpansion`), keyframed
  and seeded from the layer's id, so they look the same every time. Nothing new is drawn per frame.
- A click puts a pointer on the scene, drawn after its layers. It follows the target layer's centre, uses the
  system's arrow and pointing hand (read on the main actor once), and presses the target.
- `letters` and `kinetic` are `TextReveal` styles. The caret and the accent tint are drawn in `revealed`.
- `MotionEasing+Grammar` gains `overshoot`, a cubic Bézier that passes its end and settles, used only by this
  kind's moves.

### Sound

New cues from the plan, through `SoundCueList`, levels in `SoundRules`:

| Event | Cue |
|---|---|
| `pop` | A blip a step up the chord |
| `press`, `click` | A key |
| `flood` | A riser into the fill and a thump at it |
| `burst` | A glass pair |
| `kinetic` | Keys at the letters' times |
| A fast `scroll` | A whoosh at its peak speed |

### Skill

`AgentRecording/Skills/reco-motion-design*.md` are installed as `.claude/skills/reco-motion-design/SKILL.md`
and `reference/*.md`. For Claude Code, `--tools` adds `Read`, and `--allowedTools` adds only
`Read(./.claude/skills/**)`. Other agents get the `SKILL.md` body inline.

## Phases

| Phase | What | Status |
|---|---|---|
| D1 | Model: shapes, glow, icons, the new moves and their validation | Done |
| D2 | Plan and frames: morphs, expansions, pointer, reveals | Done |
| D3 | Sound cues | Done |
| D4 | Skill, prompts, catalog, permission | Done |
| D5 | Look-dev: the reference's beats rebuilt by hand, stills beside its frames | Done |
| D6 | The Spotify film from the app | Done |
| D7 | Smoother: the reference's transitions measured again, the engine and the skill after them | Done; the user's verdict next |

## Open questions

- A groove (kick, hats, bass) at the film's tempo, which this kind is cut to. It is left out for now: the
  existing score and effects mark the beats, and the sound memory warns against designing from taste.
- A check that draws itself on (a stroke's end). For now it pops in, which reads the same at 30 fps (the
  reference draws it in 0.1 s).

## Progress

### D1–D4: the engine and the skill

- **Built.**
  - The moves, `ShapeMorph`, `BurstExpansion`, `MotionPointer` and `ShapeGlyph`.
  - The reveals, sound cues and lint changes.
  - The skill: `SKILL.md` plus `reference/film.md`, `moves.md`, `recipes.md`, `longer.md` and `example.md`.
- **Tests.** `MotionDesignTests` checks:
  - morph chains, places and colour;
  - the flood's coverage and a morphing pill's drawn size;
  - pops and presses, letters and kinetic timing;
  - bursts and ripples (seeded, ordered, coloured);
  - rows building on scroll, the pointer's place;
  - outlines and glyphs, the toned-down field, validation, each event's sound.

  `AgentInvocationTests` checks that both skills are installed with the restricted `Read` and that the example is
  a valid, lint-clean document.
- **Permission.** A headless `claude -p` with `--tools Skill,Read --allowedTools Skill "Read(./.claude/skills/**)"
  --permission-mode dontAsk` read its skill's reference file. It was denied `../outside.txt` and said so.

### D5: look-dev against the reference

The reference's beats were rebuilt as one document from Spotify's web player and exported through the app's MCP
(`~/Movies/Reco/quality/design/`):

- Spotify's player renders signed-out at a phone viewport. The n-th row is
  `div:nth-of-type(n) > [data-encore-id=listRow]`, 382×64 CSS px, 64 px apart.
- **Scale.** The first pass was half the reference's. At its scale everything read: rows 1070 px wide and 215
  apart, the pill 560×184 with 64 px type, kinetic type 150 px, the hand 8 % of the frame.
- **Ground**, compared at nine moments beside the reference:
  - Ember at full strength and sunlit (teal and grey from the green's palette) swamped the UI.
  - Bloom put a blob behind it.
  - Satin and plain were closest in value but carried no brand.
  - Ember at 0.45 kept the brand's light in two corners with the middle dark, so `fieldStrength` was added.
- **Fixed on the way:**
  - A still outline drew filled.
  - Flood rings were drawn under the flood.
  - Particles took a disc's colour from before it turned green.
  - The pointer was sized by its image, which has clear margins (3.5 % of the frame instead of 8 %).
  - The stroke generator draws inside its extent.
- **Lint, from the example's findings:**
  - A label on a control was checked against the ground (1.0:1) and held to reading time.
  - A click after a text's entrance counted as its entrance.
  - A burst's own move and its particles counted twice.
  - A toned-down field counted as busy.

  Its real findings (three moves in 0.1 s at the iris and at Invite's choice) were fixed in the example by
  staggering, as the reference does.
- **The example** is 22.4 s: −16.0 LUFS, −2.5 dBFS peak, exported at 1080p in under 20 s. Its frames match the
  reference's at every beat: the queue, the pill, the click, the flood with bands and chip, the outline with
  listeners, Invite chosen, kinetic type, the check in a burst.
- **Open:** Spotify's nav logo lifts with an opaque grey box (`#6b7885`) behind it, even bare and at a phone viewport.
  (D7: the same logo from www.spotify.com's header, `header svg`, lifts clean.)

### D6: the Spotify film from the app

The film was made by `reco://record-agent?mode=launch&url=https://open.spotify.com` with a request naming its
movements:

> the Queue builds and scrolls fast with motion blur; a green dot grows into a pill that reads Listen together,
> then Start a Jam springs in letter by letter; a click floods the frame green with rings; it shrinks back to a
> pill of three listeners that splits into Invite and Leave, the hover moving between them; Invite becomes a dot,
> then a caret, and a song title is typed big; a plus turns into a green check in a burst; Spotify's closing

- **The run.** Claude Code, default model, 9 min (18:28–18:37 on 2026-10-08).
  - It chose `reco-motion-design` itself and built from its recipes: Spotify's own rows, the pill, Invite and
    Leave, kinetic "Patient Zero", the add, the song landing in the queue, and the closing.
  - It added a sixth scene of its own, the song landing back in the queue, as the reference does at 14–17 s.
- **The film** (`~/Movies/Reco/Spotify Jam-edited.mp4`): 30 s at 4K, −16.0 LUFS, −2.1 dBFS peak.
- **Against the reference.** `~/Movies/Reco/quality/design/Spotify Jam vs reference.png` compares eleven matched
  moments.
  - Every beat is there in order, at the reference's scale.
  - Weaker:
    - The ending: small mono caps on black for 7.8 s, where the reference ends on the green logo (the logo lift
      problem above).
    - A softer green and glow than its neon.
    - No icon in the pill.
- **Full suite:** 847 tests. Only `ExportServiceTests.keepsATransparentBackgroundInProRes4444` fails (alpha 254),
  as before.

### D7: smoother, after a second look at the reference

The user found the D6 film good but its transitions and animation not yet professional. The reference and the film
were compared frame by frame at every transition (strips of 24–36 frames). The reference is never still and never
waiting: each move starts before the last settles, new things come out of what is there, and the camera carries the
changes it doesn't cut. The engine's moves were measured again where they read differently.

- **Letters** (`TextReveal.letterPose`): tracked letter by letter in "Start a Jam" (the pill's own lift taken out), each
  comes up from about 0.7 of its line below at a third of its size, is at 1.35× a quarter line above its place 0.1 s in
  (its height 39 px against 24 at rest, the hover's 1.2× taken out), and falls back over 0.3 s in-out with no second
  bounce. Before, letters rose 0.45 of a line with CSS's out-back (10 % past) and read as a fade. A letter reveal's
  image has room around its text (half a line across, a line up and down, whole pixels), projected onto the quad grown
  by the same room (`Placement.roomCorners`), so letters travel outside their line.
- **The hover** lifts the pill about 75 px and grows it 20 % in 0.1 s (it had grown 10 %); the press brings it back.
- **The flood** (`ShapeMorph`): its widths a frame apart were 0.19 (dipped), 0.37, 0.54, 0.66, 0.76, 0.84, 0.90, 0.96,
  0.99 and 1.0 of the frame, out-cubic, at an aspect near the frame's (1.95). It now grows into the frame's shape,
  corners 0.35 of its height round, 1.05× what covers the frame from where the shape is. Grown round at the pill's
  aspect it had to reach 3–4 frame widths, and filled the frame in two frames. The dip measured 0.57, not 0.6.
- **Bands** (a ripple with a stroke on a rectangle) are drawn inside its shape, from a tenth of its size out to its
  edge, so they open in the flood's shape and leave with the iris; drawn as rings over it, they hung over black after
  the iris. A thin ripple's rings open by half the layer's side (they crossed the frame) over 0.7 s.
- **Particles** are drawn at the frame's own time under motion blur (`Layer.isSharp`, `BurstExpansion.isParticles`),
  and don't count towards how far the frame moves: a 180° shutter streaked them into rays, where the reference's are
  sharp. They spread 1.4× farther across than down.
- **The pointer** comes up from below the frame in 0.3 s, out-cubic (the reference: 0.76, 0.65, 0.6 of the height 0.2,
  0.13 and 0.07 s before it lands); it had drifted in over 0.5 s, faded. Its travel counts towards motion blur, so it
  streaks as the reference's does.
- **`spin`**: a quarter turn into place, overshooting, 0.5 s: the reference's plus spinning in.
- **Pans chain** (`MoveExpansion.cameraContexts`): each camera move starts where the moves before left the camera, so a
  pan in on the plus and a pan back out show the check landing in the queue without a cut. Before, a second pan was
  computed from the scene's start and did nothing.
- **Kinetic type's caret** is there 0.3 s before the first letter, so the caret the scene before stretched out of a dot
  holds across the cut.
- **Lint:** a motion-design scene holds still for at most 0.72 s (a beat and a half at 125 BPM, 1.5 s otherwise); a
  group and its layers count once among simultaneous starts.
- **The skill** says all of this: never still, things out of each other, the camera carrying the change, a cut only
  where a shape continues; its recipes and example are the new look-dev.
- **Look-dev** (`~/Movies/Reco/quality/design/Jam Smooth.motion`, made and exported in the app): 19.4 s in four scenes,
  lint-clean, exported at 4K in 2 min. The pill grows as the list leaves; the hover lifts it; the chip is in the flood
  from its start; Invite and Leave slide out of the outline; Invite flies to the caret's place; the carets meet across
  the cut to the pixel; the camera pans in on the plus and back out into the queue, which scrolls away to the logo.
- **From the app:** the D6 request (its ending changed to "the queue scrolls away to Spotify's logo") made `Spotify Jam
  2` in 6.3 min (20:29–20:36): the agent built from the new example with its own words ("Listen together"), lint-clean;
  19.4 s at 4K, −16.0 LUFS, −3.9 dBFS peak.
- A test helper read Core Image's bitmaps bottom-up (`MotionDesignTests.pixels`): the shapes it measured are symmetric,
  so no test had noticed.

