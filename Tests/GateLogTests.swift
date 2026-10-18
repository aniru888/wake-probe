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

    func testTimestampsKeepMilliseconds() throws {
        let e = GateLog.Entry(time: Date(timeIntervalSince1970: 1000.25), gate: "G1", event: "x", detail: [:])
        let back = try GateLog.decodeLine(try GateLog.encodeLine(e))
        XCTAssertEqual(back.time.timeIntervalSince1970, 1000.25, accuracy: 0.001)
        XCTAssertEqual(back, GateLog.Entry(time: back.time, gate: "G1", event: "x", detail: [:]))
    }

    func testTwoRecordsBothSurvive() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("two-\(UUID()).jsonl")
        let log = GateLog(fileURL: url)
        log.record("G1", "a")
        log.record("G1", "b")
        XCTAssertEqual(log.entries().map(\.event), ["a", "b"])
        XCTAssertEqual(log.failedWrites, 0)
    }

    func testFailedWriteIsCountedAndLeavesNoFile() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID())")
        let url = dir.appendingPathComponent("log.jsonl")
        let log = GateLog(fileURL: url)
        log.record("G1", "a")
        XCTAssertEqual(log.failedWrites, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
