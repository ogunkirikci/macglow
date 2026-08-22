import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: GlowSettings
    @ObservedObject var displayCatalog: DisplayCatalog
    @ObservedObject var permissionStatus: PermissionStatusStore
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    @ObservedObject var nowPlaying: NowPlayingController
    let openSystemAudioSettings: () -> Void
    let previewGlow: () -> Void
    let importPreset: () -> Void
    let exportPreset: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MacGlow")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Tune the ambient light around your displays.")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Glow") {
                VStack(spacing: 14) {
                    HStack {
                        Text("Preset")
                        Spacer()
                        Menu(settings.selectedPreset?.title ?? "Choose Preset") {
                            ForEach(GlowPreset.allCases) { preset in
                                Button {
                                    settings.applyPreset(preset)
                                } label: {
                                    if settings.selectedPreset == preset {
                                        Label(preset.title, systemImage: "checkmark")
                                    } else {
                                        Text(preset.title)
                                    }
                                }
                            }
                        }
                        Button("Import…", action: importPreset)
                        Button("Export…", action: exportPreset)
                    }

                    Picker("Mode", selection: $settings.animationMode) {
                        ForEach(GlowAnimationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check the current look")
                                .fontWeight(.medium)
                            Text("Shows the glow for four seconds, even when audio is silent or idle hiding is active.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        Button(action: previewGlow) {
                            Label("Preview Glow", systemImage: "sparkles")
                        }
                        .keyboardShortcut("p", modifiers: [.command])
                    }

                    settingSlider(
                        title: "Width",
                        value: $settings.spread,
                        range: 20...220,
                        valueLabel: "\(Int(settings.spread)) px"
                    )
                    settingSlider(
                        title: "Intensity",
                        value: $settings.intensity,
                        range: 0.1...1,
                        valueLabel: "\(Int(settings.intensity * 100))%"
                    )

                    Toggle("Leave the camera housing area clear", isOn: $settings.notchCompatibility)
                        .help("On MacBook displays with a notch, the top glow is drawn only on the left and right sections.")
                }
                .padding(8)
            }

            GroupBox("Displays") {
                VStack(alignment: .leading, spacing: 10) {
                    if displayCatalog.displays.isEmpty {
                        Text("No displays detected.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(displayCatalog.displays) { display in
                            Toggle(isOn: displayBinding(display.id)) {
                                HStack {
                                    Text(display.name)
                                    if display.hasNotch {
                                        Label("Notch", systemImage: "web.camera")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Music response") {
                VStack(spacing: 14) {
                    settingSlider(
                        title: "Reaction",
                        value: $settings.audioAttack,
                        range: 0.05...1,
                        valueLabel: "\(Int(settings.audioAttack * 100))%"
                    )
                    settingSlider(
                        title: "Fade",
                        value: $settings.audioRelease,
                        range: 0.02...0.5,
                        valueLabel: "\(Int(settings.audioRelease * 100))%"
                    )
                    settingSlider(
                        title: "Sensitivity",
                        value: $settings.audioGain,
                        range: 1...8,
                        valueLabel: String(format: "%.1fx", settings.audioGain)
                    )
                    Label("The macOS Reduce Motion preference is respected automatically.", systemImage: "accessibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
            }

            GroupBox("Edge colors") {
                Grid(horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow {
                        ColorPicker("Top", selection: colorBinding(\.topColor), supportsOpacity: false)
                        ColorPicker("Right", selection: colorBinding(\.rightColor), supportsOpacity: false)
                    }
                    GridRow {
                        ColorPicker("Bottom", selection: colorBinding(\.bottomColor), supportsOpacity: false)
                        ColorPicker("Left", selection: colorBinding(\.leftColor), supportsOpacity: false)
                    }
                }
                .padding(8)
            }

            GroupBox("Now Playing") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Source", selection: $settings.metadataSource) {
                        ForEach(MetadataSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Use album artwork colors", isOn: $settings.useArtworkColors)
                        .disabled(settings.metadataSource == .disabled)

                    if let track = nowPlaying.currentTrack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).fontWeight(.medium)
                            Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(nowPlaying.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }

            GroupBox("Privacy permissions") {
                VStack(alignment: .leading, spacing: 12) {
                    permissionRow(
                        title: "System Audio Recording",
                        detail: permissionStatus.systemAudioDetail
                            ?? "Required to make the glow react to audio playing on your Mac.",
                        status: permissionStatus.systemAudio,
                        buttonTitle: "Open Settings",
                        action: openSystemAudioSettings
                    )
                    Divider()
                    permissionRow(
                        title: "Automation",
                        detail: permissionStatus.automationDetail
                            ?? "Optional; used only when Music or Spotify metadata is enabled.",
                        status: permissionStatus.automation,
                        buttonTitle: "Open Settings"
                    ) {
                        _ = PrivacySettings.openAutomation()
                    }
                }
                .padding(8)
            }

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Launch MacGlow at login", isOn: launchAtLoginBinding)

                    HStack(spacing: 8) {
                        launchAtLoginBadge
                        if launchAtLogin.state == .requiresApproval {
                            Button("Open Login Items") {
                                launchAtLogin.openLoginItemsSettings()
                            }
                        }
                    }

                    if let errorMessage = launchAtLogin.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()
                    Toggle("Hide glow when Mac is idle", isOn: $settings.hideWhenIdle)
                    if settings.hideWhenIdle {
                        settingSlider(
                            title: "After",
                            value: $settings.idleDelay,
                            range: 60...1800,
                            valueLabel: "\(Int(settings.idleDelay / 60)) min"
                        )
                    }
                    Toggle("Hide glow for full-screen apps", isOn: $settings.hideInFullScreen)
                    Text("Full-screen detection uses public window bounds only; screen contents are never read.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            HStack {
                Text("Changes are saved automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Restore Defaults") {
                    settings.restoreDefaults()
                }
            }
            }
            .padding(22)
        }
        .frame(width: 500, height: 650)
    }

    private func permissionRow(
        title: String,
        detail: String,
        status: PermissionState,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            permissionBadge(for: status)
            if status != .granted {
                Button(buttonTitle, action: action)
            }
        }
    }

    @ViewBuilder
    private func permissionBadge(for status: PermissionState) -> some View {
        let presentation = permissionPresentation(for: status)
        Label(presentation.title, systemImage: presentation.icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(presentation.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(presentation.color.opacity(0.12), in: Capsule())
            .help(presentation.help)
    }

    private func permissionPresentation(
        for status: PermissionState
    ) -> (title: String, icon: String, color: Color, help: String) {
        switch status {
        case .checking:
            ("Checking", "clock", .secondary, "MacGlow is checking this permission.")
        case .granted:
            ("Granted", "checkmark.circle.fill", .green, "This permission is available.")
        case .needsAttention:
            ("Needs attention", "exclamationmark.triangle.fill", .orange, "Open System Settings to allow access.")
        case .unavailable:
            ("Unavailable", "xmark.circle.fill", .red, "This permission is unavailable on this Mac.")
        case .notRequested:
            ("Not requested", "minus.circle", .secondary, "MacGlow has not requested this optional permission.")
        }
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueLabel: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 76, alignment: .leading)
            Slider(value: value, in: range)
            Text(valueLabel)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
    }

    private func colorBinding(_ keyPath: ReferenceWritableKeyPath<GlowSettings, NSColor>) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: settings[keyPath: keyPath]) },
            set: { settings[keyPath: keyPath] = NSColor($0) }
        )
    }

    private func displayBinding(_ displayID: UInt32) -> Binding<Bool> {
        Binding(
            get: { settings.isDisplayEnabled(displayID) },
            set: { settings.setDisplay(displayID, enabled: $0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }

    @ViewBuilder
    private var launchAtLoginBadge: some View {
        switch launchAtLogin.state {
        case .disabled:
            Label("Disabled", systemImage: "minus.circle")
                .foregroundStyle(.secondary)
        case .enabled:
            Label("Enabled", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .requiresApproval:
            Label("Needs approval", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .unavailable:
            Label("Unavailable", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
