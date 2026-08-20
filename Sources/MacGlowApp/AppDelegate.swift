import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let anyInputEventType = CGEventType(rawValue: UInt32.max)!
    private let musicReactiveFloor = 0.12
    private let settings = GlowSettings()
    private let displayCatalog = DisplayCatalog()
    private let permissionStatus = PermissionStatusStore()
    private let launchAtLogin = LaunchAtLoginController()
    private lazy var nowPlaying = NowPlayingController(permissionStatus: permissionStatus)
    private lazy var overlayController = GlowOverlayController(settings: settings)
    private lazy var settingsWindowController = SettingsWindowController(
        settings: settings,
        displayCatalog: displayCatalog,
        permissionStatus: permissionStatus,
        launchAtLogin: launchAtLogin,
        nowPlaying: nowPlaying,
        openSystemAudioSettings: { [weak self] in
            self?.openAudioPrivacySettings()
        },
        previewGlow: { [weak self] in
            self?.startTemporaryPreview()
        }
    )
    private var statusItem: NSStatusItem?
    private var audioStatusItem: NSMenuItem?
    private var retryMenuItem: NSMenuItem?
    private var privacyMenuItem: NSMenuItem?
    private var audioCapture: AnyObject?
    private var retryAudioWhenActive = false
    private var previewTimer: Timer?
    private var previewPhase: Double = 0
    private var temporaryPreviewTimer: Timer?
    private var temporaryPreviewPhase: Double = 0
    private var temporaryPreviewEndDate = Date.distantPast
    private var isPausedForSleep = false
    private var lifecycleTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        overlayController.start()
        settings.onAnimationModeChange = { [weak self] mode in
            self?.applyAnimationMode(mode)
        }
        settings.onAudioResponseChange = { [weak self] response in
            self?.updateAudioResponse(response)
        }
        settings.onLifecycleChange = { [weak self] _ in
            self?.evaluateLifecyclePolicy()
        }
        settings.onMetadataChange = { [weak self] metadata in
            self?.nowPlaying.configure(metadata)
        }
        nowPlaying.onPalette = { [weak self] palette in
            guard self?.settings.useArtworkColors == true else { return }
            self?.settings.applyArtworkPalette(palette)
        }
        observeWorkspaceLifecycle()
        startLifecycleMonitoring()
        nowPlaying.configure(settings.metadata)
        applyAnimationMode(settings.animationMode)
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopTemporaryPreview()
        previewTimer?.invalidate()
        settings.onAnimationModeChange = nil
        settings.onAudioResponseChange = nil
        settings.onLifecycleChange = nil
        settings.onMetadataChange = nil
        nowPlaying.onPalette = nil
        nowPlaying.stop()
        lifecycleTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        stopSystemAudioCapture()
        overlayController.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        launchAtLogin.refresh()
        nowPlaying.configure(settings.metadata)
        if retryAudioWhenActive {
            retryAudioWhenActive = false
            retryAudioCapture()
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "◈"
        item.button?.toolTip = "MacGlow"

        let menu = NSMenu()
        let audioStatusItem = NSMenuItem(
            title: "Audio: Starting…",
            action: nil,
            keyEquivalent: ""
        )
        audioStatusItem.isEnabled = false
        menu.addItem(audioStatusItem)
        self.audioStatusItem = audioStatusItem

        let retryItem = NSMenuItem(
            title: "Retry Audio Capture",
            action: #selector(retryAudioCapture),
            keyEquivalent: "r"
        )
        retryItem.isHidden = true
        menu.addItem(retryItem)
        retryMenuItem = retryItem

        let privacyItem = NSMenuItem(
            title: "Open System Audio Privacy Settings…",
            action: #selector(openAudioPrivacySettings),
            keyEquivalent: ""
        )
        privacyItem.isHidden = true
        menu.addItem(privacyItem)
        privacyMenuItem = privacyItem
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Settings…",
                action: #selector(showSettings),
                keyEquivalent: ","
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Toggle Glow",
                action: #selector(toggleGlow),
                keyEquivalent: "g"
            )
        )
        let previewItem = NSMenuItem(
            title: "Preview Glow",
            action: #selector(previewGlow),
            keyEquivalent: "p"
        )
        menu.addItem(previewItem)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit MacGlow",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func startSystemAudioCapture() {
        stopPreviewSignal()
        overlayController.update(level: musicReactiveFloor)

        guard #available(macOS 14.2, *) else {
            permissionStatus.systemAudio = .unavailable
            updateAudioStatus("Audio: Requires macOS 14.2+", failed: true)
            return
        }

        let capture = SystemAudioCapture()
        capture.updateResponse(settings.audioResponse)
        capture.onFeatures = { [weak self] features in
            Task { @MainActor in
                guard let self else { return }
                self.overlayController.update(
                    level: max(Double(features.level), self.musicReactiveFloor)
                )
            }
        }
        capture.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.handleAudioState(state)
            }
        }
        audioCapture = capture

        do {
            try capture.start()
        } catch {
            permissionStatus.systemAudio = .needsAttention
            permissionStatus.systemAudioDetail = error.localizedDescription
            updateAudioStatus("Audio unavailable — retry after permission", failed: true)
        }
    }

    private func stopSystemAudioCapture() {
        guard #available(macOS 14.2, *),
              let capture = audioCapture as? SystemAudioCapture else {
            audioCapture = nil
            return
        }
        capture.onFeatures = nil
        capture.onStateChange = nil
        capture.stop()
        audioCapture = nil
    }

    @available(macOS 14.2, *)
    private func handleAudioState(_ state: SystemAudioCaptureState) {
        switch state {
        case .stopped:
            updateAudioStatus("Audio: Stopped", failed: false)
        case .starting:
            permissionStatus.systemAudio = .checking
            permissionStatus.systemAudioDetail = "macOS is checking System Audio Recording access."
            updateAudioStatus("Audio: Starting…", failed: false)
        case .running:
            permissionStatus.systemAudio = .granted
            permissionStatus.systemAudioDetail = "System audio is analyzed on-device and never recorded."
            updateAudioStatus("Audio: System capture active", failed: false)
        case let .failed(message):
            permissionStatus.systemAudio = .needsAttention
            permissionStatus.systemAudioDetail = message
            updateAudioStatus("Audio unavailable — \(message)", failed: true)
        }
    }

    private func updateAudioStatus(_ title: String, failed: Bool) {
        audioStatusItem?.title = title
        audioStatusItem?.toolTip = title
        retryMenuItem?.isHidden = !failed
        privacyMenuItem?.isHidden = !failed
    }

    private func startPreviewSignal() {
        stopSystemAudioCapture()
        previewPhase = 0
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        updateAudioStatus(reduceMotion ? "Mode: Pulse · Reduced Motion" : "Mode: Pulse", failed: false)
        previewTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                self.previewPhase += reduceMotion ? 0.025 : 0.08
                let carrier = (sin(self.previewPhase) + 1) / 2
                let pulse = pow(carrier, 3)
                let level = reduceMotion ? 0.42 + pulse * 0.28 : 0.18 + pulse * 0.82
                self.overlayController.update(level: level)
            }
        }
    }

    private func stopPreviewSignal() {
        previewTimer?.invalidate()
        previewTimer = nil
    }

    private func startTemporaryPreview() {
        stopTemporaryPreview()
        temporaryPreviewPhase = 0
        temporaryPreviewEndDate = Date().addingTimeInterval(4)
        overlayController.setPreview(level: 0.9)

        let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard Date() < self.temporaryPreviewEndDate else {
                    self.stopTemporaryPreview()
                    return
                }
                let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                self.temporaryPreviewPhase += reduceMotion ? 0.025 : 0.08
                let carrier = (sin(self.temporaryPreviewPhase) + 1) / 2
                let pulse = pow(carrier, 3)
                let level = reduceMotion ? 0.65 + pulse * 0.2 : 0.38 + pulse * 0.62
                self.overlayController.setPreview(level: level)
            }
        }
        temporaryPreviewTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTemporaryPreview() {
        temporaryPreviewTimer?.invalidate()
        temporaryPreviewTimer = nil
        overlayController.setPreview(level: nil)
    }

    @objc private func toggleGlow() {
        overlayController.toggle()
    }

    @objc private func showSettings() {
        settingsWindowController.show()
    }

    @objc private func previewGlow() {
        startTemporaryPreview()
    }

    @objc private func retryAudioCapture() {
        settings.animationMode = .musicReactive
    }

    @objc private func openAudioPrivacySettings() {
        retryAudioWhenActive = PrivacySettings.openSystemAudioRecording()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func applyAnimationMode(_ mode: GlowAnimationMode) {
        stopPreviewSignal()
        stopSystemAudioCapture()

        guard !isPausedForSleep else {
            updateAudioStatus("Paused while Mac sleeps", failed: false)
            return
        }

        switch mode {
        case .musicReactive:
            startSystemAudioCapture()
        case .steady:
            overlayController.update(level: 0.72)
            updateAudioStatus("Mode: Steady", failed: false)
        case .pulse:
            startPreviewSignal()
        }
    }

    private func updateAudioResponse(_ response: AudioResponseSettings) {
        guard #available(macOS 14.2, *),
              let capture = audioCapture as? SystemAudioCapture else { return }
        capture.updateResponse(response)
    }

    private func observeWorkspaceLifecycle() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(workspaceWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    private func startLifecycleMonitoring() {
        lifecycleTimer?.invalidate()
        lifecycleTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.evaluateLifecyclePolicy()
            }
        }
        evaluateLifecyclePolicy()
    }

    private func evaluateLifecyclePolicy() {
        guard !isPausedForSleep else {
            overlayController.setLifecycleSuppressed(true)
            return
        }

        let policy = settings.lifecycle
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: Self.anyInputEventType
        )
        let isIdle = policy.hideWhenIdle
            && idleSeconds.isFinite
            && idleSeconds >= policy.idleDelay
        let isFullScreen = policy.hideInFullScreen && frontmostApplicationIsFullScreen()
        overlayController.setLifecycleSuppressed(isIdle || isFullScreen)
    }

    private func frontmostApplicationIsFullScreen() -> Bool {
        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              frontmostPID != ProcessInfo.processInfo.processIdentifier,
              let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[String: Any]] else {
            return false
        }

        let screenSizes = NSScreen.screens.map(\.frame.size)
        return windowInfo.contains { info in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == frontmostPID,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let boundsDictionary = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary) else {
                return false
            }
            return screenSizes.contains { size in
                abs(bounds.width - size.width) < 4 && abs(bounds.height - size.height) < 4
            }
        }
    }

    @objc private func workspaceWillSleep() {
        isPausedForSleep = true
        stopTemporaryPreview()
        overlayController.setLifecycleSuppressed(true)
        stopPreviewSignal()
        stopSystemAudioCapture()
        updateAudioStatus("Paused while Mac sleeps", failed: false)
    }

    @objc private func workspaceDidWake() {
        guard isPausedForSleep else { return }
        isPausedForSleep = false
        applyAnimationMode(settings.animationMode)
        evaluateLifecyclePolicy()
    }

    @objc private func accessibilityDisplayOptionsDidChange() {
        guard settings.animationMode == .pulse else { return }
        applyAnimationMode(.pulse)
    }
}
