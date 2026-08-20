import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController {
    private let settings: GlowSettings
    private let displayCatalog: DisplayCatalog
    private let permissionStatus: PermissionStatusStore
    private let launchAtLogin: LaunchAtLoginController
    private let nowPlaying: NowPlayingController
    private let openSystemAudioSettings: () -> Void
    private var window: NSWindow?

    init(
        settings: GlowSettings,
        displayCatalog: DisplayCatalog,
        permissionStatus: PermissionStatusStore,
        launchAtLogin: LaunchAtLoginController,
        nowPlaying: NowPlayingController,
        openSystemAudioSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.displayCatalog = displayCatalog
        self.permissionStatus = permissionStatus
        self.launchAtLogin = launchAtLogin
        self.nowPlaying = nowPlaying
        self.openSystemAudioSettings = openSystemAudioSettings
    }

    func show() {
        launchAtLogin.refresh()
        let window = window ?? makeWindow()
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(
            rootView: SettingsView(
                settings: settings,
                displayCatalog: displayCatalog,
                permissionStatus: permissionStatus,
                launchAtLogin: launchAtLogin,
                nowPlaying: nowPlaying,
                openSystemAudioSettings: openSystemAudioSettings,
                importPreset: { [weak self] in self?.importPreset() },
                exportPreset: { [weak self] in self?.exportPreset() }
            )
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "MacGlow Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 500, height: 650))
        return window
    }

    private func importPreset() {
        let panel = NSOpenPanel()
        panel.title = "Import MacGlow Preset"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try settings.importPresetData(Data(contentsOf: url))
        } catch {
            present(error)
        }
    }

    private func exportPreset() {
        let panel = NSSavePanel()
        panel.title = "Export MacGlow Preset"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MacGlow-Preset.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try settings.exportPresetData().write(to: url, options: .atomic)
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        let alert = NSAlert(error: error)
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
