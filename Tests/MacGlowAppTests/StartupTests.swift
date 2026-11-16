import Foundation
import XCTest
@testable import MacGlowApp

final class StartupTests: XCTestCase {
    func testOnlyOneInstanceCanHoldTheLockAndExitReleasesIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("instance.lock")

        var first = try SingleInstanceLock.acquire(at: url)
        XCTAssertNotNil(first)
        XCTAssertNil(try SingleInstanceLock.acquire(at: url))
        withExtendedLifetime(first) {}
        first = nil

        // A leftover file after exit or a crash must not prevent the next launch.
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let next = try SingleInstanceLock.acquire(at: url)
        XCTAssertNotNil(next)
        withExtendedLifetime(next) {}
    }

    func testLockFileErrorsAreNotTreatedAsAnotherRunningInstance() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("instance.lock")
        XCTAssertThrowsError(try SingleInstanceLock.acquire(at: url))
    }

    @MainActor
    func testReapplyingMusicModeDoesNotRequestAnotherCaptureSession() throws {
        let suite = "MacGlowStartupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = GlowSettings(userDefaults: defaults)
        var modes: [GlowAnimationMode] = []
        settings.onAnimationModeChange = { modes.append($0) }

        settings.animationMode = .musicReactive
        XCTAssertTrue(modes.isEmpty)
        settings.animationMode = .steady
        settings.animationMode = .steady
        settings.animationMode = .musicReactive
        XCTAssertEqual(modes, [.steady, .musicReactive])
    }
}
