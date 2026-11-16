# MacGlow

MacGlow is an open-source, native macOS ambient-lighting app. It renders a
click-through, Metal-accelerated glow around each enabled display and reacts to
system audio entirely on-device.

The development preview includes per-display and notch-aware rendering,
music-reactive/steady/pulse modes, response controls, presets with JSON
import/export, optional Music and Spotify metadata, on-device album-art color
extraction, launch at login, and sleep/idle/full-screen lifecycle handling.

## Principles

- Public Apple APIs only
- No microphone access
- No storage or transmission of raw audio
- No analytics or tracking in the default build
- Accessible controls and reduced-motion support
- Predictable CPU/GPU and battery usage

## Requirements

- Apple silicon Mac (primary) or an Intel Mac for best-effort support
- macOS 14.2 or newer for the planned CoreAudio Process Tap integration
- Swift 6.1+
- Xcode 26+ recommended

## Run the development preview

```sh
swift run MacGlowApp
```

The app appears in the menu bar as `◈`. The glow is click-through and can be
toggled from the menu. On first launch, macOS may request System Audio Recording
access. Because this Swift Package executable is not yet a signed app bundle,
permission behavior can vary during development; release packaging is tracked
on the roadmap.

For the real app bundle, open `MacGlow.xcodeproj` in Xcode and run the shared
`MacGlow` scheme. Command-line builds can use:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacGlow.xcodeproj -scheme MacGlow \
  -configuration Debug -derivedDataPath Build/DerivedData build
```

## Repeated System Audio Recording prompts

Install MacGlow in `/Applications` and launch that copy rather than the copy
on the mounted DMG. Keep a single MacGlow entry in System Settings → General →
Login Items. MacGlow also takes a per-user instance lock before starting audio
capture so concurrent launches cannot create two capture sessions.

If permission is requested again after every login, report your macOS version,
MacGlow version, installation location, and whether Launch at Login is enabled
in [issue #2](https://github.com/ogunkirikci/macglow/issues/2). Check MacGlow in
System Settings → Privacy & Security → Screen & System Audio Recording (the
label varies by macOS version). Steady and Pulse modes do not need system audio.

Unsigned/ad-hoc prereleases may have unreliable permission persistence,
especially when replacing or rebuilding the app. A stable Developer ID signing
identity is needed for consistent identity across updates; see
[Apple’s explanation of privacy permissions and designated requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
The startup guards address duplicate capture attempts; a reboot on an affected
Mac is still needed to verify the reported permission loop.

## Test

```sh
swift test
```

## Build, benchmark, and release

Run `./scripts/benchmark.sh` for the release-mode audio benchmark. Run
`VERSION=0.1.0 ./scripts/release.sh` to create a universal drag-to-Applications
DMG, app ZIP, and SHA-256 files. Developer ID and notarization setup is documented in
[docs/RELEASING.md](docs/RELEASING.md); the manual update policy and performance
budgets live in [docs/UPDATES.md](docs/UPDATES.md) and
[docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## Current status

MacGlow is feature-complete for the planned pre-alpha scope. Public distribution
still requires a maintainer-owned Apple Developer ID certificate and
notarization credentials. See [the roadmap](docs/ROADMAP.md).

## License

MacGlow is available under the MIT License. See [LICENSE](LICENSE).
