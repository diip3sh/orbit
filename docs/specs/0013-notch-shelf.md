# 0013 — Notch shelf

Status: built 2026-10-03 (`feat/screenshot-history`, on top of spec 0012). Not yet seen running: see "Unverified".

## Why

Screenshots (saved or in the history, spec 0012) are a click away in the Library, but the Library is a
window. The notch is the one spot on a MacBook that is always there and never in the way: a shelf that
grows out of it shows the newest screenshots at once, like Alcove, NotchNook or the Dynamic Island.

## What

- A black shape at the top centre of every screen. On a notched display it is exactly the notch (black on
  black, invisible); elsewhere a 120×8 pt pill, flush with the top edge.
- Two stages, as in notchi. **Peek:** the pointer on the shape grows it 7.5 pt to each side and 5 pt down and
  gives it a shadow. **Open:** the pointer staying 300 ms grows it into a 560 pt wide panel. Leaving the
  panel collapses it after 500 ms; coming back cancels that. Reduce Motion: no spring, the shape changes at
  once and the content cross-fades.
- Open: "Screenshots" and their count, and a scrolling strip of the newest 20 (saved ones in the
  screenshot folder and unsaved ones in the history), newest first. **Click** copies the PNG and the tile
  says Copied for 1.2 s; **drag** drops the file into another app. No screenshots: "No screenshots yet".
- **Settings → Screenshots → History → Show Screenshots in the Notch** (on by default; in General until 2026-10-08).
- Taken away as a screenshot starts and brought back as it ends, so it isn't in the shot.

## Rules

- `NotchGeometry` (pure) holds every rect, in global coordinates: the notch is the gap between
  `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` (only their widths and height are read, so their
  coordinate space doesn't matter); no areas, or no room for a notch, is a pill. Open = 560 pt (less on a narrower screen) wide, centred on the
  notch and kept on the screen, `contentTopInset` (the notch's height, 12 pt under a pill) plus 132 pt
  tall: 164 pt on a 14" MacBook Pro.
- Motion (`NotchMotion`, the numbers match notchi's measured feel, at the user's request on 2026-10-04; no
  code was taken, notchi is GPL-3.0). **This is the one place that overshoots on purpose**, an exception to
  the bounce-free rule. Springs `(response, damping)`: peek in 0.36/0.74, peek out 0.28/0.96, open 0.5/0.78,
  collapse 0.36/0.88. Shadows are black, blur 6: 0.3 while peeking, 0.7 open. Width, height, radii and
  shadow all follow `isExpanded` and `isPeeking` under one spring each (`.animation(_:value:)` on the
  container; where both change at once the open/collapse spring wins), so the shape grows out of the notch.
- Outline (`NotchShape`, quadratic curves): the top corners curve inward (ears), the sides are inset by the
  top radius, the bottom corners round outward. Top radius 6 pt closed, 19 pt open; bottom radius 14 pt
  closed, 24 pt open. Both are in `animatableData`, and clamped to fit the pill's 8 pt (4 and 4).
- Content: the strip enters as offset y −12 + opacity, `easeOut(0.22)` after 0.08 s, and leaves as y −6,
  `easeIn(0.12)`; the header enters as y −8, `easeOut(0.2)` after 0.12 s, and leaves as y −4, `easeIn(0.1)`
  (asymmetric transitions, each with its own animation). Reduce Motion: a plain fade.
- **The window never resizes.** Each screen's panel is one fixed frame for its whole life: the open panel
  plus 24 pt (`NotchGeometry.windowRoom`) to each side and below, flush with the top of the screen. A window
  that followed the shape was resized a run-loop turn after the state changed, so the shape grew inside
  the old, smaller window and was clipped (shadow too), then the window jumped. 24 pt covers the open
  spring's overshoot (~2%, 11 pt on 560) and the 6 pt shadow blur.
- **Click-through is transparency plus hit-testing.** The panel is non-opaque with a clear background, so
  its fully transparent pixels pass clicks to the window below (the menu bar); the hosting view's
  `hitTest(_:)` also returns nil outside the active rect: the collapsed shape while idle, the peek while
  peeking, the open panel while open (`NotchShelfViewModel.activeRect`).
- **Hover is an `NSTrackingArea`** (`.activeAlways`, `.mouseEnteredAndExited`) whose rect is that active rect,
  rebuilt when the state changes (one turn late is invisible, unlike a window), and after each rebuild the
  pointer is compared with the view model's belief (`NSEvent.mouseLocation`; AppKit sends no enter or exit
  for a pointer a new area already contains or misses) and enter/exit sent if they differ. No global
  `NSEvent` monitor, so no Accessibility permission. The active rect's edge being the peek's means the peek
  doesn't flicker at the notch's edge.
- Level `.statusBar` (above the menu bar), `canJoinAllSpaces`, `stationary`, `fullScreenAuxiliary`,
  `ignoresCycle`; never key or main, never activates Reco, no window shadow (the view draws its own). One panel per screen, rebuilt on
  `didChangeScreenParametersNotification`.
- The screenshots are read when the pointer starts resting, not on a timer. `reload()` draws the pictures
  not cached yet side by side (`LibraryStore.thumbnail`, a task group) before publishing items and pictures
  together, so by the end of the 300 ms delay the tiles have their pictures instead of popping from grey
  as the strip enters (the tile's own `.task` stays as a fallback). The previous items and pictures stay
  until a read finishes, so a second opening never starts empty; those of screenshots no longer shown are let go.
- Timings live in the view model with an injectable sleep (as `RecordingCountdown`).

## Files

| File | Role |
|---|---|
| `NotchShelf/Model/NotchGeometry.swift` | Pure: notch or pill, peek and open rects, and the one fixed window |
| `NotchShelf/Model/NotchMotion.swift` | Every spring, delay, radius, shadow and transition |
| `NotchShelf/ViewModel/NotchShelfViewModel.swift` | Peek, open and close with delays, screenshots, thumbnails, copy and its confirmation |
| `NotchShelf/View/NotchShelfController.swift` | Fixed panel per screen, `hitTest` and the tracking rect that follow the state, hide/restore |
| `NotchShelf/View/NotchShelfView.swift`, `NotchShape.swift` | The strip and tiles; the outline |
| `Model/SettingsStore+ScreenshotHistory.swift`, `View/SettingsView.swift` | `showsScreenshotsInNotch` and its toggle |
| `AppDelegate.swift` | Owns the controller; hides it in `onWillCapture`, restores it in `onDidCapture` |

## Unverified

Built and unit tested only; the app wasn't run on a notched Mac. Still to check by hand: hover while Reco
isn't the active app (an `.activeAlways` tracking area is documented to deliver enter/exit then, but a
nonactivating panel's first click and SwiftUI's `onHover` in it were not seen), the panel above the
notch and in full-screen Spaces, more than one display, a click and a drag on the same tile
(`onTapGesture` + `onDrag`), the look of the ears, and that the springs feel like notchi's (matched by number, never side by side).

Not yet: other contents (recordings, files), a keyboard way in, a size or position preference.
