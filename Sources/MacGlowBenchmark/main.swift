import Foundation
import MacGlowCore

let frame = (0..<512).map { index in
    Float(sin(Double(index) * 0.08) * 0.35)
}
let iterations = 200_000
var analyzer = AudioFrameAnalyzer()
let clock = ContinuousClock()
let elapsed = clock.measure {
    for _ in 0..<iterations {
        _ = analyzer.analyze(frame)
    }
}
let seconds = Double(elapsed.components.seconds)
    + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000
let framesPerSecond = Double(iterations) / max(seconds, 0.000_001)

print("{\"iterations\":\(iterations),\"samplesPerFrame\":\(frame.count),\"seconds\":\(String(format: "%.6f", seconds)),\"framesPerSecond\":\(String(format: "%.1f", framesPerSecond))}")
