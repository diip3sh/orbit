---
name: reco-flow-film
description: Reco's light launch film, after two AI launch reels (Vantae, IrukaDark). One unbroken flow on a white ground lit by the brand's colour, where every scene grows out of the last - a typed line becomes the input, a click dives through it into what it made, a picked thing opens into the next step, a text selection gets its answer, the last picture melts into the ground and the logo's mark flies onto its name. The product's controls are rebuilt light (white bars, cards, its colour on the buttons), the camera never rests, and each transition has its own sound. Use it for a product whose own UI is light, and whenever the user asks for flowing transitions, a light or clean film, or names these reels. Its reference files are read one at a time, when a step says so.
---

# A flow film, Reco's way

Two light reels make it (`reference/film.md` has both shot by shot, measured):

- **Vantae** (18.7 s): "Have an idea?" typed huge, a glass prompt, a click that dives through it into a ring of pictures, one
  picked and dragged into the next prompt, the answer growing out of the box, the picture melting into the logo's ground.
- **IrukaDark** (40.5 s): a question popping a word at a time that becomes the search bar, the logo's mark flying in, a
  key that opens into an error, the error selected and explained by a panel sliding up, the app's tabs cycling, the mark
  flying onto its name.

What they share, and what yours must have:

- **One flow, no slideshow.** Every scene comes out of the one before: what was clicked opens, what was typed becomes the
  input, what was made grows out of the box. You can say why each scene follows the last.
- **A white ground lit by the brand.** `haze`: white with the brand's colour as soft light that drifts and turns, a
  pastel orb behind type, a deep blob sweeping in from a corner behind UI. It is never still.
- **Light UI, rebuilt.** The product's input and answers as white bars and cards with soft shadows and a pale rim, its
  colour only on its buttons, chips and marks, ink type. Never a screenshot.
- **The camera never rests.** Every scene pushes in, pulls back or drifts; macros drift along the control. Vantae is
  still in 1 % of its frames.
- **A hand on every action.** The pointer comes in, presses the send, picks one of the results, drags across a sentence.
- **Transitions you hear.** Quiet chords change with the shots, and each transition has its own sound: the air and glass
  of a dive, a melt's shimmer, a flight's whoosh, a key on a click.

Read `reference/film.md` before your first storyboard.

## Transitions

Every change of scene is one of these, and you can name its reason:

| What happens | On the next scene |
|---|---|
| A click sends something and the next scene is what it made | `"seam": "dive"`: the camera tilts and flies through the clicked control into it. Make it the scene's last click, pressed in its last 0.5 s |
| A click opens a thing (a result, a key, a chip, a card) into the next step | `"seam": "expand"`: the next scene opens out of the clicked thing |
| An answer comes over what was asked (a panel over a page, a sheet over a list) | `"seam": "stack"` |
| Into or out of a picture, the ground or the ending | `"seam": "melt"`: the frame dissolves by its own light into the next, its front in the brand's colour |
| A macro on the control the last scene showed whole, or the same thing going on | `cut`, the thing there on the first frame |
| The next scene moves on its first frame: a voice line typing, a pop at 0, a scatter | `cut` |

- Never the same seam on two scene changes running. Use at least `dive`, `expand` and `melt`, and `stack` when an answer
  comes over a question.
- Inside a scene, a change is a move, never a cut: the box `morph`s into a card, a thumbnail `morph`s (with `to`) into the
  result, a line is `select`ed, a mark `fly`s in, contents `show` and `hide` on a beat.
- `melt` opens the film's second scene or closes it; a dive after a click on send; an expand after a pick.

## The look

- **Ground:** `"field": "haze"` on the canvas, and every scene on it. `canvas.background` the white it lies on, a breath
  of the brand: `#f5f9fd` for a blue brand, `#fbf9fa` for a warm one.
- **Gradient:** `style.gradient` is the light's colours from pale to deep: 2–3 colours of the brand. A strong, saturated
  brand (Vantae's blue) runs to its deepest colour: `["#7cc4fa", "#0b92f6", "#0436e7"]`. A soft brand (IrukaDark's
  pastels) stays light: `["#e9d5ff", "#f9a8d4", "#fdba74"]`. Never colours the brand doesn't have.
- **Type:** ink (`#0d1220`, or the product's text colour) on white; `accent` the brand's colour (the send button, the
  typing caret, the mark).
- **Surfaces:** white (`#ffffff`) with the soft shadow `{"opacity": 0.16, "radius": 40, "offset": 14}`, a 2 px rim in a
  pale tint of the brand (`#d3e3f8` for blue); pills and chips `#f1f4f8`; the primary button filled in the brand's colour
  with a white glyph. A dark product panel (IrukaDark's) may stay dark: one card, never the ground.

## Which skill

| The film | Skill |
|---|---|
| A light product, or flowing transitions on a light ground (this one) | reco-flow-film |
| A dark product: one person's job told through it, on a dark shader ground | reco-story-film |
| Motion design: one object morphing state to state (Spotify Jam) | reco-motion-design |
| The real UI up close, typed into and toured, Raycast's look | reco-launch-film |

## Method

1. **Research.** Call inspect_page on the product's site and the pages its navigation links to. Find its main input (a
   prompt, a search, a command bar, an editor, a booking form) and its send or confirm; what it gives back (pictures,
   answers, files, events, results); its brand colour, text colour, fonts and logo. Web search what it's for, if you can.
2. **Story.** One person's need, in 5–7 beats, each growing out of the last:
   1. the need, as a short line typed huge (`voice`) or popping a word at a time (`wordByWord`), e.g. "Have an idea?";
   2. the input arrives (or the line becomes it), the request is typed, a macro on send and the hand presses it;
   3. `dive` into what it made: results popping, scattering or turning in;
   4. the hand picks one, which `expand`s into the next step (a second ask, a detail, an edit);
   5. the answer grows out of the box (`morph`), or comes over the question (`stack`), or a sentence is `select`ed and
      explained;
   6. optional: a statement typed big;
   7. `melt` into the end: the logo's name, its mark flying in (`fly`), a tagline.
   Lines are short and plain, the person's or the product's own words: never hype.
3. **Timing.** 18–30 s in 8–12 scenes, each 1.2–3 s. A macro 1.2–1.6 s; a typing scene as long as its typing plus 0.6 s.
4. **Assets.** The logo lifted `bare` from the site (or its mark as SVG from Simple Icons, `reference/recipes.md`). Real
   pictures the product makes (an `img` that is still and sharp) may be lifted for the results; otherwise rebuild them as
   shapes in its colours. Rebuild every control as shapes and type. Write all assets in one edit_motion call, then call
   capture_ui.
5. **Write the scenes.** Copy the components from `reference/recipes.md`: read it now.
6. **Check.** Call preview_motion and look at every frame:
   - Does every scene come out of the last, by the transition the table names?
   - Does the camera move in every scene, and does something else move in every second of it?
   - Is every surface white with its shadow and rim, the brand's colour only on buttons, chips, marks and the light?
   - Is the type at least 40 px (34 for a note), and every answer whole in the frame?
   - Does the hand land on what it presses, and is the dive's or expand's click the scene's last?
   Fix everything in one edit_motion call. Stop after three previews.
7. **Export** with export_recording: format hevc, resolution 2160, and no frame_rate (the film's own 60 fps).

`reference/example.md` is a whole document of this kind: Vantae's reel rebuilt. Read it for how the parts fit.

## Settings

- **Canvas:** `{"size": [1920, 1080], "frameRate": 60, "background": "<white with a breath of the brand>", "field": "haze",
  "pacing": "beats"}`.
- **Style:** `text` ink; `accent` the brand's colour; `gradient` pale to deep (above); `face` sans.
- **Sound:** leave `sound` out: quiet chords and the transitions' sounds.
- **Sizes:** an opening line 160–200 px `regular`; a statement 110–140; a line popping word by word 64–80; the input bar
  1240×140, corners 70, its text 52, its send disc 96; cards 900–1100 wide, corners 36–40; names in cards 44 `semibold`,
  notes 34–40; the end name 120–140 `semibold`, its mark 110–120 in the brand's colour, corners a third of it.

## Never

- A dark ground, a shader look other than `haze`, or two grounds in one film.
- A scene with a still camera, or a second with nothing moving but the ground.
- A scene that doesn't come out of the last: a title card, a fade, a slide in from the side, a cut onto something new
  and still.
- The same seam on two scene changes running.
- A screenshot of a page as an answer; grey or coloured cards on the white ground (cards are white).
- Text under 34 px; the brand's colour on body text.
- Hype copy, exclamation marks, emoji.

## From the chat

Change only what's asked. "Faster" is about two thirds of the timings. Preview once; don't export unless asked.
