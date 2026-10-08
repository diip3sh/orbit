# Longer films: macro and motion design together

A film of 45–60 s holds attention when it changes register: the product's real UI up close (reco-launch-film's
macros), then a passage of motion design that tells one flow, then the real UI again with the result, then the
closing. Load reco-launch-film too and follow both. This file says how they meet.

## Shape of the film

| Part | Length | Kind | What it shows |
|---|---|---|---|
| Opening | 3–4.5 s | Macro | The product's real control, close: a search, a prompt, an editor. The first second is ground alone. |
| Tour | 6–10 s | Macro, 2–3 stops | The real UI working: typing, results, a selection, a whip to the next part. |
| The flow | 12–20 s | Motion design | One thing the product lets you do, as morphs: tap, a state that floods, choices that split, a confirmation that bursts. |
| The result | 3–5 s | Macro | The real UI showing what the flow made: the shared playlist, the merged branch, the sent invoice. |
| Closing | 0.42 s a word + 4.5 s (+1.6 with a logo) | Closing shot | reco-launch-film's closing. |

## Where they meet

- **Into motion design on a match cut.**
  - The macro's last frame has a control at a place, size and colour. The design passage's first scene starts on
    a shape at that place and size, in that colour: the field's box becomes a pill, a button becomes the dot that
    grows.
  - Cut on the beat. Never fade.
- **Out of motion design on a whip** to the result's macro (`seam: whip`), or a cut from the last state (a check,
  a dot) to the real UI's matching element.
- **One look for the whole film.**
  - Satin works for both kinds.
  - A light look (`ember`) under macros wants its full strength, and under motion design about half. Choose
    `fieldStrength` 0.6 for a film with both, or give each scene its own `field` from the look's list as
    reco-launch-film says.
- **One beat.**
  - Make scene lengths multiples of 0.48 s (125 BPM): 3.36, 3.84, 4.32, 4.8.
  - Put the design passage's morphs on the beat, so the cuts and the moves keep one pulse.
- **Type** stays the system's sans in the design passage. The closing keeps its small mono caps.

## Order of work

1. Research once for both. Find the real controls for the macros (reco-launch-film, section 1) and the flow and
   liftable parts for the design passage (this skill, step 1).
2. Write every asset in one edit_motion call and capture once.
3. Write the macros first, then the design scenes between them, matching sizes and places across each meeting
   cut.
4. Preview. Check the two meetings frame by frame: the shape after the cut is where the control was.
