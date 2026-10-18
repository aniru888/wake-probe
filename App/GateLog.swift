import Foundation

final class GateLog {
    struct Entry: Codable, Equatable {
        let time: Date
        let gate: String
        let event: String
        let detail: [String: String]
    }

    static let shared: GateLog = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return GateLog(fileURL: docs.appendingPathComponent("gatelog.jsonl"))
    }()

    private static func makeFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(makeFormatter().string(from: date))
        }
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            guard let date = makeFormatter().date(from: s) else {
                throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "Bad date \(s)"))
            }
            return date
        }
        return d
    }()

    static func encodeLine(_ e: Entry) throws -> Data { try encoder.encode(e) }
    static func decodeLine(_ d: Data) throws -> Entry { try decoder.decode(Entry.self, from: d) }

    let fileURL: URL
    private let queue = DispatchQueue(label: "gatelog")
    private(set) var failedWrites = 0

    init(fileURL: URL) { self.fileURL = fileURL }

    func record(_ gate: String, _ event: String, _ detail: [String: String] = [:]) {
        let entry = Entry(time: Date(), gate: gate, event: event, detail: detail)
        queue.sync {
            do {
                var line = try Self.encodeLine(entry)
                line.append(0x0A)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: line)
                } else {
                    try line.write(to: fileURL, options: .withoutOverwriting)
                }
            } catch {
                failedWrites += 1
            }
        }
    }

    func entries() -> [Entry] {
        queue.sync {
            guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
            return text.split(separator: "\n").compactMap { try? Self.decodeLine(Data($0.utf8)) }
        }
    }
}
