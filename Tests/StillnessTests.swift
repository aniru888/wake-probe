import XCTest
@testable import WakeProbe

final class StillnessTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func at(_ min: Double) -> Date { t0.addingTimeInterval(min * 60) }

    func testEmptyIsZero() {
        XCTAssertEqual(Stillness.longestStationary([], from: at(0), to: at(30)), 0)
    }
    func testSingleStationaryRunsToEnd() {
        let s = [ActivitySample(start: at(5), stationary: true)]
        XCTAssertEqual(Stillness.longestStationary(s, from: at(0), to: at(30)), 25 * 60, accuracy: 0.001)
    }
    func testWalkingBreaksStretch() {
        let s = [ActivitySample(start: at(0), stationary: true),
                 ActivitySample(start: at(4), stationary: false),
                 ActivitySample(start: at(6), stationary: true)]
        XCTAssertEqual(Stillness.longestStationary(s, from: at(0), to: at(13)), 7 * 60, accuracy: 0.001)
    }
    func testConsecutiveStationaryMerge() {
        let s = [ActivitySample(start: at(0), stationary: true),
                 ActivitySample(start: at(3), stationary: true)]
        XCTAssertEqual(Stillness.longestStationary(s, from: at(0), to: at(10)), 10 * 60, accuracy: 0.001)
    }
    func testClipsToWindow() {
        let s = [ActivitySample(start: at(-60), stationary: true)]
        XCTAssertEqual(Stillness.longestStationary(s, from: at(0), to: at(8)), 8 * 60, accuracy: 0.001)
    }
}
