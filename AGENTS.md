# MacGlow contributor guidance

- Build a native macOS application with public Apple APIs only.
- The minimum supported system is macOS 14.2 because system-audio capture uses
  CoreAudio Process Taps.
- Audio analysis must remain on-device. Never persist raw audio samples.
- Keep the signal-processing layer independent from AppKit so it remains easy
  to test.
- Avoid private frameworks and behavior that attempts to bypass the macOS
  secure desktop.
- Run `swift test` before handing off code changes.
