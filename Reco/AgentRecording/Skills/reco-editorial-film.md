---
name: reco-editorial-film
description: Reco's editorial launch film, after ElevenLabs' "Introducing ElevenAgents Architect". Type and print on warm paper with hairline rings, pictures far out of focus, one dark beat - the wordmark opening out of its mark, mono labels blinking in, statements lit word by word, a card growing to fill the frame, a card turning into a sphere among dots, a mosaic of panels whose tiles leave by their edges, stars turning round a scanning line, registration marks framing what's shown, all hard cuts and sharp, under a film score. Use it for an AI, voice or developer product that wants a calm, premium, typographic film, and whenever the user names ElevenLabs or asks for an editorial, print-like or minimal launch film. Its reference files are read one at a time, when a step says so.
---

# An editorial film, Reco's way

ElevenLabs' launch of Agents Architect (67 s, 60 fps) makes it; `reference/film.md` has it shot by shot, measured. What it
does, and what yours must do:

- **Type is the hero.** The product's name opens out of its mark. Statements are set big and plain and lit word by word.
  Around what's read, 14 px mono caps labels blink in and grey mono lines type at 115 characters a second, as texture.
- **Three grounds, cut between.** Warm paper (`#f3f2f0`) with hairline rings magnified in the middle as through a lens;
  colour photographs far out of focus filling the frame; one dark beat. UI scenes sit on plain paper.
- **UI rebuilt as print.** White cards with 22–40 px corners, chips in hairline outlines, a black disc to send; the
  product's panels dark (`#151617`) with mono text. Never a screenshot, never glass, never a glow.
- **Things change inside a scene, sharply.** A square steps larger in cuts and grows to fill the frame; a card grows into
  the frame and is the picture; a card turns into a sphere; tiles leave by an edge; a pill opens beside the sphere. Every
  frame is sharp (no motion blur), and the camera only settles back onto a card or a mosaic.
- **Registration marks** frame what's shown: dotted hairlines across the whole frame, a solid square where they cross.
- **A film score.** Dark wide pads, a sub boom after each section's cut, high ticks on what types, a breakdown, the tonic's
  major at the peak, a burst on the logo; no drums.

Read `reference/film.md` before your first storyboard.

## The moves

Every one of these was measured on the film and rebuilt in the engine. `reference/recipes.md` has each as JSON.

| On screen | Write |
|---|---|
| The mark opens into its name and tagline | a group: mark, name (one text or a bold and a regular), tagline last; `unfold` on the group |
| A statement lit word by word as it settles | text with `brighten` (dim from the cut, a word at a time, from 1.19× to its size) |
| A tagline or a word wiped in | text with `sweep` |
| A mono label blinking in | a group of a 5×12 bar and the label, `blink` on the bar and, a frame later, on the label |
| Grey description lines | mono 14 px `#858483`, `type` at 115 characters a second |
| A square stepping larger | `morph` with `duration` 0.0167 (a frame) at each step, a little larger each time |
| A card growing to fill the frame | a rectangle with a `picture`, `grow` |
| A card turning into a sphere | `morph` to a square size with radius half of it, then smaller |
| Dots born round the sphere | `dots` on the card |
| Stars turning round a line | `orbit` on its box |
| Registration marks | `marks` on the layer or group, from the scene's start |
| Tiles leaving | `morph` to a 1 px side with the anchor at the edge it shrinks to, `hide` (a cut), or `exit` with a direction |
| A pill opening beside the sphere | a white pill anchored at its left edge, `show` then `morph` to its width; the sphere `morph`s `to` its left end |
| Contents swapping on a cut | `show` and `hide` |

## Transitions

- `cut` almost everywhere: on paper, between pictures, into ink. Moves land on the cut (the card grows from its first
  frame, the statement is there dim).
- `wipe` once: a picture sweeping in from the right over the wordmark, into the first card on a picture.
- `fade` into the dark beat and out of it.
- Nothing else: no whip, dive, melt, glow, dither, ring, stack or expand.

## The look

- **Canvas:** `{"size": [1920, 1080], "frameRate": 60, "background": "#f3f2f0", "field": "plain", "pacing": "beats"}`.
- **Style:** `text` `#1b1a19`; `accent` the product's colour toned down to a slate (`#5e658c` for a blue or violet brand),
  for the tagline only.
- **Sound:** `{"style": "editorial"}`.
- **Scene fields:** `paper` for type alone (the opening, the wordmark, the sphere, the end card); `plain` for UI scenes;
  `lens` with `picture` for a card or words on a photograph; `ink` for one statement. The scanning beat is `plain` with a
  full-frame `#171717` rectangle first.
- **Pictures** (`lens` scenes and a rectangle's `picture`): pick by the brand's hue. Cool: `sky`, `mist`, `indigo`, `dusk`,
  `violet`. Pink and red: `petal`, `rose`, `bloom`. Warm: `sand`, `dune` (white type is faint on these two: keep words off
  them). One picture a scene; a card that grows hands its picture to the scene it fills.
- **Type:** sans `regular` for statements and the name's second word, `bold` for the mark and the name's first, `medium`
  for chips; mono for labels. Never `semibold` headlines, never all caps but the labels.

## Which skill

| The film | Skill |
|---|---|
| Editorial: type, paper and pictures, a film score (this one) | reco-editorial-film |
| A light product, flowing transitions on a white ground | reco-flow-film |
| A dark product: one person's job told through it | reco-story-film |
| Motion design: one object morphing state to state | reco-motion-design |
| The real UI up close, typed into and toured | reco-launch-film |

## Method

1. **Research.** Call inspect_page on the product's site and the pages its navigation links to. Find its name and mark,
   what it does in four to six verbs ("ANALYZING CONVERSATIONS", "WRITING FIX"), its main input (a prompt, a request)
   and a real request a user would type, what it gives back, the tools it connects to, and its closing line. Web search
   what it's for, if you can.
2. **Story.** Follow the reference's arc in 12–14 scenes; `reference/example.md` is all of it, rebuilt:
   1. the mark opens into two or three words (`unfold`), 2 s;
   2. labels blink in round a picture square that steps larger and grows to fill the frame, 2.4 s;
   3. the wordmark opens: mark, name, tagline, 3 s;
   4. `wipe` to a picture: the request card (outline, white fill sweeping from the right, a chip, the request typed), 3.4 s;
   5. the steps it takes as icon tiles framed by marks, 2.4 s;
   6. `fade` to the dark beat: what it's doing ("Scanning conversations…"), stars turning, the line lit, 3.2 s;
   7. a mosaic of its panels and pictures; tiles leave by their edges, one card stays, 2.8 s;
   8. that card turns into a sphere among dots; the input pill opens beside it, 2.8 s;
   9. the input on a picture card, a request typed, 3 s;
   10. a statement on ink, brightened, 2.9 s;
   11. a card grows into "Connect <name> to — <tool>", the tools cutting by every 0.667 s on their own pictures, 3.6 s;
   12. a sphere shrinking as two words part ("Improve ● your agents"), 1.75 s;
   13. a last statement brightened on paper, 2.5 s;
   14. the wordmark unfolds again and holds, 5.3 s.
   Words are the product's own, short and plain: never hype.
3. **Assets.** Rebuild everything as shapes and type. The mark is a text glyph when the logo is letters, else the logo
   lifted `bare` as a `ui` layer, first in the wordmark's group. Pictures are the engine's (`picture`), never lifted.
4. **Write the scenes.** Copy the components from `reference/recipes.md`: read it now. Write the whole document in one
   edit_motion call.
5. **Check.** Call preview_motion and look at every frame:
   - Is the wordmark one line, centred, the mark first, nothing overlapping?
   - Is every statement 68–92 px and whole in the frame, every label a group of a bar and its text?
   - Is the request card's text inside it, the pill's text clear of the sphere?
   - Does each picture suit the brand, and does the grown card's picture match the scene after it?
   Fix everything in one edit_motion call. Stop after three previews.
6. **Export** with export_recording: format hevc, resolution 2160, and no frame_rate (the film's own 60 fps).

## Sizes

- The wordmark 63 px. Lay it out left to right from the group's position, each text anchored at its left (`anchor`
  [0, 0.5]): about 0.45 em a character (28 px at 63 px; the film's ran 0.40–0.51), 0.2 em between the name's words,
  0.43 em before the tagline; then move every x so the line's middle is at 0. Check the gaps in the preview.
- An opening line or statement on paper 68 px; on ink 92 px; centred (`anchor` [0.5, 0.5]).
- Labels 14 px mono caps, their bar 5×12 `#1a1918` 17 px before the text, at x 258 and 1394, rows 100–400 px apart.
- The request card 1500×700, corners 40; its chip text 40 `medium`; the request 58; the send disc 112.
- Mosaic columns at x 0, 454, 648, 1144, 1266, 1920 and rows at y 0, 96, 358, 721, 1080, 3 px gutters, corners 6.
- The sphere's card 790×471, corners 34; its outline frame 1130×790, a 2 px stroke `#d0cfcc`; the pill 628×101.

## Never

- Motion blur, a drifting camera, glass, glows, gradients on type, shadows on cards.
- A seam other than a cut, one `wipe` and the `fade`s into and out of the dark beat.
- Fades on words (they pop, blink, sweep or type), or words on `sand` and `dune`.
- Screenshots of the product; text under 32 px that isn't a mono label or description.
- Hype copy, exclamation marks, emoji.

## From the chat

Change only what's asked. "Faster" is about two thirds of the timings. Preview once; don't export unless asked.
