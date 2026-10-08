# The reference, beat by beat

LordyVisuals' Spotify Jam concept, measured frame by frame at 30 fps. Times are seconds into it; sizes are at
1920×1080. Its music is about 125 BPM, so a beat is 0.48 s, and its one hard cut lands on a beat.

| Time | What happens | In Reco |
|---|---|---|
| 0–0.4 | A green glow sweeps up the ground. "Queue / Playing Songs … Clear" rises into place. | Header group, `fadeUp` |
| 0.4–1.6 | Rows build about 0.35 s apart: cover art, the title typed in, its icon popping. The list moves up as it grows. Rows are 219 px apart, their art 135 px. | Rows in a group, `cascade` |
| 1.6–3.2 | The list scrolls fast, about 1.8 frame heights a second at its fastest, blurred. Rows build as they come into view. It eases to rest on the last three. | `scroll` on the group, after its `cascade` |
| 3.37–3.77 | A green dot under the list grows into a pill 560×184 in 0.43 s, slow off, fast, long settle. | Shape: `pop`, then `morph` size |
| 3.8–4.5 | "This is different" comes in word by word inside the pill. The pill rises to the middle, glowing. | Text `wordByWord`; pill `morph` to |
| 4.5–4.9 | "This" drops and "different" lifts away. | Text `exit` |
| 4.87–4.97 | Hover: the pill grows 10 % in 0.1 s. "Start a Jam" springs in a letter at a time, 0.036 s apart, each overshooting. The type is about 64 px, bold, black. | `morph` size (duration 0.12); text `letters` |
| 4.8–5.2 | An arrow rises from below in 0.5 s and turns to a hand over the pill: the hand is 8 % of the frame's height. The press shrinks the pill back. | `click` on the pill |
| 5.77–5.93 | The pill dips to 0.6 of its size in 0.17 s. | `flood` (its first part) |
| 5.97–6.33 | Flood: the pill grows past the frame's corners in 0.4 s, fast then settling. A "Starting" chip stays in the middle. | `flood`; chip shape with `stroke` |
| 6.33–7.13 | All green. Lighter and darker bands open outward from the middle. | `ripple` with `stroke` 70–90, twice |
| 7.13–7.33 | Iris: the green closes back toward a pill. A hard cut lands on the beat. | `morph` back to a pill size |
| 7.4–8.0 | The pill's fill drains to an outline. Three avatars slide in, blurred by their speed, then a "3". | `morph` color to clear; avatars `cascade`; "3" `pop` |
| 8.0–8.5 | The outlined pill moves left; "Invite" and "Leave" pop out of it as their own outlined pills. | `morph` to; groups `pop` |
| 8.4–9.2 | The hover's green outline moves from Invite to Leave. | Ring `morph` color, there and back |
| 9.3–9.7 | Invite fills green and lifts; the others blur away. Invite shrinks to a dot, blurred by its speed. | `morph` stroke 0, then size; `click`; others `exit` |
| 9.8 | The dot stretches into a tall caret. A green pulse lights the ground. | `morph` size [16, 130] |
| 10.0–10.8 | "Black & Tan" is typed big and bold at about 13 characters a second. The newest letters are green, fading to white, behind a thick green caret. | Text `kinetic`, about 150 px |
| 10.4–11.5 | A pointer clicks the words. The camera pushes in about 25 % and the caret goes. | `click`; camera `push` intensity 2 |
| 11.7–12.6 | The words become the song's row. The camera pans along it to a "+", which spins in. | Lifted row; camera `pan` to the plus; plus `pop` |
| 12.7–12.9 | Hover: a grey disc pops behind the "+", overshooting to 1.6× and settling in 0.2 s. | Disc shape `pop` |
| 13.0–13.4 | The disc fills green. About 40 green triangles burst out and drift, a check pops in, and a ring pulses out. | Disc `morph` color, `burst`, `ripple`; check `pop` |
| 13.8–14.0 | The camera pulls back; the check becomes the row's icon in the queue. | Camera `pullBack`, or a cut on the beat |
| 14.0–16.8 | The queue builds again under the song and scrolls to its end. | As at the start |
| 16.9–18.0 | The logo sharpens up from under the list as the list leaves. | Logo `blurIn`; list `exit` up |
| 18–19 | The logo fades out. | Logo `exit` |

Its weak part is its ground, a flat green gradient across the top. Reco's light look toned down (`ember` at
`fieldStrength` 0.45) or satin replaces it.
