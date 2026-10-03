# 0010 — Library, Reco's main window

Status: built 2026-10-02 (`feat/ui-polish`). Replaces the Recordings window (spec 0003, phase 6).

## Why

The menu bar popover closes as soon as it loses focus, so there was no place to come back to: no way to
see recordings, web recordings and screenshots together, or to manage them. The Library is that place,
a normal window that stays open, reached from **Library…** in the menu bar or by clicking Reco in the Dock.

## What

- Sidebar: All, Recordings, Web Recordings, Exports, Screenshots, each with a count.
- Grid of pictures, newest first; search by name. A click opens a movie in the editor and a screenshot in
  the system's viewer (Preview).
- Context menu: Open, Show in Finder, Copy (a screenshot as PNG data, a movie as its file), Move to Trash
  (with a recording's telemetry and editor project).
- **New**: Capture Area / Window / Screen, Record Area…, Record Window or Display…, New Web Recording…,
  Record with AI Agent…: the same entry points as the menu bar.
- New files show while the window is open (a folder watcher), and the folders are read again whenever it
  comes forward, since Settings can change them.

## Rules

- Recordings folder: movies only; `-edited` is an export, `Reco_Web_` a web recording, anything else a
  screen recording. Screenshot folder: only `Reco_Screenshot_*.png`, as it's the Desktop by default.
- The same folder for both is read once, so nothing is listed twice.

Not yet: multiple selection, rename, drag-out from tiles, the movie's length on its tile.
