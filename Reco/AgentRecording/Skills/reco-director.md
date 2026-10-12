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
- **Ground.** What the scenes stand on, by the brand, then by `Variation` among those that fit. Never a flat void: a dark
  frame is lit (Reco's shader looks, or a pool of light), a light one has soft colour moving through it.

| The brand | Grounds that fit |
|---|---|
| Dark site, any hue | `swirl`, `warp` or `tide` (dither in its hue, 0.45 under type); `satin`; `aurora` if it paints a gradient |
| Dark site, one clear hue, bold | `ember`, `sunlit`, `bloom`, `orb`, `ripple` (toned to 0.45 under type); a dither |
| Technical (APIs, data, infra, developer tools) or black and white | `warp`, `tide`, `swirl`, `matrix`; `satin` |
| Dark and quiet, its colour all in its UI | `satin`; `pool` (one soft light in its hue) |
| Light site, one clear colour | `haze` with its gradient; `plain` on its background with lit, shadowed cards |
| Light site, warm, typographic, print-like | `paper`; `plain` |

  A film keeps one ground family (`pool` and `plain` are one). Scenes may change the colour of a plain ground (a statement
  on the accent, the hero on black) with a grow or a flood.

## 4. The motion personality: its curves and its transitions

| Personality | Moves | Its signature transitions (at the film's turns) | Between them |
|---|---|---|---|
| **Precise** (developer tools, infra, data) | quick, no overshoot; `type`, `blurWipe`, `lineMask`, `cascade` | the look's seam, `flow`, `whip`, `expand` | `stack`, cuts onto motion |
| **Calm, premium** (design, finance, AI assistants) | slow settles, never a bounce; `brighten`, `wordByWord`, `fly` | the look's seam, `flow`, `dive`, `expand` | `stack`, cuts onto motion |
| **Playful** (consumer, creative, social) | overshoot ~10 %; `letters`, `pop`, `morph`, `burst`, `ripple` | the look's seam, `flood` into the next, `expand`, `flow` | `stack`, cuts onto a pop |
| **Bold, loud** (launches, growth, sales, sport) | expo in to the cut, expo out after; `kinetic`, short holds | the look's seam, `whip`, `zoomThrough`, `flood` | hard cuts onto motion, on the beat |
| **Editorial, exact** (writing, research, voice) | stepped and still; `brighten`, `sweep`, `blink`, `eat` | `eat`, `grow`, `wipe`, `flow` | hard cuts |

The look's seam is its ground's own: `dither` over a dither, `glow` over light, `melt` over haze, `wipe` on paper, `ring`
into the logo. The graphic seams (`iris`, `bars`, `slats`, `tiles`, `split`, `spin`, `glitch`, `pixelate`, `liquid`, `flip`,
`cube`, `flash`, `stretch`) are a slideshow's transitions: at most one in a film, only in a playful or bold one, only where
the story turns hardest.

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
- the **signature transition**: the one of the personality's list (section 4) the film uses at its biggest turn.

Two runs for one product must differ in all three.

## 7. The film is actions

The films users loved (Cal.com's story film, the Spotify Jam film, ElevenLabs' launch) change their picture all the time:
a hand clicks a pill and its menu opens, a request is typed huge, a button washes with light, tiles pop and flip to done,
a stack of cards scatters, a slot is circled, a pill morphs to "Booked". Their picture stands still in 11–22 % of the
film. Films that showed UI on cards that sat there while their rows rose in, the camera pushing or arcing slowly, stood
still in 40–64 % and read as static slides, however good each frame was.

So write the film as actions before you write any scene: one line each, a verb on a thing, with its time.

```
0.0  the prompt box arrives; the hand comes up to "Auto"
0.6  click: the menu opens, the highlight follows the hand to "Documentary"
1.4  cut: "Make a one-minute documentary on American makers" typed huge
3.0  send: the box washes with light, the thread rises over it
3.6  "Working…" shimmers; steps tick to done one by one
```

- **Something happens at least every 0.5–1 s**, and it changes the picture: a click that opens or changes something,
  typing, a state changing (a pill morphing, a status swapping, a check), things arriving as a group (a pop from the
  middle out, a cascade, a scatter), a thing growing to fill the frame, the camera whipping or diving to the next thing.
- **A scene is one action, not a display.** Parts arriving is an entrance, not the action: after its parts arrive, the
  scene does its action (the click, the typing, the swap). A scene with nothing to do is cut, or shortened to a beat.
- **Six or more different actions in a film**, never the same one twice running. A film of cards rising in is one action.
- **The camera serves the action**: a push into what's about to be clicked, a whip to the next control, a dive through
  the click. A slow push, drift or arc behind still UI is not motion.

| The action | Moves | Recipes in |
|---|---|---|
| A control used, close | a macro on it, the hand's `click` and `press`, its menu opening (`pop`, `show`), `select` | story, flow, launch |
| The ask | the person's words typed big (`voice`), typed into the box (`type`), the send `wash`ing it | story |
| The product working | `shimmer` ("Working…"), steps or rows ticking to done (`show`/`hide` swaps, `spin`, `check` glyphs), a `cascade` | story, motion design |
| The answer arriving | a bento `pop`ping from the middle out, a stack `scatter`ing into a collage, a `reply` word by word, `fly` | story, motion design, flow |
| A state changing | `morph` (a pill to its next size and colour), `flood`, `burst`, `ripple`, a counter rolling (`roll`) | motion design |
| One thing becoming the next scene | `grow` to fill the frame, `flood`, `eat` into a block, `flow` (the same id in both), `dive`, `expand` | editorial, motion design, this skill |
| Words | `brighten`, `letters`, `kinetic`, `sweep`, `wordByWord`, a line laid big over the product's pictures | editorial, motion design |
| The name | `unfold` (mark into name and line), `letters`, `fly`, `ring` into the logo | editorial, motion design, story |

## 8. Transitions: each one has a reason

Every change of scene comes out of an action, and you can name its reason:

| What happens | Seam on the next scene |
|---|---|
| The scene clicks something and the next is what it opens | `expand` (pressed in the scene's last 0.5 s) or `dive` through it |
| A new view comes over the last: the thread over the box, a detail over a list | `stack` |
| Something of this scene goes on into the next (a pill becomes a card, a word the logo, a thumbnail the full frame) | `flow`, the same layer id in both scenes |
| The camera goes to another part of the same thing | `whip` |
| A thing grows or floods to fill the frame and is the next ground | `grow` or `flood` in the scene, then a cut |
| The film's three turns: the opening, the first answer, the end words | the look's seam (`dither`, `glow`, `melt`, `wipe`) |
| The end words into the logo | `ring`, the logo on `halo` |
| The next scene moves on its first frame (typing, a pop at 0, a scatter) | `cut` |

- At least four kinds in a film; never the same seam on two scene changes running; never more than two cuts running.
- Never a cut onto or from something still, and never onto an empty ground: a caret alone or one small word reads as nothing
  happening. Cut into a frame that is full from its first frame (a big line, a grid, a card whole), or match the cut: the
  thing the last scene ended on is in the same place, the same size or the same colour as the first thing of the next.
- A `stack`, `expand` or `dive` carries the next scene in whole, as a sheet sliding up or a screen opening: what it shows is
  there from the cut (no `rise` or `cascade` under it), and acts after it (a check ticks, a count runs, a click). Parts rising
  in under it leave an empty sheet moving; the lint names them.
- Inside a scene a change of state is a move (a pill `morph`s, a button `flood`s), never a cut.

## 9. The frame

**Facing the viewer, big, whole.** The product's parts are rebuilt as shapes, type and its own images and shown facing the
camera, as Cal.com's film did. Never a whole window or a dense panel tilted on a card: it reads as a template and its text
can't be read.
- A control is shown in macro: its pill or button 3–4× its size, the hand as large as it, the frame cropping the rest.
- An answer is a thing rebuilt from the product (tiles, cards, a short list, a calendar's week, one result), whole in the
  frame, centred, 60–80 % of its width, its type at least 34 px.
- The person's words are typed at 90–140 px; a statement alone is set as the brand's heading at 110–160 px and something
  moves round it or under it (pictures of the product's output, a reply arriving).
- `angle` is for a picture or a mark at most, never for UI.

**Real things in every slot.** The site's images and thumbnails (`ui` layers from its image addresses), avatars, logos,
file names, numbers, dates. Never a grey bar for content. A panel has a header, one accent element (the selected row, the
send, the progress) and the brand's corners.

**Light.** Surfaces are lit: a card is its ground lifted 6–10 % in lightness with a 1 px edge of white at 8–14 %, or glass
(`glass`); the hero casts a soft shadow or, in a dark film, a glow in the accent under it.

**Timing.** Scenes are 0.7–3 s, each a whole number of beats when the score has a beat. Parts arrive 40–80 ms apart, rising
out of a blur; exits are half as long as entrances and run into the cut. Things arrive slightly large and settle;
overshoot only in a playful film, never on type.

## 10. Write, check, export

1. Load `reco-story-film` (the hand, the macro, the voice, answers as things) and the other technique skills for your
   moves, and read their recipes. set_style (with fonts) and set_canvas first, then the whole film in one edit_motion call.
2. preview_motion, and check:
   - Its findings: every one that says **the picture stands still** names a scene to fix: give it an action from section 7
     or cut it shorter. The film is done only when none is left.
   - Does the first frame move, and do the first words read by 2 s?
   - Can you say each scene's action in one verb, and each transition's reason? Six or more actions, four or more seams?
   - Is every line in the brand's own face, its colours and its corners? Would someone who knows the product's site
     recognise it with the logo covered?
   - Is anything small in a void, tilted, a grey bar, or a dense panel? Rebuild it bigger and simpler.
   - Would someone who knows the reference films recognise one of them scene for scene? Then change it.
   Fix everything in one edit_motion call. Stop after three previews. Never add a scene to try something out: the
   preview is the test, and a film that ran out of time with one in it showed a calibration card first.
3. Export with export_recording: format hevc, resolution 2160, at 60 fps.
