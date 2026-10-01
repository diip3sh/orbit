# Manual Smoke Testing Strategy

This document outlines the manual testing matrix for Reco. These tests focus on hardware interactions, visual verification, and edge cases that are difficult to automate.

## Test Matrix

| #   | Test Case                           | Content Source                        | Video Codec | Audio Config       | HDR/Alpha     | Expected Result                                     | Notes                              |
| --- | ----------------------------------- | ------------------------------------- | ----------- | ------------------ | ------------- | --------------------------------------------------- | ---------------------------------- |
| 1   | Basic display recording             | Full display (built-in)               | H.264       | System audio only  | SDR           | MOV/MP4 file with system audio, no errors           | Baseline test                      |
| 2   | Window capture with movement        | Single window (move during recording) | HEVC        | No audio           | SDR           | Window stays in frame, smooth tracking              | Test content filter                |
| 3   | Application group recording         | Application group                     | ProRes 422  | System + Mic mix   | SDR           | Only the selected app's windows visible, other apps absent, wallpaper and Dock present, both audio tracks present | Test app scoping and multi-audio   |
| 4   | Alpha channel transparency          | Single window (transparent areas)     | ProRes 4444 | No audio           | Alpha enabled | Transparent areas preserved in output               | Requires MOV                       |
| 5   | HDR color accuracy                  | Full display (HDR content)            | ProRes 422  | No audio           | HDR enabled   | 10-bit output with correct color space              | Visual verification                |
| 6   | External display capture            | Full display (external)               | H.264       | System audio only  | SDR           | External display captured correctly                 | Test multi-monitor                 |
| 7   | Area selection recording            | Custom area selection                 | HEVC        | System audio only  | SDR           | Only selected area captured                         | Test area selection UI             |
| 8   | Microphone-only recording           | Full display                          | H.264       | Mic only           | SDR           | Only microphone track present                       | Test audio routing                 |
| 9   | Long duration recording             | Full display                          | H.264       | No audio           | SDR           | Recording > 1 hour completes without errors         | Test stability                     |
| 10  | Display disconnect during recording | Full display (external)               | H.264       | System audio only  | SDR           | Recording stops gracefully, file saved              | Unplug display mid-recording       |
| 11  | System sleep during recording       | Full display                          | H.264       | System audio only  | SDR           | Recording stops/resumes or saves gracefully         | Test power management              |
| 12  | Content picker during recording     | Full display → Window                 | HEVC        | System audio only  | SDR           | Can change content source while recording           | Update picker mid-recording        |
| 13  | Presenter overlay recording         | Full display                          | H.264       | System + Mic mix   | SDR           | Camera overlay appears, no timing glitches          | Test CameraSession                 |
| 14  | High frame rate recording           | Single window                         | HEVC        | No audio           | SDR           | 60 FPS output with smooth playback                  | Test frame rate setting            |
| 15  | Native frame rate recording         | Full display (120Hz display)          | HEVC        | No audio           | SDR           | Constant 60 fps output, `mediainfo` reports CFR     | Test native FPS                    |
| 16  | Content filter toggles              | Full display                          | H.264       | No audio           | SDR           | Cursor/wallpaper/dock hidden as configured          | Test all filter options            |
| 17  | PCM audio recording                 | Full display                          | H.264       | System audio (PCM) | SDR           | Uncompressed audio track, MOV container             | Test lossless audio                |
| 18  | Permission recovery                 | Full display                          | H.264       | System + Mic mix   | SDR           | Denying then granting permissions works             | Test permission flow               |
| 19  | Minimum area selection              | Custom area (24pt minimum)            | H.264       | No audio           | SDR           | Small area captured, no errors                      | Test boundary conditions           |
| 20  | User stops sharing (system UI)      | Full display                          | H.264       | System audio only  | SDR           | Recording stops gracefully, file saved              | Click system "Stop Sharing" button |
| 21  | Disconnected display still selected | Full display (external, unplugged)    | H.264       | System audio only  | SDR           | Start refused with notice, selection cleared        | Unplug display before recording    |
| 22  | Application capture on black        | Application group                     | H.264       | No audio           | SDR           | App windows on a black background, no wallpaper, no Dock, no other apps | Show Wallpaper and Show Dock both off |
| 23  | Window capture hears other apps     | Single window (app A)                 | H.264       | System audio only  | SDR           | App B's audio is in the recording                   | Play audio in app B throughout     |
| 24  | Application capture hears other apps | Application group (app A)            | H.264       | System audio only  | SDR           | App B's audio is in the recording                   | Play audio in app B throughout     |
| 25  | Window shadow toggle                | Single window (floating on desktop)   | H.264       | No audio           | SDR           | Drop shadow absent when the toggle is off, present when on | Test `showWindowShadows`     |
| 26  | Editor export presets               | Any recording, opened in the editor   | Each export format | As recorded | SDR           | Every export plays in QuickTime at the chosen size and frame rate | Export sheet: Format, Size, Frame Rate |
| 27  | Editor canvas                       | Any recording, opened in the editor   | HEVC export | As recorded        | SDR           | Each aspect ratio, background, padding, corner and shadow setting looks the same in the preview and the export | A background picture still shows after relaunch |
| 28  | Editor transparent background       | Any recording, opened in the editor   | ProRes 4444 export | No audio    | Alpha (canvas) | The padding is transparent over another clip in an editing app; other formats export it black | Canvas background: Transparent |
| 29  | Editor HDR export                   | Full display (HDR content), HEVC and ProRes 422 | HEVC, ProRes 422, H.264 exports | No audio | HDR enabled | HEVC and ProRes exports stay HDR (`ffprobe -show_entries stream=color_transfer` reports `smpte2084`); H.264 is SDR | Overlays at SDR brightness |
| 30  | Recordings window                   | Output folder with recordings and exports | Any     | Any                | Any           | Newest first, no `-edited` exports, pictures load, a click opens the editor, a new recording shows when the window comes forward | Menu bar: Recordings… |

## Test Coverage Summary

### Content Sources (3 types)

- **Full Display**: Tests 1, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 20, 21
- **Single Window**: Tests 2, 14, 23, 25
- **Application Group**: Tests 3, 22, 24
- **Custom Area**: Tests 7, 19

### Video Codecs (4 types)

- **H.264**: Tests 1, 6, 8, 9, 10, 11, 13, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25
- **HEVC (H.265)**: Tests 2, 7, 12, 14, 15
- **ProRes 422**: Tests 3, 5
- **ProRes 4444**: Test 4

### Audio Configurations (4 types)

- **System Audio Only**: Tests 1, 6, 7, 10, 11, 12, 17, 20, 21, 23, 24
- **Microphone Only**: Test 8
- **System + Microphone Mix**: Tests 3, 13, 18
- **No Audio**: Tests 2, 4, 5, 9, 14, 15, 16, 19, 22, 25

### Special Features

- **HDR Recording**: Test 5
- **Alpha Channel**: Test 4
- **Presenter Overlay**: Test 13
- **PCM Audio**: Test 17
- **High/Native Frame Rates**: Tests 14, 15
- **Content Filters**: Tests 16, 22, 25
- **Editor Canvas and Export**: Tests 26–30
- **Area Selection**: Tests 7, 19
- **Content-Independent System Audio**: Tests 23, 24

### Edge Cases

- **Long Duration**: Test 9
- **Display Disconnect**: Tests 10, 21
- **System Sleep**: Test 11
- **Live Content Change**: Test 12
- **Permission Flow**: Test 18
- **Minimum Size**: Test 19
- **User Stop Sharing**: Test 20

## Testing Notes

### Prerequisites

- macOS 15.2 or later
- Screen Recording permission granted
- Microphone permission granted (for audio tests)
- Built-in and external display (for multi-monitor tests)
- HDR-capable display (for HDR test)
- Test content with transparent windows (for alpha test)
- HDR video content (for color verification)

### Test Execution Guidelines

1. Run tests in order to catch regressions early
2. Verify output files play correctly in QuickTime Player
3. Check file properties match expected codec/container
4. Use QuickTime Inspector (⌘I) to verify:
   - Video codec and resolution
   - Audio tracks and codec
   - Frame rate
   - Color profile (for HDR)
   - Alpha channel presence
5. Delete test files between runs to avoid confusion
6. Document any failures with console logs and system details

### Known Limitations

- HDR recording requires HEVC, ProRes 422, or ProRes 4444 (H.264 does not support HDR)
- Alpha channel requires HEVC or ProRes 4444 with MOV container
- PCM audio requires MOV container
- MP4 container supports H.264/HEVC only, no alpha
- Area selection requires minimum 24pt size
- Native frame rate follows the display but is capped at 60 fps
- Application capture renders at display size, showing only the selected app's windows over the
  wallpaper and Dock. Turning off both Show Wallpaper and Show Dock gives the app on black.
- Window and application captures record system audio through a second, full-display stream, so
  audio is never scoped to the selected content
