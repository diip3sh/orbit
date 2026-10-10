---
name: reco-story-film
description: Reco's launch film, the default. One person's real job is told through the product's own UI, rebuilt as things that move, with the motion of Lovable's chat launch. What they say is typed big, the product's controls are clicked in macro, its answers arrive as things (tiles, cards, a collage, a result read close), and every scene comes out of the last through a transition with a reason (a click opening into the next, a view stacking over the last, the look's seam), on a 170 BPM grid with a sound for each. The look is the product's own theme over one of Reco's shader looks (dither, light, satin, or the aurora for a brand whose colour is a gradient). Use it for any product unless the user asks for another kind: prompts, chats and agents, and calendars, notes, editors, dashboards alike. Its reference files are read one at a time, when a step says so.
---

# A story film, Reco's way

Two things make it, and they come from different places:

- **The motion is Lovable's** (its chat launch, 48 s): a prompt box, a macro on its controls, the voice typed big, a wash
  when it's sent, the answers arriving as things on the beat, end words a word at a time.
- **The look is the product's own**, over one of Reco's shader looks. Lovable's colours are Lovable's: never paint its
  gradient, its greys or its aurora on a product that doesn't have them.

## The motion

1. The product's main control arrives over the ground: its prompt box, search, calendar, editor or new-task dialog. Cut on
   a beat to macro: one of its pills or buttons, a hand on it. Its menu opens and the highlight follows the hand.
2. The person talks: "I've got five bugs and one evening" is typed huge, the newest words in the gradient, the line
   sliding left behind a thin caret.
3. Back in the box: the request, its attachments. The hand presses send and the gradient washes across the box. The
   thread comes up over it: "Thinking…" shimmers, the reply arrives word by word.
4. The answers are things, not screenshots: a bento of the product's actors popping from the middle out, then all
   swapping status on one beat; its outputs thrown out of a stack into a collage; one result read close, a comment sent.
5. Big type with the logo.
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
- **Cut on a beat.** Lovable's cuts land on its 170 BPM track: a beat is 0.353 s, a bar 1.412 s. Every scene is a whole
  number of beats and a cut comes every 1–3 s, so the cutting has its rhythm.
- **Transitions you hear.** Under quiet chords that change with the shots, each transition has its own sound: the dots
  of a dither seam, the light of a glow, the swell and hit of the ring into the logo, a shimmer as the box is sent, a
  chime as things turn to done, a soft swish on a cut. No drum loop: a beat under every cut was the same sound
  everywhere.
- **Something on every cut.** On a cut, the layer that carries on is there on the scene's first frame, or the first new
  thing pops at 0. The ground is never alone after a cut. After one of the look's seams, the seam is the entrance.
- **Never still.** Something changes on every beat: a hand, a pop, typing, a swap, a scroll, the camera. The next move
  starts before the last has settled. A line being read is no pause: while it's read, a chip pops beside it, the hand
  goes to the next control, the camera pushes in. Lovable's film is still in 8 % of its frames; a film of cards that
  appear and wait is still in half of them, and reads as a slideshow.
- **Out of each other.** The next thing comes out of what's there: a clicked card opens into the next scene, the thread
  comes up over the box, a pill morphs into its next state, a button floods the frame. Read *Transitions*.

`reference/film.md` has Lovable's film shot by shot with every timing measured. Read it before your first storyboard.
Take its motion and timing, never its colours.

## Transitions

Every change of scene is a transition with a reason, and you can name it:

| What happens | Seam on the next scene |
|---|---|
| The scene clicks something (a card, a button, send) and the next scene is what it opens | `expand`: the next scene opens out of the clicked thing, as an app opens from its icon. Make it the scene's last click, pressed in its last 0.5 s |
| A new view of the product comes over the last: the thread over the box, a detail over a list, a form over a calendar | `stack`: the next scene rises on a card while the last sinks back |
| The camera goes to another part of the same thing | `whip` |
| The three turns: the opening, the first answer, the end words | the look's seam: `dither` or `glow` (below) |
| The end words into the logo | `ring`, with `"field": "halo"` |
| The next scene moves on its first frame: a voice line typing, a pop at 0, a scatter, a scroll | `cut`: the motion on the cut carries it |

- Never the same seam on two scene changes running, and never more than two cuts running. A film of 15 scenes uses at
  least four kinds.
- Never a cut onto something still.
- Inside a scene, a change of state is a move, not a cut: a pill `morph`s into its next size and colour, a button
  `flood`s the frame, a done thing `burst`s. Their fields are in `../reco-motion-design/reference/moves.md`; read it when
  you use one.

## The look

### The product's theme

Read the brand from inspect_page (`brand`: colours and fonts) and from its site's own UI, and rebuild everything in it:

- the ground colour (`canvas.background`): the site's own, e.g. `#08090a`;
- surfaces are glass: the box, menus, tiles and cards are panes (`"glass": true` on their fill, a light veil `#ffffff0d`
  for colour), the look's ground blurred through them, their rims lit; their pills and chips `#ffffff14`;
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

The look's own seam (`dither` or `glow`) marks the three turns, never more:

- **The opening.** Name it on the first scene (`"seam": "dither"`): the ground swells in from black over 0.6 s and the
  box arrives in the seam by 1.4 s. Make that scene 6 beats and start nothing in it before 1.4 s.
- **Into the first answer** (the bento): the thread goes to the look's dots or light and the answer's scene comes
  through. Start its entrances (the pops) at 2 beats (0.706 s), as the seam ends.
- **Into the end words:** the first end word arrives in the seam, no entrance of its own.
- **Into the logo:** `"seam": "ring"` with `"field": "halo"` on the logo's scene (dither and light looks): a ring of
  smoke opens from the middle and leaves the logo in a halo in the brand's colour.

The aurora and satin have no seam of their own: their turns take `stack` or `expand`. The aurora's light goes out over the
last 2 s.

### The gradient

`style.gradient` colours new words, the voice's caret, the shimmer on "Thinking…" and the end words, and the wash when
something is sent. Nowhere else: the UI keeps its own colours.

- The brand's own gradient, 2–5 colours, cool end first; or its colours in order of hue.
- A black and white brand: grey into white, `["#a3a9b3", "#dcdfe4", "#ffffff"]`. Never invent colours it doesn't have.

## Which skill

| The film | Skill |
|---|---|
| One person's job told through the product (the default) | this one |
| The user asks for the real UI up close, typed into and toured, or Raycast's look | reco-launch-film |
| The user asks for motion design: one object morphing state to state (Spotify Jam) | reco-motion-design |

## Method

1. **Research.**
   - Call inspect_page on the product's site and the pages its navigation links to.
   - Find:
     - the product's main input (a prompt, a chat, a command bar, a "new task" dialog, a booking calendar, a notes editor)
       and its controls (pickers, pills, send, confirm);
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
   - Does each shot answer the last, and does every scene change have its transition (*Transitions*)?
   - Is anything still for more than a beat and a half?
   - Is it the product's theme everywhere, and the gradient only on new words, shimmers and washes?
   - Is the type at least 34 px, and is every answer whole in the frame (preview_motion names text that runs off it)?
   - Do labels sit clear of each other (attachments, chips, a swapped label)?
   - Does the hand land on what it presses?

   Fix everything in one edit_motion call. Stop after three previews.
8. **Export** with export_recording: format hevc, resolution 2160, and no frame_rate: the film's own 60 fps (H.264 stops
   at 30 fps at 4K).

`reference/example.md` is a whole document of this kind: Lovable's film rebuilt, over the aurora because Lovable's colour
is a gradient. Read it for how the parts fit, and take your look from your brand.

## Settings

- **Canvas:** `{"size": [1920, 1080], "frameRate": 60, "background": "<the site's ground>", "field": "<the look's field>",
  "fieldStrength": <the look's>, "pacing": "beats"}`.
- **Style:** `text` the site's text colour; `accent` the brand's colour (white for a black and white brand); `gradient`
  as above; `face` sans.
- **Sound:** leave `sound` out: the ambient score and the transitions' sounds. Never `groove` or `house` here.
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
- A flat, opaque card or box over the look's ground: every surface is glass.
- Two looks in one film, a seam from another look, or the look's seam at more than its three turns.
- A cut onto something still; the same seam on two scene changes running.
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
