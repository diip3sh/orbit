# Localization

Orbit follows the macOS system language. There is no in-app language picker.

| Language | Code | Resources |
|---|---|---|
| English (source, fallback) | `en` | |
| Simplified Chinese | `zh-Hans` | `Reco/Localizable.xcstrings`, `Reco/InfoPlist.xcstrings` |

A string with no translation in the current language shows its English text.

## Where strings live

- `Reco/Localizable.xcstrings`: every string the UI shows.
- `Reco/InfoPlist.xcstrings`: the permission prompts (microphone, camera, screen recording).

## Writing localizable code

- SwiftUI literals (`Text("Save")`, `Button("Save")`, `.help("…")`, `Label`, `Toggle`, …) are localized by themselves.
- A view that takes a title as a parameter declares it as `LocalizedStringKey`, so call sites pass literals.
- Text that isn't a SwiftUI literal (enum titles, error descriptions, status messages, `NSAlert` / `NSOpenPanel` / notification text) uses `String(localized: "…")`. Use `LocalizedStringResource` when it flows into a SwiftUI view.
- Put every dynamic part in the interpolation (`String(localized: "Saved to \(name)")`), never concatenate translated pieces.
- Format numbers and dates with `.formatted(...)` or a `format:` argument, never `String(format:)`.
- Files that call `String(localized:)` or take a `LocalizedStringResource` need `import Foundation` (the project enables strict member imports).

### Intentionally English

These are read by coding agents or are protocol text, not by the user, so they stay English:

- the MCP tool catalog, tool errors and render lint (`AgentBridge/Model`, `AgentBridge/Service`, `Motion/Grammar`, `Motion/Model/MotionDocumentError.swift`, `Motion/Model/UICaptureError.swift`, `MotionEditError`);
- the agent skill files (`AgentRecording/Skills`) and the prompts built from them (`AgentRecordingRequest.prompt`);
- log messages, signposts and file names.

## Adding a translation

1. Build once so Xcode adds any new strings to `Reco/Localizable.xcstrings` (or run `xcrun xcstringstool sync` on it with the build's `.stringsdata` files).
2. Open `Reco/Localizable.xcstrings` in Xcode, click **+** in the language list, and pick the language. The project's known regions (`knownRegions` in `project.pbxproj`) get the new region.
3. Translate each key. Keep every format specifier (`%@`, `%lld`) and keep their order, or use positional ones (`%1$@`, `%2$lld`). A literal percent sign is `%%`.
4. Do the same in `Reco/InfoPlist.xcstrings` for the three permission prompts.
5. Leave symbols, units, product names and shortcuts unchanged. Mark such a key **Don't translate**.
6. Run the app with the language set: launch the built app with `-AppleLanguages '(zh-Hans)'`, or choose it in System Settings → General → Language & Region.

`RecoTests/LocalizationTests.swift` checks that the bundled translations load and that a missing one falls back to English.
