# The After Effects bar: depth, light and transitions made by the content

> Films took their brand's taste (spec 0019) but still looked generated next to a studio's launch film: a small flat card
> in a black void, grey bars for content, an effect laid over every cut. The camera now sees a scene at an angle and arcs
> round it with depth of field, a dark film is lit by a pool of light that falls on the UI too, a `flow` carries a layer
> from one scene into the next while the rest hands off in offsets, a `swing` turns one scene away and the next in, and the
> director holds films to the bar measured on Linear's, Raycast's, Nothing's and Copilot's films.

## Why

On 2026-10-11 the user saw the second Cardboard film (spec 0019) and found the animation, transitions and UI "very basic,
not at all After Effects level": different films for different sites, with their assets and design, was right, but the
transitions were basic and the UI shown was basic. They pointed at the ElevenLabs film's transitions, camera movement and
smooth animation, and our Cal.com film's.

## What the films that set the bar do

Measured on the reference films with frame differences and grabs (research note in the session's scratchpad; numbers
marked est. are estimates):

- **Cut and hold.** Linear cuts 8 times in 55 s, Raycast 15 in 38.5 s, Nothing 12 in 75 s, Copilot 31 in 102 s; 55–72 % of
  frames barely move; moves last 0.75 s (median). The change of scene happens inside the shot (a shape morphs, a match cut,
  a whip). None uses an iris, bars or a generic wipe.
- **Lopsided curves.** A move peaks a quarter of the way in (Nothing 0.26, Linear 0.25, Copilot 0.31), not half way as a
  symmetric easy ease does.
- **UI at 4–8× and cropped.** Raycast's typed text is 8 % of the frame's height, its rows 5 %, its panel cut by the right
  and bottom edges; Linear's plane runs off three edges.
- **Light and focus in the scene.** Linear's frame edges are 0 of 255, its middle 10–36: one pool of light on the UI. Its
  depth of field leaves a band 15–25 % of the frame sharp. Its plane lies back 35–50° and rolls 15–25°.
- **Shared elements and offsets.** Material's container transform: the content cross-fades early, the shape done by 75 %.
  Exits take half as long as entrances and overlap them.

## The camera at an angle

`camera.angle` `[x, y, z]` turns the scene about the point at z 0 the camera looks at, in degrees, as a layer's rotation is
(x leans the top away, y turns the right edge away, z rolls). The camera's rotation properties take keyframes and moves.

- `CameraProjection` turns points about the look point before projecting them. Layers are still ordered by their depth
  before the turn (`order(of:)`): ordered after it, the far side of a card lying back was farther than the card's middle,
  and the card was drawn over what's on it.
- A camera at an angle has depth of field unless keyed: aperture `MotionCamera.angledAperture` 3 (canvas pixels of blur per
  100 px of depth), sharp along a band through where it looks; at 30° the band is about 15 % of the frame.
- `arc` (camera move): the camera travels round where it looks, 2.5° a second (est.), direction left, right, up or down,
  linear, past the cut as a drift does.
- `swing` (seam): the scene turns 40° away over its last 0.3 s, in-cubic, 6 % nearer, and the next in from 40° the other
  way over 0.6 s, out-expo, from 6 % further; two in a film turn different ways. Camera tracks only, so motion blur
  samples it as the planes move; the whip finder counts the camera's turn as a pan, so it sounds as a whip.

## Flow: carried into the next scene

`flow` (seam, 0.8 s, `MotionPlan+Handoff`, `MotionFrameRenderer+Handoff`):

- The scene before's top-level layers leave one after another, the front first along the way (leftwards, then upwards by
  turns): each over 0.3 s from 0.12 s before the cut, 45 ms apart, a tenth of the width, blurring 8 px and fading,
  in-cubic. Leaving from the cut, the scene before stood whole under the next's first layers for a fifth of a second.
- The next scene's layers arrive from 0.12 of the width back over 0.65 s from 0.08 s, out-expo, sharpening from 10 px, faded
  in over 0.2 s unless their own entrance fades them. A layer covering the canvas is a ground: it fades in under them.
- A drawn layer whose id is in both scenes travels between its places over 0.7 s, in-out: a plain rectangle changes size,
  corners and colour on the way (`ShapeMorph.interpolated`), anything else turns into the next scene's in the middle of the
  travel. It is drawn on top, seen throughout though the groups it leaves and joins fade.
- One ground: the scene before's field, the next's coming up over it when it differs.
- Motion blur samples the leaving and carried layers' travel (`flowTravel`). It sounds as a flip does.

## The pool of light

`pool` (field, family plain): the canvas's background lit by one soft light in the brand's hue (0.14 lighter in OKLCH,
chroma up to 0.07), a Gaussian wider than tall, a new place each shot, drifting 3 % of the frame and following the camera as
far ground does. Over the frame, the UI too, it falls off to 0.45 of its light at the corners, round the pool: the light
lies on the product rather than behind it.

## Checks

`preview_motion` names two more things:

- `smallContent`: a scene whose shown layers, mid-way, span under half the frame's width and under 45 % of its height (the
  end card aside). Cardboard's second film showed a 600 px line, a 1190 px box and 640 px cards on a black 1920 × 1080 frame.
- `flatFilm`: four or more scenes, fewer than two with a camera at an angle, an arc, or a layer turned or set in depth.
  Removed by spec 0021: the user found the tilted UI it asked for looks bad.

## The director

`reco-director` holds films to the bar:

- **Grounds:** never a flat void; a dark brand's product scenes on `pool` first.
- **Transitions:** a personality's signature transitions are content-driven (`flow`, `swing`, `whip`, `dive`, `expand`,
  `melt`, `morph`/`flood`, `eat`, `grow`); three to five designed transitions at the turns, the rest cuts on motion. The
  graphic seams are at most one a film, only in a playful or bold one.
- **The frame and the motion:** the hero at 60–100 % of the width or cropped, UI text 32–56 px at 1080p; product scenes at an
  angle (x 15–35, y ±10–25) with an arc or a push and parts at different z; lit surfaces; real things in every slot (the
  site's images, names, numbers), never a grey bar for content; parts arriving 40–80 ms apart out of a blur, exits half as
  long and overlapping.

## Open

- Superseded in the director by spec 0021: Cardboard 5, made to this bar, was static (tilted UI that sat still while the
  camera pushed); films are now written as actions, UI facing the viewer.

- Easing: the grammar's `move` peaks at 43 % (measured on 17 moves of the films then); the research's measure peaks at
  25–31 %. Kept, since goldens and every film use it; new moves use expo-out and in-cubic.
- Motion blur is on every moving layer; the films keep text being read sharp.
- A carried layer leaving a group that slides away travels from where the slide has taken it.
