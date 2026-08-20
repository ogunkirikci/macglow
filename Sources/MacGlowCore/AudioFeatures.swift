import Foundation

public struct AudioFeatures: Equatable, Sendable {
    public let rms: Float
    public let peak: Float
    public let level: Float

    public init(rms: Float, peak: Float, level: Float) {
        self.rms = rms
        self.peak = peak
        self.level = level
    }

    public static let silence = AudioFeatures(rms: 0, peak: 0, level: 0)
}
