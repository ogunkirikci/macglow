import XCTest
@testable import MacGlowCore

final class GlowConfigurationTests: XCTestCase {
    func testConfigurationClampsUnsafeValues() {
        let configuration = GlowConfiguration(
            intensity: 4,
            thickness: -10,
            smoothing: -1
        )

        XCTAssertEqual(configuration.intensity, 1)
        XCTAssertEqual(configuration.thickness, 2)
        XCTAssertEqual(configuration.smoothing, 0)
    }
}
