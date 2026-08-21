# Releasing MacGlow

## Reproducible package

Run `VERSION=0.1.0 ./scripts/release.sh`. The script performs a Release build,
creates both `Artifacts/MacGlow-0.1.0.dmg` and
`Artifacts/MacGlow-0.1.0.zip`, and writes SHA-256 checksums beside them. The DMG
contains the app and an Applications shortcut for drag-and-drop installation.
The script then validates both archives, bundle metadata, disk-image integrity,
and the universal `arm64`/`x86_64` executable. Without signing variables this
intentionally produces local/ad-hoc packages for development verification.

## Developer ID and notarization

Export `DEVELOPMENT_TEAM` and the full `CODE_SIGN_IDENTITY` for a Developer ID
Application certificate. Store notarization credentials in Keychain with
`xcrun notarytool store-credentials`, then export `NOTARY_KEYCHAIN_PROFILE`.
The same release script signs the app, submits it for notarization, staples the
app ticket, builds and signs the DMG, notarizes and staples the DMG, regenerates
the checksums, and requires Developer ID, Gatekeeper, and stapler validation to
pass.

Existing packages can be checked independently with
`./scripts/verify-release.sh Artifacts/MacGlow-0.1.0.zip /path/to/MacGlow.app Artifacts/MacGlow-0.1.0.dmg`. Set
`REQUIRE_SIGNED=1` and `REQUIRE_NOTARIZED=1` when validating a public build.

Apple account credentials and certificates must never be committed. A release
is not considered public until `codesign --verify --deep --strict`,
`spctl --assess --type execute`, and `xcrun stapler validate` all succeed.

Pushing a `v*` tag runs the GitHub workflow and publishes the DMG, ZIP, and
checksums. The repository must define the protected Actions secrets
`APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD`,
`BUILD_KEYCHAIN_PASSWORD`, `APPLE_ID`, `APPLE_APP_PASSWORD`, and
`APPLE_TEAM_ID`. The workflow refuses to publish an unsigned or unnotarized
package. A correctly notarized DMG opens on other Macs without asking users to
remove the quarantine attribute.
