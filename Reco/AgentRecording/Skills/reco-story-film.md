---
name: reco-story-film
description: Reco's story film. One person's request is told through the product's own prompt or chat, with the motion of Lovable's chat launch. What they say is typed big, the product's controls are clicked in macro, and its answers arrive as things (tiles, cards, a collage, a result read close), cut to a 170 BPM beat. The look is the product's own theme over one of Reco's shader looks (dither, light, satin, or the aurora for a brand whose colour is a gradient), with seams in that look's language. Use it for a product driven by a prompt, chat, command bar or agents (AI builders, coding agents, assistants), and when the user asks for a story, a customer's journey, Lovable's style or type in a gradient. Its reference files are read one at a time, when a step says so.
---

# A story film, Reco's way

Two things make it, and they come from different places:

- **The motion is Lovable's** (its chat launch, 48 s): a prompt box, a macro on its controls, the voice typed big, a wash
  when it's sent, the answers arriving as things on the beat, end words a word at a time.
- **The look is the product's own**, over one of Reco's shader looks. Lovable's colours are Lovable's: never paint its
  gradient, its greys or its aurora on a product that doesn't have them.

## The motion

1. The prompt box arrives over the ground. Cut on a beat to macro: its agent or mode pill, a hand on it. Its menu opens
   and the highlight follows the hand.
2. The person talks: "I've got five bugs and one evening" is typed huge, the newest words in the gradient, the line
   sliding left behind a thin caret.
3. Back in the box: the request, its attachments. The hand presses send and the gradient washes across the box. Cut to
   the thread: "Thinking…" shimmers, the reply arrives word by word.
4. The answers are things, not screenshots: a bento of the product's actors popping from the middle out, then all
   swapping status on one beat; its outputs thrown out of a stack into a collage; one result read close, a comment sent.
5. Big type with the logo, and the beat drops out under it.
6. Macro on the finish: "Merge all", "Ship", "Deploy", pressed.
7. End words, one a scene on the beats, then the logo.

What makes it good, and what yours must have:

- **A story, not a tour.** One person with one real job asks for help, and every shot is the product answering them.
  Write their lines first person, as they would say them.
- **The product's own controls, close.** The prompt, its pills, the send button: rebuilt as shapes and type, shown in
  macro, each clicked by a hand as large as the button it presses.
- **The voice as type.** What they say is typed big. The newest words are in the gradient and turn to the text's colour
  after 0.8 s.
- **Answers as things.** What the product gives back is rebuilt as tiles and cards: the agents or people at work as a
  bento with their marks, the files, pull requests or tickets as a collage of cards, one result read close. They pop,
  scatter and swap. Never a page, pane or terminal lifted as a screenshot.
- **Framed whole.** Every answer sits whole in the frame, centred, 60–80 % of its width, its type at least 34 px. Only a
  macro on one control crops.
- **Cut to the beat.** The track is 170 BPM: a beat is 0.353 s, a bar 1.412 s. Every scene is a whole number of beats
  and a cut comes every 1–3 s.
- **Something on every cut.** On a cut, the layer that carries on is there on the scene's first frame, or the first new
  thing pops at 0. The ground is never alone after a cut. After one of the look's seams, the seam is the entrance.

`reference/film.md` has Lovable's film shot by shot with every timing measured. Read it before your first storyboard.
Take its motion and timing, never its colours.

## The look

### The product's theme

Read the brand from inspect_page (`brand`: colours and fonts) and from its site's own UI, and rebuild everything in it:

- the ground colour (`canvas.background`): the site's own, e.g. `#08090a`;
- surfaces for the box, menus, tiles and cards: the site's card and raised colours, with its border (often white at
  8–12 %);
- type: its text colour, a dim tone for notes, `face` sans for its UI font and `mono` wherever the product shows code,
  branches, ids or paths;
- its button style: a light primary button stays light (the send disc, a "Merge all"), a dark one dark;
- its status colours (green for passed, red and green for diffs) as it uses them.

Colour comes from what the answers show, as on the product's own site: each agent's, model's or integration's mark in
its own colour, status, diffs, photos. A colourful product (a design tool, a moodboard) has colourful tiles; a black and
white product keeps its tiles its own greys and lets the marks carry the colour. Its own tile in a bento can be inverted
(its light colour, its mark dark) to anchor it.

### The ground: one of Reco's looks

Choose one from the brand and keep the whole film in it (one look a film):

| The brand | Look | `canvas.field` | `fieldStrength` | Seam |
|---|---|---|---|---|
| Black and white, or a technical product (developer tools, agents, infrastructure, CLIs) | dither | `warp` (liquid streaks; the default), `tide` (a wave from below), `swirl` | 0.45 | `dither` |
| A clear hue (AI, design, consumer) | light | `ember` (two corners), `sunlit` (a wave), `bloom` (a blob) | 0.45 | `glow` |
| Its colour is a gradient of several hues (Lovable, Stripe) | aurora | `aurora` | 0.8 | cuts only |
| Dark and quiet, its colour all in its UI | satin | `satin` | 1 | cuts only |

- The dither and light looks take their colour from `style.accent`: the brand's colour, or white for a black and white
  brand (its dots or light in greys).
- Never `matrix`, `orb` or `ripple` here: a sphere or rings in the middle of every frame sit under the type.
- The field runs on across cuts: a cut keeps the ground. Give every scene the canvas's field, except the logo's (below).

### The look's seams

Cuts on the beat are the film's transition. The look's own seam (`dither` or `glow`) marks the three turns, never more:

- **The opening.** Name it on the first scene (`"seam": "dither"`): the ground swells in from black over 0.6 s and the
  box arrives in the seam by 1.4 s. Make that scene 6 beats and start nothing in it before 1.4 s.
- **Into the first answer** (the bento): the thread goes to the look's dots or light and the answer's scene comes
  through. Start its entrances (the pops) at 2 beats (0.706 s), as the seam ends.
- **Into the end words:** the first end word arrives in the seam, no entrance of its own.
- **Into the logo:** `"seam": "ring"` with `"field": "halo"` on the logo's scene (dither and light looks): a ring of
  smoke opens from the middle and leaves the logo in a halo in the brand's colour.

The aurora and satin cut everywhere; the aurora's light goes out over the last 2 s.

### The gradient

`style.gradient` colours new words, the voice's caret, the shimmer on "Thinking…" and the end words, and the wash when
something is sent. Nowhere else: the UI keeps its own colours.

- The brand's own gradient, 2–5 colours, cool end first; or its colours in order of hue.
- A black and white brand: grey into white, `["#a3a9b3", "#dcdfe4", "#ffffff"]`. Never invent colours it doesn't have.

## Which skill

| The film | Skill |
|---|---|
| The product's real UI at work, close: typing, results, a tour (Raycast's look) | reco-launch-film |
| A flow through the UI as motion design: states that morph, clicks, floods, bursts (Spotify Jam) | reco-motion-design |
| One person's request told through the product's prompt, chat or agents | this one |

## Method

1. **Research.**
   - Call inspect_page on the product's site and the pages its navigation links to.
   - Find:
     - the product's main input (a prompt, a chat, a command bar, a "new task" dialog) and its controls (mode or agent
       pickers, send, mic);
     - what the product gives back (agents, tasks, files, pull requests, previews, designs);
     - its theme: background, surfaces, border, text, fonts, button style, status colours, logo.
   - Web search what it's for, if you can.
2. **Story.**
   - Pick one person and a concrete job that the product does well, e.g. "I've got five bugs and one evening".
   - Write 5–7 beats:
     1. the ask (voice);
     2. the product's control, close (picking a mode or an agent);
     3. the first answer (a thing);
     4. a short second ask;
     5. the second answer;
     6. the finish (macro on the last button: merge, ship, build);
     7. the end words and the logo.
   - Lines are short, first person, plain: never hype or questions to the viewer.
3. **Look.** Choose the look, its field and the gradient from the brand (above). Write down the theme's colours.
4. **Timing.** Give every scene a whole number of beats: 2 (0.706 s), 3 (1.059), 4 (1.412), 5 (1.765), 6 (2.118),
   8 (2.824), 9 (3.177). Aim for 30–40 s in 14–18 scenes. Put each click, swap and word on a beat too.
5. **Assets.**
   - The marks: the product's logo lifted `bare` from its site, and every brand the film shows (agents, models,
     integrations) from Simple Icons as SVG (`reference/recipes.md`, *The marks*), tinted in their own colours.
   - Rebuild everything else as shapes and type (`reference/recipes.md`) in the product's theme, with its real names,
     tasks, branches, files and numbers from your research.
   - Lift a card or panel only when it's simple, still and sharp at 2×. Never a terminal, a docs screenshot (`img`) or a
     mockup the site animates: the first is unreadable, the second blurred at 4K, the third caught mid-animation.
   - Write all assets in one edit_motion call, then call capture_ui. It gives each asset's size.
6. **Write the scenes.** Copy the components from `reference/recipes.md`: read it now. It has the box, a macro, a menu,
   the voice, send and the thread, a bento of actors, a collage of outputs, one output read close, a statement with the
   logo, the finish, the end words and the logo.
7. **Check.** Call preview_motion and look at every frame:
   - Is every scene a whole number of beats?
   - Does each shot answer the last?
   - Is it the product's theme everywhere, and the gradient only on new words, shimmers and washes?
   - Is the type at least 34 px, and is every answer whole in the frame (preview_motion names text that runs off it)?
   - Do labels sit clear of each other (attachments, chips, a swapped label)?
   - Does the hand land on what it presses?

   Fix everything in one edit_motion call. Stop after three previews.
8. **Export** with export_recording: format h264, resolution 2160.

`reference/example.md` is a whole document of this kind: Lovable's film rebuilt, over the aurora because Lovable's colour
is a gradient. Read it for how the parts fit, and take your look from your brand.

## Settings

- **Canvas:** `{"size": [1920, 1080], "frameRate": 30, "background": "<the site's ground>", "field": "<the look's field>",
  "fieldStrength": <the look's>, "pacing": "beats"}`.
- **Style:** `text` the site's text colour; `accent` the brand's colour (white for a black and white brand); `gradient`
  as above; `face` sans.
- **Sound:** `{"style": "groove"}`.
- **Sizes** (Lovable's, measured):
  - box 1190×370, corners 44, its hint 50 px; pills 84 tall with 42 px labels; the send disc 88;
  - voice 130–140 px `regular`; a statement with the logo 120–130 px;
  - the thread: the request 54 px, the reply 66 px;
  - in tiles and cards: names 44 `semibold`, what they do 34; chips 32;
  - end words 260 px `bold`, a tagline 150–170.
  - Set `weight` on every text layer: the default is semibold.

## Never

- A screenshot of a page, a terminal, a transcript or a docs image as an answer: rebuild it as things.
- Colours the product doesn't have: Lovable's gradient or aurora on another brand, a violet glow on a black and white one.
- Two looks in one film, a seam from another look, or more than the four seams above.
- An answer cut by the frame's edge, or small in a wide empty frame.
- Text on attachments in a stack, or two labels in one place at once.
- A fade between scenes, a slide in from the side, a title card.
- A scene that isn't a whole number of beats, or a hold of more than a beat and a half with nothing moving.
- A scene whose first frame is the ground alone (except the opening), an entrance on the end words or the logo, or list
  rows spun in (rows cascade; a small spin is for tiles).
- Hype copy, exclamation marks in the product's words, emoji.
- Text under 34 px; chips 32, and nothing under 32 except inside a control the camera is close on.

## From the chat

Change only what's asked. "Faster" is about two thirds of the timings, kept on beats. Preview once; don't export unless asked.
