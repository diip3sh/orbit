# 0012 — Screenshot history

Status: built 2026-10-03 (`feat/screenshot-history`).

## Why

A screenshot lived only in memory until **Save** on the Quick Access card; closing the card or copying
it lost the picture. Every screenshot is now kept for a while, so it can be found later in the Library,
and deleted after that so it doesn't fill the disk.

## What

- Every successful capture (area, window, screen) is written as PNG to
  `~/Library/Application Support/com.diip3sh.Reco/Screenshots/Reco_Screenshot_<capture time>.png`, in the
  background: the card doesn't wait for it. A failed write is logged, never shown.
- **Save** writes to the screenshot folder as before, then deletes the history copy. Copy, Pin,
  Recognize Text and Close leave it.
- **Settings → General → Screenshot History**: Keep Screenshots (Off, 1 Week, 1 Month, 3 Months; default
  1 Month) and Clear History… (asks first).
- The Library lists history screenshots with the saved ones, grouped under date headers.

## Rules

- Expired = older than the retention by creation date; Off expires everything and stops writing. Expired
  files are deleted (`removeItem`), never trashed: the point is to free space. One function decides it,
  `ScreenshotHistory.isExpired(created:now:retention:)`.
- Pruning runs when `ScreenshotController` is created and after each history write. It only touches
  `Reco_Screenshot_*.png` in the history folder; Clear History empties that folder. Neither touches the
  screenshot folder.
- Save waits for a history write still in flight (kept by file name) before deleting, so the copy can't
  outlive the save.
- A name in both folders (briefly, during Save) is listed once, from the screenshot folder.
- Date groups, newest first, empty ones left out: Today, Yesterday, Earlier This Week, Last Week, then a
  month each ("September 2026"). Weeks follow the calendar's first weekday.

## Files

| File | Role |
|---|---|
| `Model/ScreenshotHistoryRetention.swift`, `Model/SettingsStore+ScreenshotHistory.swift` | The setting |
| `Screenshot/Service/ScreenshotHistory.swift` | Folder, expiry rule, prune, clear, remove |
| `Screenshot/ViewModel/ScreenshotController.swift` | Writes after a capture, removes after Save, prunes at start |
| `Library/Model/LibraryDateGroup.swift` | Pure grouping by date |
| `Library/Service/LibraryStore.swift`, `Library/ViewModel/LibraryViewModel.swift`, `Library/View/LibraryView.swift` | History folder listed and watched; grid sections |
| `View/SettingsView.swift` | Settings section |

Not yet: restoring a history screenshot to the Quick Access card, a size limit, per-day clearing. A
history folder created after the Library window opened is only seen when the window next comes forward.
