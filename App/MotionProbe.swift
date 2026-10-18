import SwiftUI
import CoreMotion

struct MotionGateView: View {
    @State private var report = ""
    private let activity = CMMotionActivityManager()

    var body: some View {
        Form {
            Section("Mark each placement as you start it (10 min each)") {
                ForEach(["desk", "bed", "pocket-walking"], id: \.self) { p in
                    Button("Start: \(p)") { GateLog.shared.record("G4", "placement-start", ["where": p]) }
                }
            }
            Section("Analyse") {
                Button("Analyse last 2 hours") { analyse() }
                Text(report).font(.caption.monospaced())
            }
        }
        .navigationTitle("Stillness gate G4")
    }

    private func analyse() {
        guard CMMotionActivityManager.isActivityAvailable() else { report = "activity unavailable"; return }
        let from = Date().addingTimeInterval(-2 * 3600)
        let marks = GateLog.shared.entries().filter { $0.gate == "G4" && $0.event == "placement-start" && $0.time >= from }
        activity.queryActivityStarting(from: from, to: Date(), to: .main) { acts, error in
            if let error { report = "error: \(error)"; GateLog.shared.record("G4", "query-error", ["error": "\(error)"]); return }
            let raw = (acts ?? []).sorted { $0.startDate < $1.startDate }
            let samples = raw.map { ActivitySample(start: $0.startDate, stationary: $0.stationary) }
            var lines: [String] = []
            for (i, m) in marks.enumerated() {
                let nextMark = i + 1 < marks.count ? marks[i + 1].time : Date.distantFuture
                let end = min(nextMark, m.time.addingTimeInterval(600), Date())
                let window = end.timeIntervalSince(m.time)
                let longest = Stillness.longestStationary(samples, from: m.time, to: end)
                let place = m.detail["where"] ?? "?"
                let inWindow = raw.filter { $0.startDate >= m.time && $0.startDate <= end }
                let lowConfidence = inWindow.filter { $0.confidence == .low }.count
                let unknown = inWindow.filter { $0.unknown }.count
                let inEffect = raw.last { $0.startDate <= m.time } ?? raw.first { $0.startDate >= m.time && $0.startDate <= end }
                let firstOffset = inEffect.map { "\(Int($0.startDate.timeIntervalSince(m.time)))" } ?? "none"
                let threshold: TimeInterval = 360
                let verdict: String
                if window < threshold || (inWindow.isEmpty && inEffect == nil) { verdict = "INCONCLUSIVE" }
                else if place == "pocket-walking" { verdict = longest < threshold ? "PASS" : "FAIL" }
                else { verdict = longest >= threshold ? "PASS" : "FAIL" }
                lines.append("\(place): longest still \(Int(longest))s of \(Int(window))s, \(inWindow.count) samples \u{2192} \(verdict)")
                GateLog.shared.record("G4", "analysis", ["where": place, "longestStillSec": "\(Int(longest))",
                                                         "windowSec": "\(Int(window))", "verdict": verdict,
                                                         "samples": "\(inWindow.count)", "lowConfidence": "\(lowConfidence)",
                                                         "unknown": "\(unknown)", "firstSampleOffsetSec": firstOffset])
            }
            report = lines.joined(separator: "\n") + "\nsamples: \(samples.count)"
        }
    }
}
