import XCTest
@testable import MacGlowCore

final class AudioFrameAnalyzerTests: XCTestCase {
    func testSilenceProducesZeroFromFreshAnalyzer() {
        var analyzer = AudioFrameAnalyzer()

        let features = analyzer.analyze(Array(repeating: Float.zero, count: 128))

        XCTAssertEqual(features.rms, 0, accuracy: 0.000_001)
        XCTAssertEqual(features.peak, 0, accuracy: 0.000_001)
        XCTAssertEqual(features.level, 0, accuracy: 0.000_001)
    }

    func testRMSAndPeakAreCalculated() {
        var analyzer = AudioFrameAnalyzer(attack: 1, release: 1, noiseFloor: 0, gain: 1)

        let features = analyzer.analyze([Float(1), -1, 0, 0])

        XCTAssertEqual(features.rms, sqrt(0.5), accuracy: 0.000_001)
        XCTAssertEqual(features.peak, 1, accuracy: 0.000_001)
        XCTAssertEqual(features.level, sqrt(0.5), accuracy: 0.000_001)
    }

    func testReleaseDecaysInsteadOfDroppingImmediately() {
        var analyzer = AudioFrameAnalyzer(attack: 1, release: 0.25, noiseFloor: 0, gain: 1)
        _ = analyzer.analyze(Array(repeating: Float(1), count: 16))

        let released = analyzer.analyze(Array(repeating: Float.zero, count: 16))

        XCTAssertEqual(released.level, 0.75, accuracy: 0.000_001)
    }

    func testInputAndOutputAreClamped() {
        var analyzer = AudioFrameAnalyzer(attack: 1, release: 1, noiseFloor: 0, gain: 10)

        let features = analyzer.analyze([Float(4), -4])

        XCTAssertEqual(features.rms, 1, accuracy: 0.000_001)
        XCTAssertEqual(features.peak, 1, accuracy: 0.000_001)
        XCTAssertEqual(features.level, 1, accuracy: 0.000_001)
    }

    func testPrecomputedStatisticsFollowSameSmoothingPath() {
        var analyzer = AudioFrameAnalyzer(attack: 0.5, release: 0.25, noiseFloor: 0, gain: 1)

        let features = analyzer.analyze(rms: 0.8, peak: 0.9)

        XCTAssertEqual(features.rms, 0.8, accuracy: 0.000_001)
        XCTAssertEqual(features.peak, 0.9, accuracy: 0.000_001)
        XCTAssertEqual(features.level, 0.4, accuracy: 0.000_001)
    }
}
