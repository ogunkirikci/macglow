import AppKit
import Combine
import MacGlowCore

struct NowPlayingTrack: Equatable {
    var title: String
    var artist: String
    var album: String
}

@MainActor
final class NowPlayingController: ObservableObject {
    @Published private(set) var currentTrack: NowPlayingTrack?
    @Published private(set) var statusText = "Metadata is off"

    var onPalette: (([MacGlowCore.RGBColor]) -> Void)?

    private let permissionStatus: PermissionStatusStore
    private var source = MetadataSource.disabled
    private var useArtworkColors = true
    private var pollTimer: Timer?
    private var artworkTask: Task<Void, Never>?
    private var lastArtworkKey = ""
    private var pendingArtworkKey = ""

    init(permissionStatus: PermissionStatusStore) {
        self.permissionStatus = permissionStatus
    }

    func configure(_ settings: MetadataSettings) {
        let artworkConfigurationChanged = source != settings.source
            || useArtworkColors != settings.useArtworkColors
        source = settings.source
        useArtworkColors = settings.useArtworkColors
        pollTimer?.invalidate()
        pollTimer = nil
        artworkTask?.cancel()
        artworkTask = nil
        pendingArtworkKey = ""
        if artworkConfigurationChanged {
            lastArtworkKey = ""
        }

        guard source != .disabled else {
            currentTrack = nil
            statusText = "Metadata is off"
            permissionStatus.automation = .notRequested
            permissionStatus.automationDetail = nil
            return
        }

        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        artworkTask?.cancel()
        artworkTask = nil
        pendingArtworkKey = ""
    }

    private func poll() {
        switch source {
        case .disabled:
            return
        case .music:
            pollMusic()
        case .spotify:
            pollSpotify()
        }
    }

    private func pollMusic() {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty else {
            currentTrack = nil
            statusText = "Music is not running"
            return
        }

        let script = """
        tell application "Music"
            if player state is stopped then return {"", "", ""}
            set currentItem to current track
            set artworkData to missing value
            try
                set artworkData to data of artwork 1 of currentItem
            end try
            return {name of currentItem, artist of currentItem, album of currentItem, artworkData}
        end tell
        """
        guard let descriptor = execute(script) else { return }
        updateTrack(from: descriptor, sourceName: "Music")

        if useArtworkColors, let data = descriptor.atIndex(4)?.data {
            processArtwork(data, key: trackKey)
        }
    }

    private func pollSpotify() {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty else {
            currentTrack = nil
            statusText = "Spotify is not running"
            return
        }

        let script = """
        tell application "Spotify"
            if player state is stopped then return {"", "", "", ""}
            set currentItem to current track
            return {name of currentItem, artist of currentItem, album of currentItem, artwork url of currentItem}
        end tell
        """
        guard let descriptor = execute(script) else { return }
        updateTrack(from: descriptor, sourceName: "Spotify")

        guard useArtworkColors,
              let urlString = descriptor.atIndex(4)?.stringValue,
              let url = URL(string: urlString),
              trackKey != lastArtworkKey,
              trackKey != pendingArtworkKey else { return }
        let key = trackKey
        pendingArtworkKey = key
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled,
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      self.source == .spotify,
                      self.useArtworkColors,
                      self.trackKey == key else {
                    if self.pendingArtworkKey == key { self.pendingArtworkKey = "" }
                    return
                }
                if self.publishPalette(from: data) {
                    self.lastArtworkKey = key
                }
                if self.pendingArtworkKey == key { self.pendingArtworkKey = "" }
            } catch {
                guard !Task.isCancelled else { return }
                if self.pendingArtworkKey == key { self.pendingArtworkKey = "" }
                self.statusText = "Track detected; artwork could not be loaded"
            }
        }
    }

    private func execute(_ source: String) -> NSAppleEventDescriptor? {
        var errorInfo: NSDictionary?
        let descriptor = NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
            permissionStatus.automation = code == -1743 || code == -1744 ? .needsAttention : .unavailable
            permissionStatus.automationDetail = code == -1743 || code == -1744
                ? "Allow MacGlow to control the selected music app in Privacy & Security → Automation."
                : (errorInfo[NSAppleScript.errorMessage] as? String ?? "The music app did not return metadata.")
            statusText = permissionStatus.automationDetail ?? "Metadata unavailable"
            return nil
        }

        permissionStatus.automation = .granted
        permissionStatus.automationDetail = "MacGlow can read the current track from the selected app."
        return descriptor
    }

    private func updateTrack(from descriptor: NSAppleEventDescriptor, sourceName: String) {
        guard let title = descriptor.atIndex(1)?.stringValue, !title.isEmpty else {
            currentTrack = nil
            statusText = "\(sourceName) is not playing"
            return
        }
        currentTrack = NowPlayingTrack(
            title: title,
            artist: descriptor.atIndex(2)?.stringValue ?? "",
            album: descriptor.atIndex(3)?.stringValue ?? ""
        )
        statusText = "Connected to \(sourceName)"
    }

    private var trackKey: String {
        guard let currentTrack else { return "" }
        return "\(source.rawValue)|\(currentTrack.title)|\(currentTrack.artist)|\(currentTrack.album)"
    }

    private func processArtwork(_ data: Data, key: String) {
        guard key != lastArtworkKey else { return }
        if publishPalette(from: data) {
            lastArtworkKey = key
        }
    }

    @discardableResult
    private func publishPalette(from data: Data) -> Bool {
        guard let image = NSImage(data: data) else { return false }
        let width = 48
        let height = 48
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return false }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        var pixels: [MacGlowCore.RGBColor] = []
        pixels.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                      color.alphaComponent > 0.25 else { continue }
                pixels.append(MacGlowCore.RGBColor(
                    red: color.redComponent,
                    green: color.greenComponent,
                    blue: color.blueComponent
                ))
            }
        }
        let palette = DominantColorExtractor.palette(from: pixels)
        if !palette.isEmpty {
            onPalette?(palette)
            return true
        }
        return false
    }
}
