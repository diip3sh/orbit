# Release Process

How this fork (`diip3sh/reco`, formerly `diip3sh/Reco`) ships. Upstream's process (a
hand-published GitHub Release, Developer ID signing, notarization, the Homebrew tap) doesn't apply
here: its `release.yml` and `prerelease.yml` workflows stay in the repository for merges from
upstream, and only run when a release is published by hand.

## What a push does

Every push to `main` that touches the app is released automatically by
`.github/workflows/fork-release.yml`. It:

1. Runs the tests. A failing test stops the release.
2. Builds a universal (Intel and Apple silicon) app, signed with the Apple Development certificate.
3. Packs it into a DMG and signs the DMG with the Sparkle key.
4. Publishes a GitHub Release with the DMG and `appcast.xml`, Sparkle's update feed.

Installed copies read that feed (`SUFeedURL` in `Info.plist`) and offer the new version.

- A push releases when it changes `Reco/**`, `Reco.xcodeproj/**`,
  `dist/update_appcast.py` or the workflow itself. Docs-only and website-only pushes don't.
- **Actions → Fork Release → Run workflow** releases the current `main` by hand.
- Never commit the DMG or any build output to git; it only goes on the Release.

## Before pushing to `main`

A push to `main` reaches users as an update, so check first:

1. All tests pass locally (the `test` command in `CLAUDE.md`).
2. SwiftLint is clean on the files you touched.
3. The code compiles with **Xcode 26.6**. GitHub's `macos-26` runner has no Xcode 27, and its older
   Swift compiler can fail to infer types that Xcode 27 accepts, such as a closure returning a labeled
   tuple. Give such expressions explicit types.
4. `actionlint .github/workflows/fork-release.yml` is clean if you changed the workflow.

After pushing, watch the run. A failed run publishes nothing: fix the cause and push again.

```sh
gh run list --repo diip3sh/reco --workflow fork-release.yml -L 3
gh run watch <run id> --repo diip3sh/reco --exit-status
gh run view <run id> --repo diip3sh/reco --log-failed
```

## Versions and tags

- The version is `1.0.<commit count>`. The build number is the commit count, which is what Sparkle
  compares, so every push to `main` is newer than the last.
- Tags are `fork-<yyyy.mm.dd>-<short sha>`, so they never collide with upstream's version tags.
- The release notes are the commit subjects since the previous release. Write subjects a user can read.

## Secrets

Repository secrets, named as in upstream's `release.yml`:

| Secret | Holds |
|---|---|
| `APPLE_CERTIFICATE_BASE64` | The Apple Development certificate and private key as a base64 `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | The `.p12`'s password |
| `APPLE_TEAM_ID` | The team the certificate belongs to |
| `SPARKLE_PUBLIC_EDDSA_KEY` | Written into `Info.plist` as `SUPublicEDKey` by the workflow |
| `SPARKLE_PRIVATE_EDDSA_KEY` | Signs each DMG |

- The Sparkle private key also lives in the login keychain of the Mac that created it ("Private key
  for signing Sparkle updates"). Installed copies only accept updates signed with it, so keep a backup:
  `generate_keys -x <file>` from Sparkle's `bin` folder exports it.
- The Apple Development certificate expires after a year. Export the new one from Keychain Access
  (**File → Export Items…**) and replace the first two secrets.
- Local builds keep the placeholder Sparkle key, so `UpdaterService` never starts the updater in them.

## Installing

- The build isn't notarized. On another Mac, macOS blocks the first launch until **System Settings →
  Privacy & Security → Open Anyway** (or `xattr -dr com.apple.quarantine /Applications/Reco.app`).
  The release notes say so. Installing without that warning needs a Developer ID certificate and
  notarization.
- **The release after 2026-10-01 drops the App Sandbox** (spec 0007). Its preferences, the agent token
  and the saved web script are copied from the old container on first launch, so settings, shortcuts and
  connected agents should carry over. Check the update from the last sandboxed release by hand (settings,
  shortcuts, custom output folder, agents still Connected, no permission asked again) before relying on it.
- Reco has its own bundle ID (`com.diip3sh.Reco`), so it installs next to the official BetterCapture.
  Copies installed under the old name, BetterCapture, can't update to Reco (Sparkle needs the same
  bundle ID): they need one manual install, and macOS asks for Reco's permissions again.
- Copies installed before this workflow (up to `fork-2026.09.29-a87a5dd`) have no Sparkle key and
  can't update themselves; they need one manual install.

## Not yet verified

- No update has been installed through Sparkle yet. After the first two releases, install the older
  one and check that it offers the newer.
