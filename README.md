# Reco

A free, open-source macOS screen recorder and screenshot tool, forked from
[BetterCapture](https://github.com/jsattler/BetterCapture).

## Features

- **Screen recording:** record a screen, window or area, with system audio and microphone
  controls, a countdown, and pause/resume.
- **Capture toolbar:** floating controls, keyboard shortcuts, window thumbnails and
  a live recording timer.
- **Screenshots:** capture a screen, window or area; copy, save, recognize text or pin
  the result. Screenshot history and the notch shelf keep recent captures handy.
- **Video editor:** trim and cut recordings, add automatic or manual zooms, smooth the
  recorded cursor, highlight clicks, show keystrokes and adjust audio.
- **Canvas and export:** backgrounds, aspect ratios, padding, rounded corners and shadows;
  export HEVC, H.264 or ProRes, including transparent backgrounds with ProRes 4444.
- **Web recordings:** script hovers, clicks, typing and scrolling on a live page, preview
  the sequence, then render it into a recording.
- **AI agent integration:** compatible coding agents can inspect and record web pages
  through Reco's MCP bridge. The Web Recording window also includes an agent chat.
- **Library:** browse recordings and screenshots, then open recordings in the editor.

The editor and Web Recording window follow macOS light/dark appearance and your system
accent colour. Settings stay in the right-hand inspector. Timelines use labelled time
units, and sliders show tick marks and their current values.

## Install

Requires **macOS 15.2 or later**. Release builds support Apple silicon and Intel Macs.

1. Download the DMG from the [latest release](https://github.com/diip3sh/reco/releases/latest).
2. Move Reco to Applications.
3. The build is signed but **not notarized**. If macOS blocks the first launch, open
   **System Settings → Privacy & Security → Open Anyway**.

Subsequent releases are delivered through the app's updater.

## Getting started

Open Reco from Applications, then use its menu bar icon:

- **Take Screenshot…** or **Record Screen…** opens the capture toolbar.
- **Library…** opens saved recordings and screenshots.
- **New Web Recording…** opens the web scripting editor.
- **Settings…** configures capture, output folders, shortcuts and agents.

Grant Screen Recording permission when requested. Microphone recording needs microphone
permission. Input telemetry is optional and off by default; click, scroll and keystroke
capture may also require Input Monitoring or Accessibility permission.

Telemetry stores key codes and modifiers, not typed characters. The editor shows only
shortcuts and special keys unless **Show All Keys** is enabled.

### Default shortcuts

These shortcuts are global and can be changed in Settings → Shortcuts.

| Action | Shortcut |
|---|---|
| Capture area / window / screen | ⌘1 / ⌘2 / ⌘3 |
| Select recording content / area | ⌘4 / ⌘5 |
| Toggle recording | ⌘6 |
| Pause/resume recording | ⌘7 |
| Open screenshot / recording toolbar | ⇧⌘1 / ⇧⌘2 |

In the video editor, Space plays/pauses, ←/→ steps a frame, **S** splits,
**Z** adds a zoom, and Delete removes the selection. ⌘Z undoes an edit.

## Known limitations

- macOS can draw its purple sharing indicator into window recordings. ScreenCaptureKit
  provides no setting to suppress it; whole-display capture does not trigger that window pill.
- Rendering web recordings is frame-by-frame and can take longer than playback on complex pages.
- Transparent exports require ProRes 4444. Other formats render transparent backgrounds black.

## Development

Open `Reco.xcodeproj` in Xcode. Use an Apple Development certificate for local builds;
ad-hoc signing can cause macOS to request capture permission again after rebuilding.

```sh
xcodebuild -scheme Reco -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bc-build/dd \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" build
```

Replace `build` with `test` to run the test suite. Release changes must also compile with
Xcode 26.6, the CI toolchain.

See [CLAUDE.md](CLAUDE.md) for build details, [AGENTS.md](AGENTS.md) for coding conventions,
[CONTRIBUTING.md](CONTRIBUTING.md) for contributing, and
[docs/RELEASE.md](docs/RELEASE.md) for the automatic release process.

## License

See [LICENSE](LICENSE). Reco builds on the work of BetterCapture's upstream contributors.
