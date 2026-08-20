import AppKit

@MainActor
final class GlowOverlayController {
    private var panels: [NSPanel] = []
    private var isVisible = true
    private var isLifecycleSuppressed = false
    private let settings: GlowSettings

    init(settings: GlowSettings) {
        self.settings = settings
    }

    func start() {
        settings.onChange = { [weak self] appearance in
            self?.update(appearance: appearance)
        }
        settings.onDisplaySelectionChange = { [weak self] in
            self?.rebuildPanels()
        }
        rebuildPanels()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func stop() {
        settings.onChange = nil
        settings.onDisplaySelectionChange = nil
        NotificationCenter.default.removeObserver(self)
        panels.forEach { $0.close() }
        panels.removeAll()
    }

    func toggle() {
        isVisible.toggle()
        applyVisibility()
    }

    func setLifecycleSuppressed(_ suppressed: Bool) {
        guard isLifecycleSuppressed != suppressed else { return }
        isLifecycleSuppressed = suppressed
        applyVisibility()
    }

    func update(level: Double) {
        for panel in panels {
            (panel.contentView as? GlowOverlayView)?.level = min(max(level, 0), 1)
        }
    }

    private func update(appearance: GlowAppearance) {
        for panel in panels {
            (panel.contentView as? GlowOverlayView)?.glowAppearance = appearance
        }
    }

    @objc private func screensDidChange() {
        rebuildPanels()
    }

    private func rebuildPanels() {
        panels.forEach { $0.close() }
        panels = NSScreen.screens
            .filter { screen in
                guard let displayID = screen.displayID else { return true }
                return settings.isDisplayEnabled(displayID)
            }
            .map(makePanel)
        applyVisibility()
    }

    private func applyVisibility() {
        let shouldShow = isVisible && !isLifecycleSuppressed
        panels.forEach { panel in
            shouldShow ? panel.orderFrontRegardless() : panel.orderOut(nil)
        }
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.contentView = GlowOverlayView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            glowAppearance: settings.appearance,
            topGlowLayout: TopGlowLayout(screen: screen)
        )
        return panel
    }
}
