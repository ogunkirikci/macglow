import Foundation

public struct GlowPresetFile: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var name: String
    public var animationMode: String
    public var intensity: Double
    public var spread: Double
    public var notchCompatibility: Bool
    public var topColor: String
    public var rightColor: String
    public var bottomColor: String
    public var leftColor: String
    public var audioAttack: Double
    public var audioRelease: Double
    public var audioGain: Double

    public init(
        formatVersion: Int = currentFormatVersion,
        name: String,
        animationMode: String,
        intensity: Double,
        spread: Double,
        notchCompatibility: Bool,
        topColor: String,
        rightColor: String,
        bottomColor: String,
        leftColor: String,
        audioAttack: Double,
        audioRelease: Double,
        audioGain: Double
    ) {
        self.formatVersion = formatVersion
        self.name = name
        self.animationMode = animationMode
        self.intensity = intensity
        self.spread = spread
        self.notchCompatibility = notchCompatibility
        self.topColor = topColor
        self.rightColor = rightColor
        self.bottomColor = bottomColor
        self.leftColor = leftColor
        self.audioAttack = audioAttack
        self.audioRelease = audioRelease
        self.audioGain = audioGain
    }
}
