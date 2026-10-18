import XCTest
@testable import WakeProbe

final class SmokeTests: XCTestCase {
    func testMetadataEncodes() throws {
        let data = try JSONEncoder().encode(ProbeMetadata())
        XCTAssertFalse(data.isEmpty)
    }
}
