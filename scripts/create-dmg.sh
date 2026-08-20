#!/bin/zsh
set -euo pipefail

APP_PATH=${1:?Usage: create-dmg.sh /path/to/MacGlow.app /path/to/MacGlow.dmg}
DMG_PATH=${2:?Usage: create-dmg.sh /path/to/MacGlow.app /path/to/MacGlow.dmg}
VOLUME_NAME=${VOLUME_NAME:-MacGlow}

[[ -d $APP_PATH ]] || {
  print -u2 "Missing app bundle: $APP_PATH"
  exit 1
}

STAGING_DIR=$(mktemp -d /private/tmp/macglow-dmg.XXXXXX)
[[ $STAGING_DIR == /private/tmp/macglow-dmg.* ]] || {
  print -u2 "Unexpected staging path: $STAGING_DIR"
  exit 1
}

cleanup() {
  rm -rf -- "$STAGING_DIR"
}
trap cleanup EXIT

ditto "$APP_PATH" "$STAGING_DIR/MacGlow.app"
ln -s /Applications "$STAGING_DIR/Applications"

mkdir -p "${DMG_PATH:h}"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

print "Created $DMG_PATH"
