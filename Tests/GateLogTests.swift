import XCTest
@testable import WakeProbe

final class GateLogTests: XCTestCase {
    func testRecordAppendsReadableLines() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("log-\(UUID()).jsonl")
        let log = GateLog(fileURL: url)
        log.record("G1", "scheduled", ["at": "07:00"])
        log.record("G1", "result", ["rang": "yes"])
        let entries = log.entries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].gate, "G1")
        XCTAssertEqual(entries[1].detail["rang"], "yes")
        let raw = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(raw.split(separator: "\n").count, 2)
    }

    func testEntriesOnMissingFileIsEmpty() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("none-\(UUID()).jsonl")
        XCTAssertEqual(GateLog(fileURL: url).entries(), [])
    }
}
