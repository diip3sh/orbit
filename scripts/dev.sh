#!/bin/zsh
# Dev loop: rebuild and relaunch Reco whenever a source file changes.
# Usage: scripts/dev.sh   (TEAM=<id> to override the signing team)
cd "${0:A:h}/.." || exit 1
TEAM=${TEAM:-6TF45WCU3B}
APP=/tmp/bc-build/dd/Build/Products/Debug/Reco.app
# `:A` resolves /tmp to /private/tmp, which is what `ps` reports, so the two compare equal
BIN=${APP}/Contents/MacOS/Reco
BIN=${BIN:A}

# macOS pins an ad-hoc signature to its cdhash, which changes on every build, so Screen Recording is
# dropped on the next launch and asked for again forever. Never launch one: a build made without the
# settings below (a plain `xcodebuild`, or Xcode's own DerivedData) is ad-hoc.
signed_with_a_team() {
  local team
  team=$(codesign -dv "$APP" 2>&1 | awk -F= '/^TeamIdentifier/{print $2}')
  if [[ -z "$team" || "$team" == "not set" ]]; then
    echo "✗ $APP is ad-hoc signed — macOS would forget Screen Recording."
    echo "  Rebuild with DEVELOPMENT_TEAM=$TEAM CODE_SIGN_IDENTITY=\"Apple Development\"."
    return 1
  fi
}

# A Reco launched from another build (Xcode's own DerivedData) is a different app to macOS and takes
# the permission with it: name it, rather than leaving it running unseen.
# The local is `running`, not `path`: in zsh `path` is tied to `PATH`, and `local path` would empty it.
# `/private` is stripped from both sides: `open` reports /private/tmp, a direct launch reports /tmp.
report_running() {
  local pid running
  pid=$(pgrep -x Reco | head -1)
  [[ -z "$pid" ]] && return 0
  running=$(ps -o command= -p "$pid")
  [[ "${running#/private}" != "${BIN#/private}" ]] && echo "⚠ Reco is running from another build: $running"
  return 0
}

# `open` on the freshly built bundle fails now and then with -600 (procNotFound) and leaves nothing
# running, so try again before falling back to the executable itself.
launch() {
  local attempt
  for attempt in 1 2 3; do
    open "$APP"
    sleep 1
    pgrep -x Reco >/dev/null && return 0
    echo "… open failed (attempt $attempt), retrying"
  done
  echo "⚠ launching the executable directly"
  "$BIN" >/dev/null 2>&1 &
  sleep 1
  pgrep -x Reco >/dev/null
}

run() {
  if ! xcodebuild -scheme Reco -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath /tmp/bc-build/dd \
    CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=$TEAM \
    CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" build -quiet; then
    echo "✗ build failed $(date +%T)"
    return
  fi
  signed_with_a_team || return
  pkill -x Reco
  # Wait for it to actually go: `open` on a bundle whose previous instance is still terminating fails
  local waited=0
  while pgrep -x Reco >/dev/null && (( waited < 50 )); do
    sleep 0.1
    (( waited++ ))
  done
  launch || { echo "✗ could not launch $(date +%T)"; return }
  report_running
  echo "✓ relaunched $(date +%T)"
}

run
# -o: one event per batch; -l 1: coalesce saves within 1 s
fswatch -o -l 1 -e '.*' -i '\.swift$' -i '\.xcassets/' -i '\.plist$' -i '\.entitlements$' Reco |
  while read -r; do run; done
