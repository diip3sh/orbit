# Films are actions: the picture keeps changing

> Spec 0020's films were static: UI on tilted cards, its parts rising in, then sitting there while the camera pushed or arced
> slowly. The films the user liked change their picture all the time, because every scene does something. The director now
> has the agent write the film as actions first, frames UI facing the viewer, and `preview_motion` names every stretch in
> which the picture stands still.

## Why

On 2026-10-11 the user saw Cardboard 5 (spec 0020) and found it "very basic and very bad": most shots static, one or two
animations, "tilted slides, switching from one to two, nothing", the same transitions again and again. The one moment they
liked was a line appearing large over the wall of the product's videos. They pointed back at the films they liked: Cal.com's
story film (`~/Desktop/Cal.com - story film.mp4`, Calcom 3), the Spotify Jam film and ElevenLabs' launch, all made before the
director (spec 0018), and asked for a different process.

## What separates them

Pixel change can't tell them apart: every frame of Cardboard 5 changes somewhere (parts rising, the camera creeping). Nor can
the lint's idle stretches: Cardboard 5's staggered entrances kept its scenes "busy", while Calcom 3 had more idle stretches.
What differs is whether the **picture** changes. Read at 32 × 18, half a second apart, with a mean luma change under 2 of
255 counting as still:

| Film | Picture still | Longest still | Liked |
|---|---|---|---|
| Cal.com story film | 11 % | 2.0 s (the logo) | yes |
| Spotify Jam 2 | 19 % | 0.7 s | yes |
| Orca ADE v6 | 21 % | 2.1 s | |
| Cal.com flow film | 22 % | 0.9 s | |
| ElevenLabs' film | 35 % | 7.2 s | yes (type-led holds) |
| Cardboard 5 | 40 % | 1.8 s | no |
| Cardboard 3 | 61 % | 2.7 s | no |
| Cardboard 2 | 64 % | 3.6 s | no |

Cal.com's scenes are each an action: a hand clicks a pill and its menu opens, a request is typed huge, the send washes the
box, tiles pop and flip to done, a stack scatters, a slot is circled, Confirm morphs into Booked. Cardboard 5's scenes were
displays: 11–21 `rise` entrances a scene, then nothing, at an angle in 8 of 12 scenes.

## The check

`DesignCheck.stillPictures(levels:scenes:)` (`DesignCheck+Change.swift`), in `preview_motion`'s findings. The plan's frames
are read 10 times a second through the same composition as an export (`ContactSheet.levels(of:)`, 3 × 3 averaged to
32 × 18):

- a film whose picture is still more than 25 % of the time is named, with what does and doesn't read as motion;
- each scene whose picture stands still for over 1 s, the end card aside, is named with where.

Through the engine at the preview's 270 px, Calcom 3 has no finding, Cardboard 5 is 35 % with five scenes named, Cardboard 2
53 % with five. It adds about 5 s to a preview (M5, Debug, a 30 s film).

`flatFilm` (spec 0020) is gone: it asked for the product at an angle, which the user found looks bad.

## The director

`reco-director` sections 7–10 are rewritten:

- **The film is actions** (7): written first as one line per action with its time, something every 0.5–1 s that changes the
  picture; a scene is one action, not a display (parts arriving is its entrance); six or more different actions, never the
  same twice running; the camera serves the action. A table maps actions to moves and the skills with their recipes.
- **Transitions with a reason** (8): what happens decides the seam (`expand` or `dive` from a click, `stack` for a view over
  the last, `flow` for a thing carried on, `whip`, `grow` or `flood`, the look's seam at the three turns, `ring` into the logo,
  `cut` only onto motion); four or more kinds, never one twice running, at most two cuts running.
- **The frame** (9): UI rebuilt and facing the viewer, a control in macro with the hand, an answer whole at 60–80 % of the
  width with type at least 34 px; `angle` never for UI.
- **Grounds** (3): Reco's shader looks first for a dark brand (the dither and light looks Cal.com's and Orca's films were
  praised for); `pool` for a quiet one.
- **Check** (10): `reco-story-film` is always loaded; the film is done when no "the picture stands still" finding is left.

The camera angle, `arc`, `swing`, `flow` and `pool` stay in the grammar.

## Open

- The thresholds come from eight films. ElevenLabs' type-led film would fail the film-wide 25 %: its holds are on words lit
  one at a time, which the 32 × 18 read misses.
