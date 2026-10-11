# The film director

> Reco's launch films came out as copies of the films its skills learned from: an InstaLanding film kept ElevenLabs' 14
> scenes and their timings with new words. A `reco-director` skill now plans every film first (a brief from the brand and
> the user's few words, a story shape, one look, moves borrowed from any skill, a bridge at every cut) and names the
> technique skill to write it with. The engine learns what made ElevenLabs' film smooth: nothing is ever still, and one
> thing carries across every cut.

## Why

On 2026-10-11 the user compared ElevenLabs' film with Reco's rebuild side by side: the reference had "a lot smoother and
better transitions and animations", ours had "many transitions missing", and the speed was wrong. They also asked for the
opposite of a copy: learn from each film, keep the learning as skills, and have Claude Code build "a different video every
time" from those skills and Reco's shaders, by the brand and a small prompt from the user. The first is for a recent YC
startup, to post on X.

## The rebuild against the film, measured

Per-frame difference at 480 px, grey; frozen means no pixel changes by more than 6 levels beyond about 13 pixels.

| | ElevenLabs | Rebuild (spec 0017) |
|---|---|---|
| Frozen frames before the end card | 5.9 % | 26.4 % |
| Longest freeze before the end card | 0.57 s (typing pauses) | 1.73 s |
| Pixels changing per frame, median | 1.55 % | 0.22 % |
| Cuts from a frozen frame | 0 of 14 | 6 of 10 |

The film keeps something small moving and carries an object across almost every cut:

- "Your agents" is eaten from both ends by the mark's bars (280 → 39 px in 0.28 s, ease-in). The square grows (40 → 336 px in
  16 frames) and becomes the picture.
- The last line is eaten into the mark (989 → 37 px in 11 frames), and the wordmark opens from it.
- A picture irises into a circle bigger than the frame, still shrinking after the cut.
- A pill accelerates into the cut onto the next card's bar.
- The ground darkens into the dark beat in 11 frames, eased out, its objects staying; there are no cross-dissolves.

After a cut a move is at its fastest: half done in 0.12–0.23 s, nine tenths by 0.4–0.5 s. Held shots creep (grounds about 2 %
a second, pictures pulling back 6–16 % a second). Before a cut things accelerate: the wordmark grew 5 % in its last 0.4 s.

## The engine

| Part | What | Files |
|---|---|---|
| `eat` | Text eaten by two bars from its ends to its middle into a block: 0.25 s on an ease-in, by default the scene's last 0.25 s; the bars a fifth of a line wide, three quarters tall, starting a third of a line outside the text, in `color` or the text's; drawn in the room around the text as letters are | `MoveExpansion+Editorial`, `MotionPlan.Eat`, `MotionFrameRenderer.eaten` |
| Breathing | In an editorial film every scene without a camera of its own but the last: in at 1.04× settling on τ 0.17 s (half in 0.12 s), creeping 1.5 % a second, 3 % more over its last 0.4 s on an ease-in | `MoveExpansion.breath(over:)`, `MotionPlan.breathe` |
| Darkening | A `fade` in an editorial film: 0.18 s eased out, not a 0.5 s dissolve | `SeamExpansion.darkenDuration`, `Transition.easing` |
| Lint | An eat is when a line leaves: its reading time ends there | `MotionLint` |

On the rebuild with two eats and these changes: frozen frames 26.9 → 14.7 %, the longest freeze 1.73 → 0.82 s, the median
share of pixels changing 0.23 → 0.37 %.

## The director

`reco-director` (`Reco/AgentRecording/Skills/reco-director.md`) is the first skill every Claude Code launch run loads:

1. **Research** the product and why it's talked about now.
2. **A brief:** the idea in one sentence, the tension, the hero moment, the tone (the user's words decide), 20–35 s, the
   first words read by 2 s since X plays muted.
3. **One look** by the brand (editorial, haze, aurora, light, dither, satin) and the skill that teaches it.
4. **A story shape** of six (the ask, before and after, claim and proof, one object, zoom in, the conversation), never an
   example's. The app sends a `Variation` (1–6, random per run) that picks among the shapes that fit, so the same product
   gets a different film each time.
5. **Moves from any skill:** only fields and seams belong to a look.
6. **A bridge at every cut:** grow into, collapse into, match, into what was clicked, over it, the look's seam, a cut on
   motion. At least half of the changes are devices, never the same twice running, never a cut onto something still.
7. **Motion,** with the numbers measured above.

The technique skills' story steps defer to it; the editorial skill lists the scenes its look does well instead of the
reference's arc, and its example says its story and words are ElevenLabs'.

## Open

- An `ease` on morphs and camera moves, so a picture can iris into the cut accelerating as the film's did.
- Breathing in the other looks (their skills ask for a camera move a scene instead).
- Whether the variation gives different enough films for one product: not yet run twice.
- Reference looks still led films (the LemonLime film's prompt named ElevenLabs): spec 0019 takes the look from the product's site and adds graphic transitions.
