import AppKit
import Combine

enum PermissionState: Equatable {
    case checking
    case granted
    case needsAttention
    case unavailable
    case notRequested
}

@MainActor
final class PermissionStatusStore: ObservableObject {
    @Published var systemAudio: PermissionState = .checking
    @Published var systemAudioDetail: String?
    @Published var automation: PermissionState = .notRequested
    @Published var automationDetail: String?
}

enum PrivacySettings {
    private static let privacyPane = "x-apple.systempreferences:com.apple.preference.security"

    @MainActor
    static func openSystemAudioRecording() -> Bool {
        open(anchor: "Privacy_ScreenCapture")
    }

    @MainActor
    static func openAutomation() -> Bool {
        open(anchor: "Privacy_Automation")
    }

    @MainActor
    static func openPrivacyAndSecurity() -> Bool {
        guard let url = URL(string: privacyPane) else { return false }
        return NSWorkspace.shared.open(url)
    }

    @MainActor
    private static func open(anchor: String) -> Bool {
        guard let url = URL(string: "\(privacyPane)?\(anchor)") else { return false }
        if NSWorkspace.shared.open(url) {
            return true
        }
        return openPrivacyAndSecurity()
    }
}
