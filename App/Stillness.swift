import Foundation

struct ActivitySample: Equatable {
    let start: Date
    let stationary: Bool
}

enum Stillness {
    static func longestStationary(_ samples: [ActivitySample], from: Date, to: Date) -> TimeInterval {
        let sorted = samples.sorted { $0.start < $1.start }
        var best: TimeInterval = 0
        var runStart: Date? = nil
        for (i, s) in sorted.enumerated() {
            let segStart = max(s.start, from)
            let segEnd = min(i + 1 < sorted.count ? sorted[i + 1].start : to, to)
            guard segEnd > segStart else {
                if !s.stationary { runStart = nil }
                continue
            }
            if s.stationary {
                if runStart == nil { runStart = segStart }
                best = max(best, segEnd.timeIntervalSince(runStart!))
            } else {
                runStart = nil
            }
        }
        return best
    }
}
