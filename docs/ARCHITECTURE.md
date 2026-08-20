# Architecture

## Product boundary

MacGlow provides ambient display lighting that can react to audio playing on a
Mac. It does not record audio, capture the microphone, or attempt to draw over
the protected macOS login/lock-screen secure desktop.

## Components

### MacGlowCore

A UI-independent Swift module containing:

- PCM frame analysis
- attack/release smoothing
- normalized visual intensity
- persisted configuration and preset-file models
- on-device dominant-color extraction

The analyzer consumes a frame and retains only the previous scalar level. It
does not retain samples.

### MacGlowApp

An AppKit menu-bar executable containing:

- one transparent, non-activating `NSPanel` per display
- Metal click-through overlay rendering with AppKit fallback
- display-topology observation
- application lifecycle and menu commands
- optional Music and Spotify Apple Events adapters
- local preset import/export and `SMAppService` login registration

### Audio adapter

System audio will be captured through the public CoreAudio Process Tap APIs:

- `CATapDescription`
- `AudioHardwareCreateProcessTap`
- an aggregate device and IO callback

`AudioHardwareCreateProcessTap` is available from macOS 14.2. MacGlow will use
an unmuted, private global tap that excludes its own process where supported.
The permission copy must accurately describe macOS System Audio Recording
access. No raw buffers will cross the audio adapter boundary after analysis.

## Data flow

```text
CoreAudio tap -> PCM frame -> AudioFrameAnalyzer -> AudioFeatures.level
                                                   |
                                                   v
                                        Overlay renderer per screen
```

Metadata adapters for Music and Spotify are optional, disabled by default, and
isolated from generic audio reactivity. Spotify artwork URLs are fetched only
when Spotify metadata and artwork colors are both enabled.

## Explicit non-goals for MVP

- Private frameworks such as MediaRemote
- Circumventing the macOS secure desktop
- Cloud accounts, telemetry, or license checks
- Audio recording or history
- Intel support before an actual contributor/user need is established
