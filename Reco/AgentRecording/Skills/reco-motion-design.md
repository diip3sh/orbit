---
name: reco-motion-design
description: Reco's motion-design film, after LordyVisuals' Spotify Jam concept. The product's UI is rebuilt as shapes, type and lifted parts that morph from one state to the next. One object is carried through (list → pill → flood → chips → caret → type → check). Letters spring in, a pointer clicks, the frame floods and bursts, everything on a beat. Use it when the user asks for motion design, a UI animation or a concept film, or names movements such as morphs, pops, a flood, a burst, kinetic type or a scrolling list. Use it for a consumer or mobile product whose story is one flow through its UI, and for a longer film (45 s or more), where it combines with reco-launch-film. Its reference files are read one at a time, when a step says so.
---

# A motion-design film, Reco's way

## The bar

The reference is LordyVisuals' Spotify Jam concept: 19 s, black, one brand green, white type. Spotify's Queue
builds row by row and scrolls fast with motion blur. A green dot under it grows into a pill: "This is
different", then "Start a Jam" springing in a letter at a time. A pointer clicks it and the pill floods the
frame green, rings opening in it. It shrinks back into a pill of listeners that splits into Invite and Leave.
Invite collapses to a dot, then a caret, and "Black & Tan" is typed big behind a green caret. The song lands in
the queue as a "+" turns into a green check in a burst of particles. The list scrolls to the logo.

What makes it good, and what yours must have:

- **One object, not shots.** There is one hard cut in 19 s; every other change is a morph of the thing on screen.
- **Never still, never waiting.** At 125 BPM a beat is 0.48 s, and something changes on every one. The next move
  starts before the last has settled: the pill grows while the list is still leaving, the words come in while the
  pill is still rising, the hand arrives while the letters spring. Nothing holds still for more than a beat and a
  half; the lint says so.
- **Out of each other.** New things come out of what is there: Invite and Leave slide out of the pill they split
  from, the dot flies to where the caret will be, the check shrinks into the row it was added to. A pop in place
  is for the first thing in a scene.
- **The camera carries the change.** It pans in on what is clicked and back out to show where it landed; the
  reference cuts once, and only where one shape continues.
- **Micro-interactions.** Hover (a pill lifts and grows 20 %), press, a pointer that comes up from below and turns
  to a hand, an outline that moves between buttons.
- **Overshoot.** Letters spring up past their line at 1.35× and settle, pops pass their size, a glyph spins in.
- **Restraint.** A black ground with the brand's light toned down, the brand colour, white type, the UI's own art.

`reference/film.md` has the film beat by beat with every timing measured. Read it before your first storyboard.

## Which skill

| The film | Skill |
|---|---|
| The product's real UI at work, close: typing, results, a tour (Raycast's look) | reco-launch-film |
| A flow through the UI as motion design: states that morph, clicks, floods, bursts | this one |
| 45 s or more, or the user asks for both kinds | Both: read `reference/longer.md` |

## Method

1. **Research.**
   - Use inspect_page on the product and its app pages. Its `selectors` argument returns boxes; the product's
     web app often renders signed-out.
   - Find one flow a person does, 4–6 states long. For Spotify: queue → Start a Jam → listeners join → pick a
     song → it's added.
   - Find the parts to lift: list rows, cover art, avatars, the logo. For the n-th of many alike, select it with
     `div:nth-of-type(n) > <the row's selector>`.
2. **Storyboard** the beats. For each, say which object carries over from the beat before: the pill that
   was the dot, the dot that becomes the caret. Put every change on the 0.48 s grid, and start each move a
   little before the one before ends.
3. **Assets.**
   - Lift what is real (rows, art, logo) as `bare` stills with the viewport the page was designed for, often a
     phone's `[390, 844]`.
   - Build the controls (pills, chips, buttons, icons) as `shape` and `text` layers in the brand's colour.
   - Write all assets in one edit_motion call, then call capture_ui. It gives each asset's size.
4. **Write the scenes.**
   - Layers with moves, positions in canvas pixels. Name what happens; never write keyframes.
   - Copy the components from `reference/recipes.md`: read it now. It has the queue, the pill button, the flood,
     the split pills, kinetic type with a click, the add-to-check burst, and the scales that read on 1920×1080.
   - Every field and default of the moves is in `reference/moves.md`. Read it when a recipe isn't enough.
5. **Check.** Call preview_motion and look at every frame:
   - Does each state come out of the last?
   - Does anything just appear or vanish, or wait for something else to finish?
   - Is the type at least 32 px and the pill at least 500 px wide?
   - Does the pointer land on what it clicks?

   Fix everything in one edit_motion call. Stop after three previews.
6. **Export** with export_recording: format h264, resolution 2160.

`reference/example.md` is a whole document of this kind. Read it if you're unsure how the parts fit.

## The look

- canvas:
  - `{"size": [1920, 1080], "frameRate": 30, "background": "#000000", "pacing": "beats"}`.
  - For a brand with a hue: field `ember` at `fieldStrength` 0.45, light in two corners and the middle dark.
  - Without a hue: `satin`.
- style:
  - `text` is `#ffffff`;
  - `accent` is the brand's colour (kinetic carets, bursts and rings take it);
  - `face` is sans.
- Pills and buttons are the accent with a glow: `shadow {opacity 0.8, radius 40, offset 0, color: the accent}`.
- Type is the system's sans, white on black and black on the accent; bold for anything typed big.

## Never

- A title card, a headline alone between beats, a fade between scenes, a card sliding in from the side.
- A layer that appears or disappears without a move: everything pops, morphs, rises, floods or exits.
- A cut where a camera move or a morph could carry the change: a cut only where the same shape continues.
- A scene where nothing changes for longer than a beat and a half.
- A second accent colour, a gradient on a control, an emoji.
- The pointer on a layer it doesn't press: a click is the moment something changes.
- Hype copy, exclamation marks, questions to the viewer.

## Sound

Give the document `"sound": {"style": "house"}`: a 125 BPM four-on-the-floor score like the reference's, fitted to your
cuts. Put your cuts on its 0.48 s beat. Effects come from the film's own timing:

- a blip on each pop, a key on each press and click, a riser and hit on a flood, glass on a burst;
- keys under kinetic type, a whoosh on a fast scroll.

Write nothing else about sound unless the user asks.

## From the chat

Change only what's asked; "faster" is about two thirds the timings, "bigger" scales sizes and positions about the
middle. Preview once; don't export unless asked.
