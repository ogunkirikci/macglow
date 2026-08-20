import Foundation

public struct GlowConfiguration: Codable, Equatable, Sendable {
    public enum ColorMode: String, Codable, CaseIterable, Sendable {
        case customGradient
        case albumArtwork
        case screenAverage
    }

    public var intensity: Double
    public var thickness: Double
    public var smoothing: Double
    public var colorMode: ColorMode

    public init(
        intensity: Double = 0.8,
        thickness: Double = 64,
        smoothing: Double = 0.65,
        colorMode: ColorMode = .customGradient
    ) {
        self.intensity = min(max(intensity, 0), 1)
        self.thickness = min(max(thickness, 2), 160)
        self.smoothing = min(max(smoothing, 0), 1)
        self.colorMode = colorMode
    }

    public static let `default` = GlowConfiguration()
}
