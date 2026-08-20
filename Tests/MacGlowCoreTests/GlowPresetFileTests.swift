import XCTest
@testable import MacGlowCore

final class GlowPresetFileTests: XCTestCase {
    func testPresetRoundTripsThroughJSON() throws {
        let preset = GlowPresetFile(
            name: "Ocean",
            animationMode: "musicReactive",
            intensity: 0.68,
            spread: 92,
            notchCompatibility: true,
            topColor: "#00B2FF",
            rightColor: "#0747EB",
            bottomColor: "#03299E",
            leftColor: "#00E0DB",
            audioAttack: 0.4,
            audioRelease: 0.07,
            audioGain: 3.8
        )

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(GlowPresetFile.self, from: data)

        XCTAssertEqual(decoded, preset)
    }
}
