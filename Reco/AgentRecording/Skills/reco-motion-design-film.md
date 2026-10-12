# The reference, beat by beat

LordyVisuals' Spotify Jam concept, measured frame by frame at 30 fps. Times are seconds into it; sizes are at
1920×1080. Its music is about 125 BPM, so a beat is 0.48 s, and its one hard cut lands on a beat.

| Time | What happens | In Reco |
|---|---|---|
| 0–0.4 | A green glow sweeps up the ground. "Queue / Playing Songs … Clear" rises into place. | Header group, `fadeUp` |
| 0.4–1.6 | Rows build about 0.35 s apart: cover art, the title typed in, its icon popping. The list moves up as it grows. Rows are 219 px apart, their art 135 px. | Rows in a group, `cascade` |
| 1.6–3.2 | The list scrolls fast, about 1.8 frame heights a second at its fastest, blurred. Rows build as they come into view. It eases to rest on the last three. | `scroll` on the group, after its `cascade` |
| 3.37–3.77 | A green dash under the list grows into a pill 560×184 in 0.43 s, slow off, fast, long settle, as the list leaves upwards, blurred. | Shape: `pop`, then `morph` size; list `exit` up |
| 3.7–4.5 | The pill rises to the middle, glowing, before it's done growing; "This is different" comes in inside it while it's still rising. | Pill `morph` to; text `letters` |
| 4.5–4.9 | "This" drops and "different" lifts away. | Text `exit` |
| 4.87–4.97 | Hover: the pill lifts about 75 px and grows 20 % in 0.1 s. "Start a Jam" springs in a letter at a time, 0.036 s apart: each comes up from below its line at a third of its size, is at 1.35× a quarter line above its place 0.1 s in, and settles over 0.3 s. The type is about 64 px, bold, black. | `morph` size and to (duration 0.12), the label's `morph` to with it; text `letters` |
| 4.8–5.2 | An arrow comes up from below the frame in about 0.3 s, fast then slowing, blurred, and turns to a hand over the pill: the hand is 8 % of the frame's height. The press brings the pill back down. | `click` on the pill; `morph` back |
| 5.77–5.93 | The pill dips to 0.57 of its size in 0.17 s. | `flood` (its first part) |
| 5.97–6.33 | Flood: a rounded rectangle about the frame's shape grows out of it, 0.37, 0.54, 0.66, 0.76, 0.84 of the frame's width a frame apart, covers it 0.3 s on and stops just past its corners. A "Starting" chip is in the middle from the start. | `flood`; chip group `pop` with it |
| 6.33–7.13 | All green. Lighter and darker bands open outward from the middle, inside the green. | `ripple` with `stroke` 70–90, twice |
| 7.13–7.33 | Iris: the green closes back toward a pill, its bands inside it. A hard cut lands on the beat. | `morph` back to a pill size |
| 7.4–8.0 | The pill's fill drains to an outline at once. Three avatars slide in from the right, blurred by their speed, then a "3". | `morph` color to clear; avatars `slideIn`; "3" `pop` |
| 8.0–8.5 | The outlined pill moves left; "Invite" and "Leave" slide out of it to the right as their own outlined pills, slowing into place. | `morph` to; groups `pop` and `morph` to from where the outline was |
| 8.4–9.2 | The hover's green outline moves from Invite to Leave. | Ring `morph` color, there and back |
| 9.3–9.7 | Invite fills green and lifts; the others blur away. Invite flies to where the text will start, shrinking to a dot, blurred by its speed. | `morph` stroke 0, then size; `click`; `morph` to up, then to the caret's place; others `exit` |
| 9.8 | The dot stretches into a tall caret. A green pulse lights the ground. | `morph` size [16, 130] |
| 10.0–10.8 | "Black & Tan" is typed big and bold at about 13 characters a second. The newest letters are green, fading to white, behind a thick green caret. | Text `kinetic`, about 150 px |
| 10.4–11.5 | A pointer clicks the words. The camera pushes in about 25 % and the caret goes. | `click`; camera `push` intensity 2 |
| 11.7–12.6 | The words vanish and the song's row flies in from far off. The camera pans along it to a "+", which spins in. | Lifted row `pop`; camera `pan` to the row, then to the plus; plus `pop` and `spin` |
| 12.7–12.9 | Hover: a grey disc pops behind the "+", overshooting to 1.6× and settling in 0.2 s. | Disc shape `pop` |
| 13.0–13.4 | The disc fills green. About 40 sharp green triangles burst out across the frame and drift, a check pops in, and a thin ring pulses round the disc. | Disc `morph` color, `burst`, `ripple`; check `pop` |
| 13.8–14.0 | The camera pulls back; the check becomes the row's icon in the queue. | Camera `pan` back out to the frame's middle, `intensity` 1 |
| 14.0–16.8 | The queue builds again under the song and scrolls to its end. | As at the start |
| 16.9–18.0 | The logo sharpens up from under the list as the list leaves. | Logo `blurIn`; list `exit` up |
| 18–19 | The logo fades out. | Logo `exit` |

Its weak part is its ground, a flat green gradient across the top. Reco's light look toned down (`ember` at
`fieldStrength` 0.45) or satin replaces it.
