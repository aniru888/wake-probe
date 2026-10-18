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
        let marks = GateLog.shared.entries().filter { $0.gate == "G4" && $0.event == "placement-start" }
        let from = Date().addingTimeInterval(-2 * 3600)
        activity.queryActivityStarting(from: from, to: Date(), to: .main) { acts, error in
            if let error { report = "error: \(error)"; GateLog.shared.record("G4", "query-error", ["error": "\(error)"]); return }
            let samples = (acts ?? []).map { ActivitySample(start: $0.startDate, stationary: $0.stationary) }
            var lines: [String] = []
            for (i, m) in marks.enumerated() {
                let end = i + 1 < marks.count ? marks[i + 1].time : min(m.time.addingTimeInterval(600), Date())
                let longest = Stillness.longestStationary(samples, from: m.time, to: end)
                let place = m.detail["where"] ?? "?"
                lines.append("\(place): longest still \(Int(longest / 60)) min of \(Int(end.timeIntervalSince(m.time) / 60))")
                GateLog.shared.record("G4", "analysis", ["where": place, "longestStillSec": "\(Int(longest))",
                                                         "windowSec": "\(Int(end.timeIntervalSince(m.time)))"])
            }
            report = lines.joined(separator: "\n") + "\nsamples: \(samples.count)"
        }
    }
}
