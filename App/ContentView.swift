import SwiftUI

struct ContentView: View {
    @State private var refresh = 0
    var body: some View {
        NavigationStack {
            List {
                Section("Gates") {
                    NavigationLink("Alarms: G1 G2 G5 G8 G9") { AlarmGatesView() }
                    NavigationLink("Defuse: G3") { DefuseGateView() }
                    NavigationLink("Stillness: G4") { MotionGateView() }
                }
                Section("Log") {
                    ShareLink(item: GateLog.shared.fileURL) { Label("Export gate log", systemImage: "square.and.arrow.up") }
                    if GateLog.shared.failedWrites > 0 {
                        Text("⚠️ \(GateLog.shared.failedWrites) log writes failed").foregroundStyle(.red)
                    }
                    ForEach(Array(GateLog.shared.entries().suffix(20).reversed().enumerated()), id: \.offset) { _, e in
                        Text("\(e.time.formatted(date: .omitted, time: .standard)) \(e.gate) \(e.event) \(e.detail.description)")
                            .font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("Wake Probe")
            .refreshable { refresh += 1 }
            .id(refresh)
        }
    }
}
