# Roadmap

## Phase 0 — foundation

- [x] Swift package and test harness
- [x] Menu-bar development executable
- [x] Multi-display click-through overlay
- [x] Audio frame analysis and smoothing
- [x] Architecture, privacy, security, and contribution documentation

## Phase 1 — functional MVP

- [x] CoreAudio Process Tap adapter for macOS 14.2+
- [x] Initial permission/error state in the menu bar
- [x] Privacy settings shortcuts and automatic retry on return
- [x] Rich permission-state detection and recovery guidance
- [x] Metal-based edge renderer with AppKit fallback
- [x] Persistent per-edge color, width, and intensity controls
- [x] Audio response and smoothing controls
- [x] Per-display enablement
- [x] Notch-aware top-edge rendering
- [x] Music-reactive, steady, and pulse animation modes
- [x] Idle/full-screen lifecycle handling
- [x] Sleep/wake lifecycle handling
- [x] Reduced-motion behavior

## Phase 2 — music experience

- [x] Optional Music metadata adapter
- [x] Optional Spotify metadata adapter
- [x] On-device album-art color extraction
- [x] Built-in visual and response presets
- [x] Preset import/export
- [x] Launch at login with `SMAppService`

## Phase 3 — release engineering

- [x] Xcode app project, Info.plist, and hardened-runtime entitlements
- [x] Developer-team signing configuration and credential-free template
- [ ] Execute Developer ID signing and notarization (requires maintainer
      certificate and Apple notarization credentials; automation is complete)
- [x] Documented manual-update strategy
- [x] Reproducible release workflow and SHA-256 generation
- [x] CPU benchmark harness and GPU/memory/energy budgets

## Research track

- [x] Validate which lock-screen-adjacent experiences are possible with public
      APIs; do not ship behavior that bypasses the secure desktop
- [x] Evaluate and document Intel support boundaries
