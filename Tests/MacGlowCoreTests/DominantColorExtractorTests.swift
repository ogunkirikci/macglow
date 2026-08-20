import XCTest
@testable import MacGlowCore

final class DominantColorExtractorTests: XCTestCase {
    func testPalettePrefersFrequentDistinctColors() {
        let red = RGBColor(red: 0.9, green: 0.1, blue: 0.1)
        let blue = RGBColor(red: 0.1, green: 0.2, blue: 0.9)
        let pixels = Array(repeating: red, count: 20) + Array(repeating: blue, count: 10)

        let palette = DominantColorExtractor.palette(from: pixels, count: 2)

        XCTAssertEqual(palette.count, 2)
        XCTAssertGreaterThan(palette[0].red, palette[0].blue)
        XCTAssertGreaterThan(palette[1].blue, palette[1].red)
    }

    func testPaletteIgnoresNearWhiteAndNearBlackPixels() {
        let pixels = [
            RGBColor(red: 1, green: 1, blue: 1),
            RGBColor(red: 0.01, green: 0.01, blue: 0.01),
            RGBColor(red: 0.1, green: 0.8, blue: 0.3)
        ]

        let palette = DominantColorExtractor.palette(from: pixels)

        XCTAssertEqual(palette.count, 1)
        XCTAssertGreaterThan(palette[0].green, 0.7)
    }
}
