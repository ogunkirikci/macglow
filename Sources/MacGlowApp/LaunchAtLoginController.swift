import Combine
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var state = LaunchAtLoginState.disabled
    @Published private(set) var errorMessage: String?

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            isEnabled = false
            state = .disabled
        case .enabled:
            isEnabled = true
            state = .enabled
        case .requiresApproval:
            isEnabled = true
            state = .requiresApproval
        case .notFound:
            isEnabled = false
            state = .unavailable
        @unknown default:
            isEnabled = false
            state = .unavailable
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
