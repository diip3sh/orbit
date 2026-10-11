# The brand's taste and graphic transitions

> Launch films looked like the films Reco learned from, and changed scenes in two or three ways. Now a film takes its
> design from the product's website (its own fonts, colours, gradients and corners, scraped by `inspect_page` and set in
> the document), the director picks a motion personality from the brand and the transitions that personality speaks in,
> and the engine has thirteen graphic transitions any look may use, drawn in the brand's colours.

## Why

On 2026-10-11 the user saw the LemonLime film (made with a prompt that named ElevenLabs) and found it the same mistake
again: "we cannot copy exactly the product videos". They want the reference films (ElevenLabs', our Cal.com and Spotify
films) as inspiration for transitions and animation only, "very dynamic things … different shades and maybe different
gradients with different transitions", transitions "more lively" ("currently there are only one, two transitions … you
just flip the page or zoom out, zoom in"), generalised towards After Effects product videos, and the design to change
with each product, "taking in their taste … from their website. You can scrape it".

## Graphic transitions

`MotionSeam.graphic`: drawn over the whole frame in `style.seamColors` (the accent, then the gradient's other end, or the
accent 0.25 lighter or darker in OKLCH for a one-colour brand), in any look. `Transition.variant` is the scene's index, so
two of a kind go different ways (bars rightwards, up, leftwards, down; a flip or cube one way then the other; a liquid
from each corner in turn). Each eases itself, mostly on in-out quart (cubic-bezier(0.76, 0, 0.24, 1)), its parts one after
another.

| Seam | What | Length | Drawn by |
|---|---|---|---|
| `iris` | A disc of the accent opens out of the last click (else the middle) over 0.85 of the seam, the next scene's disc 0.15 behind; the scene before pushed 8 % in, the next back from 1.15× | 0.7 s | `irisSeam` |
| `bars` | Two bars (accent, second colour) then the next scene, 0.13 of the seam apart, edges leaning 0.18 of the span; the next slides the last quarter span behind its bar | 0.7 s | `barsSeam` |
| `slats` | Seven strips from alternate sides, the middle first (the outermost 0.35 later); what's under darkens 0.4 | 0.6 s | `slatsSeam` |
| `tiles` | 120 px tiles (1080p) open from dots of the accent into squares of the next scene in a wave over 0.55 of the seam | 0.8 s | `tilesSeam` |
| `split` | The frame parts down (or across) its middle with 6 px accent edges, the next up from 0.9× and half dark (0.15 on a light ground: half dark, white went a dirty grey) | 0.6 s | `TransitionRenderer+Space` |
| `spin` | 50° away cubic-in and 1.3× then in from the other side cubic-out, blurred along the turn a 0.04 s shutter sees (32 taps) | 0.45 s | `spinSeam` |
| `glitch` | Bands torn sideways up to 8 % of the width, channels 12 px apart (1080p), blocks of the next and a few of the accent, a new tear 24 times a second | 0.4 s | `glitchSeam` |
| `pixelate` | Blocks up to 9 % of the height, stepping 15 times a second, the next from half way | 0.5 s | `pixelSeam` |
| `liquid` | Three wobbling blobs (accent, second, the next scene), 0.12 of the seam apart, from the click or a corner | 0.9 s | `liquidSeam` |
| `flip` | The frame turns over as a card about its upright, 0.82× half way, seen from 2.2 frame heights, shaded edge on, over the second colour | 0.75 s | `CIPerspectiveTransform` |
| `cube` | The frame turns away on a cube, the next on the next face, 0.82× half way, shaded, over the second colour | 0.75 s | `CIPerspectiveTransform` |
| `flash` | The accent up by a quarter of the seam, held to 0.35, gone by the end; the cut under it at 0.3, the next settling from 1.06× | 0.35 s | Core Image |
| `stretch` | Stretched along one axis to 4× cubic-in and blurred 60 px, the next snapping back out-expo | 0.45 s | Core Image, `CIMotionBlur` |

- The kernels are `TransitionKernels.metal.txt`, compiled each alone as the fields are.
- Motion blur: the masks and moving frames add their fastest edge's travel to the shutter (`graphicTravel`, up to 4 times
  the even speed on their curves). Seams that cut inside themselves (pixels, a glitch, dots, a spin, a stretch, a flash)
  are drawn at the frame's own time: averaged across a shutter, the stretch's cut drew both scenes grey.
- A sound each, from the story seams' voices (`SoundCueList+Graphic`): a swish and a landing a bar, a riser and a glass for
  an iris or liquid, a whoosh at a spin, split or stretch's cut, bits for pixels and a glitch, a thump and glass on a flash.
  Editorial scores carry them too.
- Look-dev: `~/Movies/Reco/quality/transitions/Reel.motion`, every graphic seam between brand-coloured scenes, exported
  at 1080p60.

- Seam colours stand out from the grounds they join: the brand's two are kept while they're at least 0.15 apart (OKLab)
  from both scenes' grounds (a filled rectangle covering the canvas, else a plain field's background), else the farthest
  of them, the text's colour and the background (`StyleTokens.seamColors(between:background:)`). In the look-dev reel a
  liquid in the accent over a scene on the accent didn't show.

## Breathing in every film

Spec 0018 breathed editorial scenes. Every film's scenes without a camera or a shot of their own now breathe, all but the
last: the first LemonLime film from the app with this spec's director (`LemonLime 2`) was frozen in 24.6 % of its frames
before its end card, its longest freeze 1.23 s; its agent gave its scenes no camera.

## The brand's taste

`inspect_page`'s `brand` also reads:

- `fonts`: the heading's and the body's font files, from the `@font-face` rules of the page's stylesheets (fetched again
  when another origin's, as Google Fonts' are), the Latin file (by `unicode-range`) of the closest weight, never italic,
  WOFF2 first; next/font's mangled families (`__Inter_d65c78`) named as people name them.
- `heading`: weight, tracking (ems), capitals, size as a share of the viewport's width.
- `palette` (painted colours on the first three screens, most area first), `gradients` (their stops, largest first),
  `radius` (the call to action's, and the one most panels share).

A document's `fonts` (`[{family, url}]`) are fetched into `assets/fonts/<hash>.<ext>` by `FontCapture` (before a plan is
captured, and after each `edit_motion`) and read by `BrandFonts` (Core Text reads WOFF2, WOFF, TrueType and OpenType
alike). `style.font` sets every text without a font of its own, but code (`MotionDocument.brandSet`, used by the expansion,
the layout and the lint); a text's `font` names its own. The face closest to the weight is taken, a variable face set on
its `wght` axis. A file that fails is logged, and its text set in the system face.

## The director

`reco-director` no longer maps a brand to a reference film's look:

- **A design system from the site:** the brand's fonts in `style.fonts` and `style.font`, its colour roles (ground,
  surfaces, accent kept for what matters, its own gradient), corners from `radius`, and a ground by the brand (`plain` on
  its own colours always fits; the shader grounds where the brand suits them).
- **A motion personality** (precise, calm, playful, bold, editorial) from three motion words, each with its moves, its
  graphic seams (two to four at the film's turns, never two running) and the bridges it favours.
- **The variation** picks the story shape, the ground and the signature seam, so two runs for one product differ in all
  three.
- At least four kinds of scene change a film. The technique skills' transition and look sections defer to it.

The research behind the transitions and the personalities (After Effects launch-film devices, published motion systems:
Material, Carbon, Atlassian, GitLab, GitHub; what reads smooth or cheap) is summarised in the director's tables.

## Open

- An iris in the brand's corner shape (a square-cornered brand's iris is a rounded square).
- Seam colours chosen against the scenes they join: an accent bar over a scene on the accent is lost.
- The brand's heading tracking and capitals are for the agent to carry; the engine's tracking is still −1.2 %.
