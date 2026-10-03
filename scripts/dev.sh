#!/bin/zsh
# Dev loop: rebuild and relaunch Reco whenever a source file changes.
# Usage: scripts/dev.sh   (TEAM=<id> to override the signing team)
cd "${0:A:h}/.." || exit 1
TEAM=${TEAM:-6TF45WCU3B}
APP=/tmp/bc-build/dd/Build/Products/Debug/Reco.app

run() {
  xcodebuild -scheme Reco -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath /tmp/bc-build/dd \
    CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=$TEAM \
    CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" build -quiet \
    && { pkill -x Reco; open "$APP"; echo "✓ relaunched $(date +%T)"; } \
    || echo "✗ build failed $(date +%T)"
}

run
# -o: one event per batch; -l 1: coalesce saves within 1 s
fswatch -o -l 1 -e '.*' -i '\.swift$' -i '\.xcassets/' -i '\.plist$' -i '\.entitlements$' Reco |
  while read -r; do run; done
