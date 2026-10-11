---
name: reco-director
description: Reco's film director, loaded first for every launch film. It turns the product's website and the user's few words into an original film - a brief, a design system taken from the brand (its fonts, colours, shapes and motion personality), a story shape, the transitions that personality speaks in - and says which of Reco's technique skills to read for the moves. Reco's other skills are techniques learned from other companies' films; this one makes sure every film is this product's own, different each run, and never a copy of them.
---

# Directing a launch film

Reco's technique skills each learned a way of moving from one film: `reco-launch-film` (Raycast: real UI in macro on
glass), `reco-motion-design` (a concept film: one object morphing), `reco-story-film` (Lovable: a person's request told
through the product), `reco-flow-film` (Vantae, IrukaDark: a light film flowing scene out of scene) and
`reco-editorial-film` (ElevenLabs: type and print, pictures, a film score). They are **techniques**: how things move, how a
document is written. **Never their story, scene order, words, colours, grounds or type.** A film that looks like one of
those films has failed, however good its frames: it is someone else's film with a new logo. Unless the user names one of
those films or styles, none of them decides how this film looks: the product's website does.

You direct: decide everything below, then load the technique skills whose moves you need and write the film.

## 1. Research

Call inspect_page on the product's site and the two to four pages its navigation links to. Web search it, if you can:
why it is talked about now (a launch, a round, a demo), who uses it, what they say.

Find:

- its name, its mark (letters or a symbol) and its own line;
- what it does in one sentence, for whom, and its main input (a prompt, a search, an editor, a call, a canvas) with one
  real thing a user would put in it;
- what it gives back, and its proof (numbers it states, customers, speed);
- its **brand kit**, from inspect_page's `brand`: `fonts` (the heading's and body's font files), `heading` (weight,
  tracking, capitals, size), `palette` (painted colours, most area first), `gradients`, `radius` (button, card), `accent`,
  `background`, `logo`; and by eye from the pages: its imagery (photos, illustrations, 3D, UI, none), its density, its motif
  (a grid, a waveform, code, a map, a chart, paper, a terminal).

## 2. The brief

Settle these before you choose anything. The user's words decide where they say something.

- **The idea:** one sentence the film says, in plain words ("Every call writes its own follow-up").
- **The tension:** what is hard without it, as a user would say it ("I spend Fridays on follow-ups").
- **The hero moment:** the one thing on screen that shows it working: a request turning into a result, a mess turning
  into order, a number moving.
- **The personality:** three motion words from the brand's voice ("precise, quiet, fast"; "loud, warm, playful"), and the
  one of the five below they come nearest.
- **The length:** 20–35 s unless asked. A film on X plays muted from its first frame: something must move at once and the
  first words must read by 2 s.

## 3. The design system: the website's, carried into motion

Every film is drawn in the product's own taste. Set it once with set_style and set_canvas, before any scene:

- **Type.** `style.fonts` from `brand.fonts` (each `{family, url}`) and `style.font` the heading's family: every line is
  set in the brand's own face. Weight as its heading (≥ 600 semibold or bold); a heading set in capitals or tight
  (`tracking` below −0.01) is set the same way in the film. Code stays `face: mono`. Without fonts, `face` by `brand.face`.
- **Colour roles.** The ground: the site's background (`brand.background`) or its darkest or lightest palette colour. The
  surfaces: the palette's next colours (cards, panels, pills). The accent (`style.accent`): the call to action's colour,
  kept for what matters (the input's send, the result, the transitions). `style.gradient`: the site's own gradient stops
  if it paints one. Nothing else: never a colour the site doesn't use.
- **Shape.** Corners from `radius`: cards at `radius.card`, pills and buttons at `radius.button` (999 is a pill), scaled
  from CSS pixels to the canvas (about 1.5× at 1080p). A square-cornered brand gets square cards; a round one, round.
- **Ground.** What the scenes stand on, by the brand, then by `Variation` among those that fit:

| The brand | Grounds that fit |
|---|---|
| Light site, one clear colour | `plain` on its background; `haze` with its gradient |
| Light site, warm, typographic, print-like | `plain`; `paper` |
| Dark site, a gradient of hues | `aurora`; `plain` |
| Dark site, one clear hue | `ember`, `sunlit`, `bloom`, `orb`, `ripple` (toned to 0.45 under type); `plain` |
| Technical (APIs, data, infra, developer tools) or black and white | `warp`, `tide`, `swirl`, `matrix`; `plain` |
| Dark and quiet, its colour all in its UI | `satin`; `plain` |

  `plain` with the brand's own colours, cards and type is always right. A film keeps one ground family; scenes may change
  the colour of a plain ground (a statement on the accent, the hero on black) with a graphic seam or a grow.

## 4. The motion personality: its curves and its transitions

| Personality | Moves | Its graphic seams (2–4 in a film, at its turns) | Bridges it favours |
|---|---|---|---|
| **Precise** (developer tools, infra, data) | quick, no overshoot; `type`, `blurWipe`, `lineMask`, `cascade` | `slats`, `tiles`, `split`, `pixelate`, a `glitch` once | `cutOnMotion`, `whip`, `expand`, `dither` |
| **Calm, premium** (design, finance, AI assistants) | slow settles, never a bounce; `brighten`, `wordByWord`, `fly` | `iris` (out of the UI), `wipe`, `split` | `expand`, `dive`, `stack`, `melt`, `grow`, match |
| **Playful** (consumer, creative, social) | overshoot ~10 %; `letters`, `pop`, `morph`, `burst`, `ripple` | `liquid`, `bars`, `tiles`, `flip`, `iris` | `morph`, `flood`, `pop`, `scatter` |
| **Bold, loud** (launches, growth, sales, sport) | expo in to the cut, expo out after; `kinetic`, short holds | `stretch`, `spin`, `flash`, `bars`, `cube` | `whip`, `zoomThrough`, `cutOnMotion` |
| **Editorial, exact** (writing, research, voice) | stepped and still; `brighten`, `sweep`, `blink`, `eat` | `slats`, `split`, `wipe` | `eat`, `grow`, cut on motion |

Graphic seams are drawn in `style.accent` and a second brand colour over the whole frame, in any look; two of a kind in a
film go different ways. Each is a hit: at the film's two to four turns (the problem to the product, the input to the
result, the result to the name), never on every cut, never two running.

## 5. The story shape: choose one

Each shape is a few beats; how many scenes each beat takes is yours. Write every line yourself from the research: short,
plain, the product's own words where it has them. Never hype, exclamation marks or emoji.

1. **The ask.** A real request typed into the product → it takes it (what it does, as labels or steps) → the result,
   whole → one detail of it close → the idea in words → the name.
2. **Before and after.** The tension, quick and cluttered in grey (small hard cuts, things piling up) → everything stops
   on one line → the name opens → the same job done in one move → the result → the name with its line.
3. **Claim and proof.** Three short claims, each lit or typed big and answered at once by one product moment (the input,
   the result, the proof) → the name.
4. **One object.** A single shape travels the whole film and every scene is it changed: the input becomes a card, the card
   a list, the list a chart, the chart the mark.
5. **Zoom in.** The product's whole world as a field of its things (a mosaic of its outputs, a map of its parts) → closer
   to one → closer to one detail of it, filling the frame → out to the name.
6. **The conversation.** One person's lines typed big, the product answering each as things, the last answer the finish
   they wanted → the name.

## 6. Variation: a different film every run

The prompt gives a `Variation` number (1–6). Use it three times, each among the options that fit the brand and the brief,
counting through them in the order listed (variation 3 of two options is the first):

- the **story shape** (section 5);
- the **ground** (section 3's row for the brand);
- the **signature seam**: the graphic seam of the personality's list (section 4) the film uses at its biggest turn.

Two runs for one product must differ in all three.

## 7. Moves: borrow from any skill

Every move works over every ground. Read only the recipe you use.

| For | Moves | Recipes in |
|---|---|---|
| The name opening | `unfold` (mark into name and line), `letters`, `fly` | editorial, motion design, flow |
| A line arriving | `brighten`, `sweep`, `letters`, `kinetic`, `voice`, `wordByWord`, `type`, `blurWipe`, `lineMask` | editorial, motion design, story |
| Texture round what's read | `blink` labels, mono lines typed, `marks` | editorial |
| The product's input | a macro on its control, typing, a hand's `click` and `press`, `select` | story, flow, launch |
| Answers arriving | `pop`, `cascade`, `scatter`, `reply`, `shimmer`, `wash`, `fly` | story, motion design, flow |
| One thing becoming another | `morph`, `grow`, `flood`, `dots`, `orbit` | motion design, editorial |
| Things leaving | `eat`, `morph` to a line at an edge, `hide`, `exit` | editorial, motion design |

## 8. Transitions: every scene comes out of the last

Plan each scene's handoff before you write it: what of this scene the next begins with.

| Device | How |
|---|---|
| Grow into the next | a card or tile `grow`s or `flood`s to fill the frame; its colour is the next scene's ground |
| Collapse into the next | a line is `eat`en into a block, a card `morph`s to a dot or a bar, and the next scene starts from that shape in the same place |
| Match | the same thing in the same place across a cut, changed: the input now full, the card now a chart, the word now the logo |
| Into what was clicked | `expand`, `dive` or `iris` on the next scene, the click its last move |
| Over it | `stack`: the answer comes up over the request |
| A graphic seam | section 4's, at the film's turns |
| A look's seam | `glow`, `dither`, `melt`, `wipe`, `whip`, `ring` into the end, in their grounds |
| Cut on motion | a cut whose next scene moves on its first frame: typing, a pop, a statement there dim |

- At least half the scene changes are a device other than a plain cut; at least four different devices in a film; never
  the same one twice running; never a cut onto something still.
- Inside a scene a change of state is a move (a pill `morph`s, a button `flood`s), never a cut.

## 9. Motion

Measured on ElevenLabs' film against a rebuild that copied its moves but felt stiff: the rebuild was frozen in 26 % of its
frames and cut from still frames six times in ten; the film is frozen in 6 % and never cuts from a still frame.

- **Never still.** Something visible changes every 0.4–1.5 s, and a held shot creeps (2–5 % over a hold). Give each scene
  a camera move (`push`, `pullBack`, `drift`); Reco breathes editorial scenes for you.
- **Cut into motion.** After a cut the move is at its fastest and decays: half done in 0.12–0.23 s, nine tenths by 0.4–0.5 s.
- **Cut out of motion.** The last move runs into the cut, accelerating: an `eat`, a shrink, a slide, a seam. Carry the
  direction: what leaves rightwards arrives from the left.
- **Short changes.** Pops 0.22–0.27 s, a card growing to the frame 0.4 s, slides 0.65 s, a ground changing colour 0.1–0.2 s.
  No cross-dissolves, nothing over 1 s.
- **Arrive large, settle.** Things come in slightly large (1.1–1.2×) and settle over 0.5–1.3 s; overshoot only in a playful
  film.
- Scenes are 1.2–3 s; the opening's first motion is on frame one.

## 10. Write, check, export

1. Load the technique skills for your moves and read their recipes. set_style (with fonts) and set_canvas first, then the
   whole film in one edit_motion call.
2. preview_motion, and check every frame:
   - Does the first frame move, and do the first words read by 2 s?
   - Is every line in the brand's own face, its colours and its corners? Would someone who knows the product's site
     recognise it with the logo covered?
   - Can you name each scene's handoff? Are there at least four kinds, the graphic seams only at turns?
   - Would someone who knows the reference films recognise one of them scene for scene, or by its ground? Then change it.
   Fix everything in one edit_motion call. Stop after three previews.
3. Export with export_recording: format hevc, resolution 2160, at 60 fps.
