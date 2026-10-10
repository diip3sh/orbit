# Flow films

> A fourth kind of launch film, after two light AI launch reels: one unbroken flow on a white ground lit by the brand,
> where every scene grows out of the last. It ships as the `reco-flow-film` skill, the default for a product whose own
> UI is light. With it the engine gets a light ground (`haze`), two transitions (`dive`, `melt`) and two moves (`fly`,
> `select`).

## Why

On 2026-10-10 the user shared two reels and asked for "another skill … some from this also good transitions … and some
videos":

- Vantae (`https://video.twimg.com/amplify_video/2101405161251852288/…/OjqwgHp-eCe7HZnJ.mp4`, copy at
  `~/Movies/Reco/references/new/ref-a.mp4`);
- IrukaDark (`https://video.twimg.com/amplify_video/2024600439690260480/…/GMr_TkMNM0mmKMp-.mp4`, copy at
  `~/Movies/Reco/references/new/ref-b.mp4`).

Before it, every launch film was on a dark ground (satin, Paper's looks, the aurora): light products such as cal.com and
Granola were forced into black.

## The references, measured

Shot by shot in the skill's `reference/film.md`. In short:

| | Vantae | IrukaDark |
|---|---|---|
| Length, size | 18.7 s, 1920×1080, 30 fps | 40.5 s, 3840×2160, 30 fps |
| Ground | A deep blue blob (`#0436e7` → `#0b92f6`, a pale band `#cbecf8`) turning round `#f5fbfd` | A pastel orb (orange `#f7ca91`, pink `#e4b3cc`, lilac) on `#fcfcfc` |
| Still (0.1 s steps under one level at 160×90) | 1 %, median change 5.7 | 22 %, median change 2.9 |
| Transitions | a melt of the ground into a meadow; a dive through the glass prompt; a melt of the picture into the ground | the question becoming the search bar; the mark flying in; a key opening into an error; a selection explained by a panel coming up; tabs cycling |
| Music | house at about 126 BPM, −35.1 LUFS | breaks at about 176 BPM with a filter sweep into its drop, −27.3 LUFS |

## The engine

| Part | What | Files |
|---|---|---|
| `haze` field | The aurora's soft lights read through a ramp from paper white (L 0.985) into `style.gradient` (pale to deep): a weak light a tint, a strong light's heart the gradient's last colour; five setups (an orb, a deep blob from a corner, faint corners, a wash from below, the blob from the other side); its lights wander 6× as far and 5× as fast as the aurora's and swing up to 0.4 rad | `AuroraSetup+Haze.swift`, `FieldPalette`, `FieldRenderer`, `auroraField` |
| `dive` seam | The scene before magnified log-evenly about what it clicked last (else its middle) until it covers the frame (1.1× past), tilting up to 16° about it, seen from 2.5 frame heights; the next scene through it from 0.6 of its size out of a 14 px blur; a 2.5 px rim at 0.7; 0.8 s on the in-out `move` easing; motion-blurred by its magnification | `MotionFrameRenderer+Seams` |
| `melt` seam | The frame dissolves into the next along a front ordered 60 % by its light (blurred 18 px: darks first) and 40 % by place from the top left, broken by 2 px grain; at the front the scene before runs down 14 px and turns to the haze palette's deepest and palest colours; 0.75 s | `meltSeam` kernel, `MotionFrameRenderer+Seams` |
| `fly` move | From 0.6 of the frame's width to the side and 0.3 of its height above (or below), across on out-quart and down on in-out cubic so it swoops, turned 30° and banking level past it (out-back), from 0.7 of its size, 0.9 s | `MoveExpansion+Flow` |
| `select` move | A text's characters selected in order, a box a line, at 60 characters a second (at least 0.35 s), eased in and out, in the macOS selection blue unless `color`; the arrow presses at its start and follows its end, held 0.5 s after | `TextSelection`, `MotionFrameRenderer+Flow`, `MotionPointer` |
| Sounds | dive: a riser and whoosh at its fastest, a thump and glass as it lands; melt: a shimmer and a low glass; fly: a whoosh at 0.3, a glass on landing; select: a key on its press | `SoundCueList+Story`, `SoundRules+Story` |

Other changes:

- On a light ground (`MotionPlan.isLight`) what goes behind a `stack` or `expand` dims to 0.15 black, not 0.55: over white,
  0.55 turned the page a dirty grey.
- The expand and dive sources follow the scene before as it goes on under the seam: with its camera drifting, the dive's
  window slid off the send button.
- The lint lets a story film's first move land on its cut (the story skill asks for it since its sound left the beat), and
  any scene after a seam other than a cut.

## Measured

- **Look-dev:** Vantae's reel rebuilt as a document (`~/Movies/Reco/quality/flow/Vantae Rebuild.motion`, the skill's
  example) and IrukaDark's pieces (`Iruka Rebuild.motion`). At first Vantae's rebuild was still in 53 % of its steps
  (median change 0.9): slow pushes (intensity 0.4–0.9) over white move few pixels. With the haze's faster wander and pushes
  at intensity 2.5–3 it is still in 15 % (median 2.8). IrukaDark's rebuild is still in 39 %: its quiet seconds match the
  reel's own (1–1.4 while a line is read); the reel's busy seconds swoop harder (10–33 against 5–12).
- **Melt, first version:** ordered by light alone, a white frame went at once, a whole frame of blue grain. The order by
  place gives a plain frame a front.
- **Speed:** each 18–20 s rebuild exports at 1080p60 in 13–17 s (M5, Debug).

## The skill

`reco-flow-film`, with `reference/film.md` (both reels shot by shot), `recipes.md` (every component rendered and checked:
the need typed huge, a line that becomes the search, the input bar, a macro on send and the dive, picking one, the answer
growing out of the box, a key that opens, a sentence selected and explained, contents cycling, the end) and `example.md`
(Vantae's reel rebuilt, 17.3 s). The prompt's skill choice: the flow film for a product whose own UI is light or when the
user asks for flowing transitions or a light film; the story film for a dark one.

## Open

- Vantae's camera tracks its huge type and its prompt's caret; a `voice` follows its caret only past the frame's width.
- IrukaDark's 3D swoops (tabs stacked in perspective, the bar tilting) have no move yet: `tilt` turns one layer.
- A picture going from duotone to colour (Vantae's result) has no move.
- Nobody has listened to the new sounds.
