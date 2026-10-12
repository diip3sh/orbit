# Transitions that read

> Cardboard 6 (spec 0021) was the first film the user found good; its transitions were the next thing to raise. Seen frame by
> frame, its expand and stack read as dim fades, and its plain cuts landed on empty frames. Expand is now a container
> transform, a stack's sheet is lit and pushes the scene before up, seams are sized by the frame, and the lint and the
> director keep a carried scene whole.

## What was wrong

On 2026-10-12 the user said Cardboard 6 "was good but we can make more improve on transition high quality transitions". Its 12
seams, frame by frame at 15 fps:

| Seam | Read |
|---|---|
| whip, dive, ring, the timeline's flow | good: the eye follows one thing across |
| expand (send → "Working…") | a dark rectangle growing on a dark ground: a dim fade |
| stack (×2) | a dark sheet sliding up empty: the clips popped in under it and after it |
| five cuts | three onto an empty ground: a caret alone, one small line |

Two causes were the engine's:

- **Dark into dark.** Expand grew the next scene in a rectangle that is the same dark as what it covers, and its content came
  in after it, so nothing showed the shape growing.
- **Seams sized by an oversized frame.** The scene before's image was larger than the frame when its layers lay past it, and
  stack and expand took their size from it: the next scene was drawn smaller than its rectangle (two thirds of it in the
  send → "Working…" expand). `transitioned` now cuts both frames to the frame first.

## Expand: a container transform

The clicked control grows with the rectangle (up to 2.5 times; further, its pixels blur), clipped to its own shape and gone by
0.35 of the way. The rectangle is filled with the control's own colour (its middle, 15 % inset, clear of a round button's corners),
turning to the next scene's from 0.1 to 0.55, and the next scene comes up in it from 0.25 to 0.7. A control (shorter than an
eighth of the frame) starts as a pill or circle, a card with a card's corners. A 1.5 px light edge (1080p, 0.3) shows the
rectangle against a dark ground until 0.6 of the way.

## Stack: a lit sheet

The sheet's edge has the same light, fading as it covers the frame, and the scene behind is pushed up a twentieth of the frame
as it sinks back.

## A carried scene is whole

A stack, an expand and a dive carry the next scene in whole. When half or more of its parts aren't there by the seam's middle
(they or a group they're in still coming in), the lint names them (`carried`). Actions, typing, a scatter, shimmers and
shown/hidden swaps don't count, so Vantae's photo popping into its box under an expand passes. On Cardboard 6 it names the
expand's checklist rows and the stack's clips, not the scatter into the video wall.

## The director

Section 8 adds: never cut onto an empty ground; cut into a frame full from its first frame, or match the cut (the same place,
size or colour). A stack, expand or dive carries its scene whole and acts after it.

## Checked

`~/Movies/Reco/quality/transitions/Cardboard 6 carried.motion` is Cardboard 6 with the two carried scenes there from the cut
(the checklist's cascade and the clips' pops removed), exported at 4K60 (`… carried-edited.mp4`, 139 s, M5, Debug). The expand
reads as the send button growing into a card showing the checklist, the stack as a sheet carrying the clip grid.

## Open

- A cut's quality is only a rule for the agent; nothing measures an empty frame after a cut yet.
- The user hasn't seen these seams yet.
