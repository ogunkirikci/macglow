import Foundation

/// Converts normalized PCM samples into a stable 0...1 value suitable for UI animation.
/// The analyzer stores only its previous scalar level; raw samples are never retained.
public struct AudioFrameAnalyzer: Sendable {
    private var smoothedLevel: Float = 0

    public var attack: Float
    public var release: Float
    public var noiseFloor: Float
    public var gain: Float

    public init(
        attack: Float = 0.55,
        release: Float = 0.12,
        noiseFloor: Float = 0.008,
        gain: Float = 3.2
    ) {
        self.attack = Self.clamp(attack)
        self.release = Self.clamp(release)
        self.noiseFloor = max(0, noiseFloor)
        self.gain = max(0, gain)
    }

    public mutating func analyze<S: Collection>(_ samples: S) -> AudioFeatures
    where S.Element == Float {
        guard !samples.isEmpty else {
            smoothedLevel += (0 - smoothedLevel) * release
            return AudioFeatures(rms: 0, peak: 0, level: smoothedLevel)
        }

        var squaredSum: Float = 0
        var peak: Float = 0

        for sample in samples {
            let magnitude = min(abs(sample), 1)
            squaredSum += magnitude * magnitude
            peak = max(peak, magnitude)
        }

        let rms = sqrt(squaredSum / Float(samples.count))
        return analyze(rms: rms, peak: peak)
    }

    /// Applies normalization and smoothing to precomputed frame statistics.
    /// This lets real-time audio adapters avoid allocating a temporary sample array.
    public mutating func analyze(rms: Float, peak: Float) -> AudioFeatures {
        let rms = Self.clamp(rms)
        let peak = Self.clamp(peak)
        let normalized = Self.clamp((rms - noiseFloor) * gain)
        let coefficient = normalized > smoothedLevel ? attack : release
        smoothedLevel += (normalized - smoothedLevel) * coefficient

        return AudioFeatures(rms: rms, peak: peak, level: Self.clamp(smoothedLevel))
    }

    public mutating func reset() {
        smoothedLevel = 0
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
