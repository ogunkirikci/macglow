import AppKit

// Login items and session restoration can both launch MacGlow. Acquire the
// lock before constructing the delegate or starting anything that needs access.
do {
    let support = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    ).appendingPathComponent("MacGlow", isDirectory: true)
    try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    guard let instanceLock = try SingleInstanceLock.acquire(
        at: support.appendingPathComponent("instance.lock")
    ) else {
        exit(EXIT_SUCCESS)
    }

    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    withExtendedLifetime((instanceLock, delegate)) {
        application.run()
    }
} catch {
    NSLog("MacGlow could not acquire its instance lock: %@", error.localizedDescription)
    exit(EXIT_FAILURE)
}
