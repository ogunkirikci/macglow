#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
VERSION=${VERSION:-0.1.0}
OUTPUT_DIR=${OUTPUT_DIR:-$PROJECT_DIR/Artifacts}
DERIVED_DATA=${DERIVED_DATA:-$PROJECT_DIR/Build/ReleaseDerivedData}
APP_PATH=$DERIVED_DATA/Build/Products/Release/MacGlow.app
ZIP_PATH=$OUTPUT_DIR/MacGlow-$VERSION.zip
DMG_PATH=$OUTPUT_DIR/MacGlow-$VERSION.dmg

if [[ ${PUBLIC_RELEASE:-0} == 1 ]]; then
  [[ -n ${DEVELOPMENT_TEAM:-} && -n ${CODE_SIGN_IDENTITY:-} && -n ${NOTARY_KEYCHAIN_PROFILE:-} ]] || {
    print -u2 "Public releases require Developer ID signing and notarization."
    exit 1
  }
fi

mkdir -p "$OUTPUT_DIR"

BUILD_ARGUMENTS=(
  -project "$PROJECT_DIR/MacGlow.xcodeproj"
  -scheme MacGlow
  -configuration Release
  -destination "generic/platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
  MARKETING_VERSION="$VERSION"
)

if [[ -n ${DEVELOPMENT_TEAM:-} && -n ${CODE_SIGN_IDENTITY:-} ]]; then
  BUILD_ARGUMENTS+=(
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY"
  )
else
  BUILD_ARGUMENTS+=(CODE_SIGNING_ALLOWED=NO)
fi

/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild "${BUILD_ARGUMENTS[@]}" build

if [[ -n ${NOTARY_KEYCHAIN_PROFILE:-} ]]; then
  [[ -n ${DEVELOPMENT_TEAM:-} && -n ${CODE_SIGN_IDENTITY:-} ]] || {
    print -u2 "Notarization requires DEVELOPMENT_TEAM and CODE_SIGN_IDENTITY."
    exit 1
  }
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
fi

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
"$SCRIPT_DIR/create-dmg.sh" "$APP_PATH" "$DMG_PATH"

if [[ -n ${DEVELOPMENT_TEAM:-} && -n ${CODE_SIGN_IDENTITY:-} ]]; then
  codesign --force --timestamp --sign "$CODE_SIGN_IDENTITY" "$DMG_PATH"
fi

if [[ -n ${NOTARY_KEYCHAIN_PROFILE:-} ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
fi

shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
VERIFY_ENV=()
if [[ -n ${DEVELOPMENT_TEAM:-} && -n ${CODE_SIGN_IDENTITY:-} ]]; then
  VERIFY_ENV+=(REQUIRE_SIGNED=1)
fi
if [[ -n ${NOTARY_KEYCHAIN_PROFILE:-} ]]; then
  VERIFY_ENV+=(REQUIRE_NOTARIZED=1)
fi
env "${VERIFY_ENV[@]}" "$SCRIPT_DIR/verify-release.sh" "$ZIP_PATH" "$APP_PATH" "$DMG_PATH"
print "Created $ZIP_PATH"
print "Created $ZIP_PATH.sha256"
print "Created $DMG_PATH"
print "Created $DMG_PATH.sha256"
