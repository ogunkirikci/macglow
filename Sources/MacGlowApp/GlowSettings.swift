import AppKit
import Combine
import MacGlowCore

enum GlowAnimationMode: String, CaseIterable, Identifiable {
    case musicReactive
    case steady
    case pulse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .musicReactive: "Music Reactive"
        case .steady: "Steady"
        case .pulse: "Pulse"
        }
    }
}

enum GlowPreset: String, CaseIterable, Identifiable {
    case neon
    case aurora
    case sunset
    case ocean

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

enum MetadataSource: String, CaseIterable, Identifiable, Sendable {
    case disabled
    case music
    case spotify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled: "Off"
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }
}

struct GlowAppearance {
    var intensity: Double
    var spread: Double
    var notchCompatibility: Bool
    var topColor: NSColor
    var rightColor: NSColor
    var bottomColor: NSColor
    var leftColor: NSColor
}

struct AudioResponseSettings: Sendable {
    var attack: Float
    var release: Float
    var gain: Float
}

struct GlowLifecycleSettings: Sendable {
    var hideWhenIdle: Bool
    var idleDelay: TimeInterval
    var hideInFullScreen: Bool
}

struct MetadataSettings: Sendable {
    var source: MetadataSource
    var useArtworkColors: Bool
}

@MainActor
final class GlowSettings: ObservableObject {
    enum PresetFileError: LocalizedError {
        case unsupportedVersion(Int)
        case invalidColor

        var errorDescription: String? {
            switch self {
            case let .unsupportedVersion(version):
                "This preset uses unsupported format version \(version)."
            case .invalidColor:
                "The preset contains an invalid color value."
            }
        }
    }
    private enum Key {
        static let intensity = "glow.intensity"
        static let spread = "glow.spread"
        static let notchCompatibility = "glow.notchCompatibility"
        static let animationMode = "glow.animationMode"
        static let disabledDisplayIDs = "glow.disabledDisplayIDs"
        static let audioAttack = "audio.attack"
        static let audioRelease = "audio.release"
        static let audioGain = "audio.gain"
        static let hideWhenIdle = "lifecycle.hideWhenIdle"
        static let idleDelay = "lifecycle.idleDelay"
        static let hideInFullScreen = "lifecycle.hideInFullScreen"
        static let metadataSource = "metadata.source"
        static let useArtworkColors = "metadata.useArtworkColors"
        static let topColor = "glow.color.top"
        static let rightColor = "glow.color.right"
        static let bottomColor = "glow.color.bottom"
        static let leftColor = "glow.color.left"
    }

    private enum Defaults {
        static let intensity = 0.8
        static let spread = 64.0
        static let notchCompatibility = true
        static let animationMode = GlowAnimationMode.musicReactive
        static let audioAttack = 0.55
        static let audioRelease = 0.12
        static let audioGain = 3.2
        static let hideWhenIdle = true
        static let idleDelay = 300.0
        static let hideInFullScreen = false
        static let metadataSource = MetadataSource.disabled
        static let useArtworkColors = true
        static let topColor = NSColor(srgbRed: 0.02, green: 0.38, blue: 1, alpha: 1)
        static let rightColor = NSColor(srgbRed: 0.48, green: 0.12, blue: 1, alpha: 1)
        static let bottomColor = NSColor(srgbRed: 1, green: 0.04, blue: 0.13, alpha: 1)
        static let leftColor = NSColor(srgbRed: 1, green: 0.02, blue: 0.36, alpha: 1)
    }

    @Published var intensity: Double {
        didSet { save(intensity, forKey: Key.intensity) }
    }

    @Published var spread: Double {
        didSet { save(spread, forKey: Key.spread) }
    }

    @Published var notchCompatibility: Bool {
        didSet { save(notchCompatibility, forKey: Key.notchCompatibility) }
    }

    @Published var animationMode: GlowAnimationMode {
        didSet {
            userDefaults.set(animationMode.rawValue, forKey: Key.animationMode)
            onAnimationModeChange?(animationMode)
        }
    }

    @Published private(set) var disabledDisplayIDs: Set<UInt32> {
        didSet {
            userDefaults.set(disabledDisplayIDs.map(String.init).sorted(), forKey: Key.disabledDisplayIDs)
            onDisplaySelectionChange?()
        }
    }

    @Published var audioAttack: Double {
        didSet { saveAudioResponse(audioAttack, forKey: Key.audioAttack) }
    }

    @Published var audioRelease: Double {
        didSet { saveAudioResponse(audioRelease, forKey: Key.audioRelease) }
    }

    @Published var audioGain: Double {
        didSet { saveAudioResponse(audioGain, forKey: Key.audioGain) }
    }

    @Published var hideWhenIdle: Bool {
        didSet { saveLifecycle(hideWhenIdle, forKey: Key.hideWhenIdle) }
    }

    @Published var idleDelay: Double {
        didSet { saveLifecycle(idleDelay, forKey: Key.idleDelay) }
    }

    @Published var hideInFullScreen: Bool {
        didSet { saveLifecycle(hideInFullScreen, forKey: Key.hideInFullScreen) }
    }

    @Published var metadataSource: MetadataSource {
        didSet {
            userDefaults.set(metadataSource.rawValue, forKey: Key.metadataSource)
            onMetadataChange?(metadata)
        }
    }

    @Published var useArtworkColors: Bool {
        didSet {
            userDefaults.set(useArtworkColors, forKey: Key.useArtworkColors)
            onMetadataChange?(metadata)
        }
    }

    @Published var topColor: NSColor {
        didSet { save(topColor, forKey: Key.topColor) }
    }

    @Published var rightColor: NSColor {
        didSet { save(rightColor, forKey: Key.rightColor) }
    }

    @Published var bottomColor: NSColor {
        didSet { save(bottomColor, forKey: Key.bottomColor) }
    }

    @Published var leftColor: NSColor {
        didSet { save(leftColor, forKey: Key.leftColor) }
    }

    var onChange: ((GlowAppearance) -> Void)?
    var onAnimationModeChange: ((GlowAnimationMode) -> Void)?
    var onDisplaySelectionChange: (() -> Void)?
    var onAudioResponseChange: ((AudioResponseSettings) -> Void)?
    var onLifecycleChange: ((GlowLifecycleSettings) -> Void)?
    var onMetadataChange: ((MetadataSettings) -> Void)?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        intensity = Self.number(forKey: Key.intensity, in: userDefaults) ?? Defaults.intensity
        spread = Self.number(forKey: Key.spread, in: userDefaults) ?? Defaults.spread
        notchCompatibility = Self.bool(forKey: Key.notchCompatibility, in: userDefaults) ?? Defaults.notchCompatibility
        animationMode = userDefaults.string(forKey: Key.animationMode)
            .flatMap(GlowAnimationMode.init(rawValue:)) ?? Defaults.animationMode
        disabledDisplayIDs = Set(
            (userDefaults.stringArray(forKey: Key.disabledDisplayIDs) ?? []).compactMap(UInt32.init)
        )
        audioAttack = Self.number(forKey: Key.audioAttack, in: userDefaults) ?? Defaults.audioAttack
        audioRelease = Self.number(forKey: Key.audioRelease, in: userDefaults) ?? Defaults.audioRelease
        audioGain = Self.number(forKey: Key.audioGain, in: userDefaults) ?? Defaults.audioGain
        hideWhenIdle = Self.bool(forKey: Key.hideWhenIdle, in: userDefaults) ?? Defaults.hideWhenIdle
        idleDelay = Self.number(forKey: Key.idleDelay, in: userDefaults) ?? Defaults.idleDelay
        hideInFullScreen = Self.bool(forKey: Key.hideInFullScreen, in: userDefaults) ?? Defaults.hideInFullScreen
        metadataSource = userDefaults.string(forKey: Key.metadataSource)
            .flatMap(MetadataSource.init(rawValue:)) ?? Defaults.metadataSource
        useArtworkColors = Self.bool(forKey: Key.useArtworkColors, in: userDefaults) ?? Defaults.useArtworkColors
        topColor = Self.color(forKey: Key.topColor, in: userDefaults) ?? Defaults.topColor
        rightColor = Self.color(forKey: Key.rightColor, in: userDefaults) ?? Defaults.rightColor
        bottomColor = Self.color(forKey: Key.bottomColor, in: userDefaults) ?? Defaults.bottomColor
        leftColor = Self.color(forKey: Key.leftColor, in: userDefaults) ?? Defaults.leftColor
    }

    var appearance: GlowAppearance {
        GlowAppearance(
            intensity: intensity,
            spread: spread,
            notchCompatibility: notchCompatibility,
            topColor: topColor,
            rightColor: rightColor,
            bottomColor: bottomColor,
            leftColor: leftColor
        )
    }

    var audioResponse: AudioResponseSettings {
        AudioResponseSettings(
            attack: Float(audioAttack),
            release: Float(audioRelease),
            gain: Float(audioGain)
        )
    }

    var lifecycle: GlowLifecycleSettings {
        GlowLifecycleSettings(
            hideWhenIdle: hideWhenIdle,
            idleDelay: idleDelay,
            hideInFullScreen: hideInFullScreen
        )
    }

    var metadata: MetadataSettings {
        MetadataSettings(source: metadataSource, useArtworkColors: useArtworkColors)
    }

    func restoreDefaults() {
        intensity = Defaults.intensity
        spread = Defaults.spread
        notchCompatibility = Defaults.notchCompatibility
        animationMode = Defaults.animationMode
        disabledDisplayIDs = []
        audioAttack = Defaults.audioAttack
        audioRelease = Defaults.audioRelease
        audioGain = Defaults.audioGain
        hideWhenIdle = Defaults.hideWhenIdle
        idleDelay = Defaults.idleDelay
        hideInFullScreen = Defaults.hideInFullScreen
        metadataSource = Defaults.metadataSource
        useArtworkColors = Defaults.useArtworkColors
        topColor = Defaults.topColor
        rightColor = Defaults.rightColor
        bottomColor = Defaults.bottomColor
        leftColor = Defaults.leftColor
    }

    func isDisplayEnabled(_ displayID: UInt32) -> Bool {
        !disabledDisplayIDs.contains(displayID)
    }

    func setDisplay(_ displayID: UInt32, enabled: Bool) {
        if enabled {
            disabledDisplayIDs.remove(displayID)
        } else {
            disabledDisplayIDs.insert(displayID)
        }
    }

    func applyPreset(_ preset: GlowPreset) {
        switch preset {
        case .neon:
            intensity = 0.8
            spread = 64
            topColor = NSColor(srgbRed: 0.02, green: 0.38, blue: 1, alpha: 1)
            rightColor = NSColor(srgbRed: 0.48, green: 0.12, blue: 1, alpha: 1)
            bottomColor = NSColor(srgbRed: 1, green: 0.04, blue: 0.13, alpha: 1)
            leftColor = NSColor(srgbRed: 1, green: 0.02, blue: 0.36, alpha: 1)
            audioAttack = 0.55
            audioRelease = 0.12
            audioGain = 3.2
        case .aurora:
            intensity = 0.72
            spread = 82
            topColor = NSColor(srgbRed: 0.02, green: 0.92, blue: 0.72, alpha: 1)
            rightColor = NSColor(srgbRed: 0.16, green: 0.48, blue: 1, alpha: 1)
            bottomColor = NSColor(srgbRed: 0.50, green: 0.18, blue: 1, alpha: 1)
            leftColor = NSColor(srgbRed: 0.04, green: 0.76, blue: 0.94, alpha: 1)
            audioAttack = 0.46
            audioRelease = 0.08
            audioGain = 3.6
        case .sunset:
            intensity = 0.76
            spread = 74
            topColor = NSColor(srgbRed: 1, green: 0.58, blue: 0.08, alpha: 1)
            rightColor = NSColor(srgbRed: 1, green: 0.20, blue: 0.10, alpha: 1)
            bottomColor = NSColor(srgbRed: 0.88, green: 0.04, blue: 0.34, alpha: 1)
            leftColor = NSColor(srgbRed: 1, green: 0.18, blue: 0.56, alpha: 1)
            audioAttack = 0.58
            audioRelease = 0.10
            audioGain = 3.4
        case .ocean:
            intensity = 0.68
            spread = 92
            topColor = NSColor(srgbRed: 0.02, green: 0.70, blue: 1, alpha: 1)
            rightColor = NSColor(srgbRed: 0.03, green: 0.28, blue: 0.92, alpha: 1)
            bottomColor = NSColor(srgbRed: 0.02, green: 0.16, blue: 0.62, alpha: 1)
            leftColor = NSColor(srgbRed: 0.00, green: 0.88, blue: 0.86, alpha: 1)
            audioAttack = 0.40
            audioRelease = 0.07
            audioGain = 3.8
        }
    }

    func exportPresetData(named name: String = "Custom") throws -> Data {
        let preset = GlowPresetFile(
            name: name,
            animationMode: animationMode.rawValue,
            intensity: intensity,
            spread: spread,
            notchCompatibility: notchCompatibility,
            topColor: topColor.hexRGB,
            rightColor: rightColor.hexRGB,
            bottomColor: bottomColor.hexRGB,
            leftColor: leftColor.hexRGB,
            audioAttack: audioAttack,
            audioRelease: audioRelease,
            audioGain: audioGain
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(preset)
    }

    func importPresetData(_ data: Data) throws {
        let preset = try JSONDecoder().decode(GlowPresetFile.self, from: data)
        guard preset.formatVersion == GlowPresetFile.currentFormatVersion else {
            throw PresetFileError.unsupportedVersion(preset.formatVersion)
        }
        guard let top = NSColor(hexRGB: preset.topColor),
              let right = NSColor(hexRGB: preset.rightColor),
              let bottom = NSColor(hexRGB: preset.bottomColor),
              let left = NSColor(hexRGB: preset.leftColor) else {
            throw PresetFileError.invalidColor
        }

        animationMode = GlowAnimationMode(rawValue: preset.animationMode) ?? .musicReactive
        intensity = min(max(preset.intensity, 0.1), 1)
        spread = min(max(preset.spread, 20), 220)
        notchCompatibility = preset.notchCompatibility
        topColor = top
        rightColor = right
        bottomColor = bottom
        leftColor = left
        audioAttack = min(max(preset.audioAttack, 0.05), 1)
        audioRelease = min(max(preset.audioRelease, 0.02), 0.5)
        audioGain = min(max(preset.audioGain, 1), 8)
    }

    func applyArtworkPalette(_ palette: [MacGlowCore.RGBColor]) {
        guard !palette.isEmpty else { return }
        let colors = palette.map {
            NSColor(srgbRed: $0.red, green: $0.green, blue: $0.blue, alpha: 1)
        }
        topColor = colors[0]
        rightColor = colors[min(1, colors.count - 1)]
        bottomColor = colors[min(2, colors.count - 1)]
        leftColor = colors[min(3, colors.count - 1)]
    }

    private func save(_ value: Double, forKey key: String) {
        userDefaults.set(value, forKey: key)
        notifyChange()
    }

    private func saveAudioResponse(_ value: Double, forKey key: String) {
        userDefaults.set(value, forKey: key)
        onAudioResponseChange?(audioResponse)
    }

    private func saveLifecycle(_ value: Double, forKey key: String) {
        userDefaults.set(value, forKey: key)
        onLifecycleChange?(lifecycle)
    }

    private func saveLifecycle(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
        onLifecycleChange?(lifecycle)
    }

    private func save(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
        notifyChange()
    }

    private func save(_ color: NSColor, forKey key: String) {
        userDefaults.set(color.hexRGB, forKey: key)
        notifyChange()
    }

    private func notifyChange() {
        onChange?(appearance)
    }

    private static func number(forKey key: String, in defaults: UserDefaults) -> Double? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.double(forKey: key)
    }

    private static func bool(forKey key: String, in defaults: UserDefaults) -> Bool? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.bool(forKey: key)
    }

    private static func color(forKey key: String, in defaults: UserDefaults) -> NSColor? {
        guard let value = defaults.string(forKey: key) else { return nil }
        return NSColor(hexRGB: value)
    }
}

private extension NSColor {
    convenience init?(hexRGB: String) {
        let value = hexRGB.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else { return nil }

        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xff) / 255,
            green: CGFloat((rgb >> 8) & 0xff) / 255,
            blue: CGFloat(rgb & 0xff) / 255,
            alpha: 1
        )
    }

    var hexRGB: String {
        guard let color = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        return String(
            format: "#%02X%02X%02X",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }
}
