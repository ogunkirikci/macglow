# Update strategy

MacGlow uses a transparent manual-update strategy until the project has a
stable signing identity and release feed. Releases contain one ZIP and one
SHA-256 file. Users compare `shasum -a 256 MacGlow-<version>.zip` with the
published checksum before replacing the application.

This avoids adding a networked updater or telemetry to the pre-alpha app. A
future Sparkle integration must use an EdDSA-signed appcast, preserve manual
downloads, and document every network request.
