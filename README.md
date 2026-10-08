# Orbit

A free, open-source macOS screen recorder, screenshot tool and video editor: a free alternative
to Screen Studio and CleanShot X. Orbit records your screen together with your cursor, clicks
and keystrokes, then turns the take into a polished video with automatic zooms, a smooth cursor
and a styled background. It lives in the menu bar.

Orbit is a fork of [BetterCapture](https://github.com/jsattler/BetterCapture), built with
ScreenCaptureKit, AVFoundation and SwiftUI.

## Install

Requires **macOS 15.2 or later**, on Apple silicon or Intel.

Orbit isn't notarized by Apple yet, so macOS blocks the first launch. You only do this once.

1. Download the DMG from the [latest release](https://github.com/diip3sh/orbit/releases/latest)
   and open it.
2. Drag **Orbit** onto **Applications**.
3. Open Orbit from Applications. macOS says it can't verify the app: click **Done**, not
   *Move to Trash*.
4. Open **System Settings → Privacy & Security**, scroll down to **Security**, and click
   **Open Anyway** next to *"Orbit" was blocked*. Enter your password, then click
   **Open Anyway** again.
5. Orbit appears in the menu bar. Allow **Screen Recording** when asked, then quit and reopen it.
   Microphone and camera ask when you first turn them on.

Prefer Terminal? After step 2, run this instead of steps 3–4:

```sh
xattr -dr com.apple.quarantine /Applications/Orbit.app && open /Applications/Orbit.app
```

Updates arrive automatically through the app's built-in updater
(**Settings → General → Check for Updates…**).

## Features

### Working now

- **Screen recording:** a screen, a window or an area, with system audio, microphone and camera,
  a 3/5/10 s countdown, and pause/resume. HEVC, H.264 or ProRes, HDR and alpha.
- **Capture toolbar:** one floating bar for screenshots and recordings, with window thumbnails to
  pick from, a live timer, pause and stop.
- **Screenshots:** capture a screen, window or area, with the screen frozen while you select.
  Each shot opens a Quick Access card: copy, save, recognize text (OCR), pin it on screen, or
  drag it into any app.
- **Screenshot history:** every shot is kept for a week, a month or three months, and the newest
  ones open from the notch.
- **Input telemetry (optional):** cursor positions, clicks, scrolls, keystrokes (key codes only,
  never typed text) and cursor shapes, saved next to each recording.
- **Video editor:** trim, split and cut, and set volume per audio track. Automatic zooms on
  clicks, typing and where the cursor rests, plus manual zooms on their own lane. The recorded
  cursor is redrawn smoothed, sharp when zoomed, and can hide when idle. Click highlights and a
  keystroke overlay. Undo and redo throughout.
- **Canvas and export:** 16:9, 9:16, 1:1 and 4:3 canvases, gradient, colour, picture or
  transparent backgrounds, padding, rounded corners and shadow. Export HEVC, H.264, ProRes 422
  or ProRes 4444 (keeps transparency) at the size and frame rate you pick, then share.
- **Web recordings:** script hovers, clicks, typing, scrolling and zooms on a live web page,
  preview it, and render a frame-perfect video into the editor.
- **AI agents:** Claude Code, Codex, Cursor, Gemini CLI, OpenCode and others can inspect,
  browse and record web pages through Orbit's local MCP server, or chat with you about the page
  from the Web Recording window.
- **Library:** every recording, export and screenshot, grouped by date, with search.

### In progress

- Audio: switching microphones mid-recording, input gain and level meters.
- Remembering the last selected window or area between recordings.
- Web recordings: spotlight, captions, narration, browser frame, speed changes and 9:16 output.
- Editor: motion blur, click sounds, voice enhancement, transcripts and captions (SRT/VTT),
  removing silences, speed per part, blur and pixelate masks, crop, GIF export.
- Screenshots: annotation, backgrounds, scrolling capture.
- Camera as its own editable track.

## Keyboard shortcuts

### Global

These work from any app and can be changed in **Settings → Shortcuts**.

| Action | Shortcut |
|---|---|
| Capture area / window / screen | ⌘1 / ⌘2 / ⌘3 |
| Select recording content / area | ⌘4 / ⌘5 |
| Start/stop recording | ⌘6 |
| Pause/resume recording | ⌘7 |
| Open screenshot / recording toolbar | ⇧⌘1 / ⇧⌘2 |
| Cancel the countdown | Esc |

### Capture toolbar

| Action | Key |
|---|---|
| Screen / window / area | 1 / 2 / 3 |
| System audio / microphone / camera | A / M / C |
| Capture or record | ↩ |
| Settings | ⌘, |
| Close | Esc |

### Quick Access card

| Action | Shortcut |
|---|---|
| Copy | ⌘C |
| Save | ⌘S |

### Video editor

| Action | Shortcut |
|---|---|
| Play/pause | Space |
| Previous/next frame | ← / → |
| Split at the playhead | S |
| Add a zoom | Z |
| Delete the selection | ⌫ |
| Undo / redo | ⌘Z / ⇧⌘Z |

### Automation

| URL | Action |
|---|---|
| `reco://toggle` | Start or stop recording, without a countdown |
| `reco://toggle-copy` | The same, and copy the file when it is saved |
| `reco://pause` | Pause or resume |
| `reco://cancel` | Stop recording and throw the take away |
| `reco://restart` | Throw the take away and record the same selection again, without a countdown |
| `reco://capture-area`, `capture-previous-area`, `capture-window`, `capture-screen` | Take a screenshot; add `?then=copy`, `save` or `pin` to do that instead of opening its card |
| `reco://edit-last` | Open the last recording in the editor |

## Development & contribution

Open `Reco.xcodeproj` in Xcode 26. Sign local builds with your own Apple Development
certificate: an ad-hoc signed build makes macOS ask for Screen Recording again after every
rebuild.

```sh
xcodebuild -scheme Reco -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bc-build/dd \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" build
```

Replace `build` with `test` to run the test suite. Every push to `main` is built, tested and
released to users, so read [docs/RELEASE.md](docs/RELEASE.md) first.

Contributions are welcome:

- **Bugs:** [open an issue](https://github.com/diip3sh/orbit/issues) with steps to reproduce,
  your macOS version and your Mac.
- **Features:** [start a discussion](https://github.com/diip3sh/orbit/discussions) before
  opening a pull request.
- **Pull requests:** branch from `main`, follow [AGENTS.md](AGENTS.md), add tests for new logic,
  and keep SwiftLint clean.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details and [CLAUDE.md](CLAUDE.md) for the
architecture and build notes.

## License

[MIT](LICENSE). Orbit builds on BetterCapture by Joshua Sattler and its contributors.
