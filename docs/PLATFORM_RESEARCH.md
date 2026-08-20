# Platform boundaries

MacGlow uses public AppKit, CoreAudio Process Tap, Metal, Apple Events, and
ServiceManagement APIs. It does not attempt to render on the macOS secure
desktop, login window, or FileVault unlock screen. Those surfaces are owned by
the system; bypassing that boundary is explicitly out of scope.

The source has no Apple-silicon-only code and generic Xcode archives use the
standard macOS architectures. Apple silicon is the primary tested platform.
Intel Macs running macOS 14.2 or later are best-effort until CI or contributor
hardware provides performance results; the AppKit fallback remains available
when Metal setup fails.
