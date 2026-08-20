#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
VERSION=${VERSION:-0.1.0}
ZIP_PATH=${1:-$PROJECT_DIR/Artifacts/MacGlow-$VERSION.zip}
APP_PATH=${2:-$PROJECT_DIR/Build/ReleaseDerivedData/Build/Products/Release/MacGlow.app}
DMG_PATH=${3:-}
CHECKSUM_PATH=$ZIP_PATH.sha256

[[ -d $APP_PATH ]] || {
  print -u2 "Missing app bundle: $APP_PATH"
  exit 1
}

[[ -f $ZIP_PATH && -f $CHECKSUM_PATH ]] || {
  print -u2 "Missing release archive or checksum: $ZIP_PATH"
  exit 1
}

shasum -a 256 -c "$CHECKSUM_PATH"
plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null

if [[ -n $DMG_PATH ]]; then
  [[ -f $DMG_PATH && -f $DMG_PATH.sha256 ]] || {
    print -u2 "Missing disk image or checksum: $DMG_PATH"
    exit 1
  }
  shasum -a 256 -c "$DMG_PATH.sha256"
  hdiutil verify "$DMG_PATH" >/dev/null
fi

ARCHITECTURES=$(lipo -archs "$APP_PATH/Contents/MacOS/MacGlow")
for REQUIRED_ARCHITECTURE in arm64 x86_64; do
  [[ " $ARCHITECTURES " == *" $REQUIRED_ARCHITECTURE "* ]] || {
    print -u2 "Missing architecture: $REQUIRED_ARCHITECTURE"
    exit 1
  }
done

SIGNING_INFO=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)
if [[ ${REQUIRE_SIGNED:-0} == 1 ]]; then
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  [[ $SIGNING_INFO == *"Authority=Developer ID Application:"* ]] || {
    print -u2 "The app is not signed with a Developer ID Application certificate."
    exit 1
  }
  if [[ -n $DMG_PATH ]]; then
    codesign --verify --verbose=2 "$DMG_PATH"
  fi
else
  print "Signing check: local/ad-hoc packages are allowed"
fi

if [[ ${REQUIRE_NOTARIZED:-0} == 1 ]]; then
  xcrun stapler validate "$APP_PATH"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
  if [[ -n $DMG_PATH ]]; then
    xcrun stapler validate "$DMG_PATH"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
  fi
fi

print "Architectures: $ARCHITECTURES"
print "Release verification passed"
