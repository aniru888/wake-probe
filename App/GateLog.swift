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

    let fileURL: URL
    private let queue = DispatchQueue(label: "gatelog")
    private let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
    private let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()

    init(fileURL: URL) { self.fileURL = fileURL }

    func record(_ gate: String, _ event: String, _ detail: [String: String] = [:]) {
        let entry = Entry(time: Date(), gate: gate, event: event, detail: detail)
        queue.sync {
            guard var line = try? encoder.encode(entry) else { return }
            line.append(0x0A)
            if FileManager.default.fileExists(atPath: fileURL.path),
               let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(line)
                try? handle.close()
            } else {
                try? line.write(to: fileURL)
            }
        }
    }

    func entries() -> [Entry] {
        queue.sync {
            guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
            return text.split(separator: "\n").compactMap { try? decoder.decode(Entry.self, from: Data($0.utf8)) }
        }
    }
}
