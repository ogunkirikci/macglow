import AppKit
import Combine

struct DisplayDescriptor: Identifiable {
    let id: UInt32
    let name: String
    let hasNotch: Bool
}

@MainActor
final class DisplayCatalog: NSObject, ObservableObject {
    @Published private(set) var displays: [DisplayDescriptor] = []

    override init() {
        super.init()
        refresh()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screensDidChange() {
        refresh()
    }

    private func refresh() {
        displays = NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            return DisplayDescriptor(
                id: id,
                name: screen.localizedName,
                hasNotch: screen.hasCameraHousing
            )
        }
    }
}

extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var hasCameraHousing: Bool {
        (auxiliaryTopLeftArea?.width ?? 0) > 0 && (auxiliaryTopRightArea?.width ?? 0) > 0
    }
}
