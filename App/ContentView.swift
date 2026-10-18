import SwiftUI

struct ContentView: View {
    @State private var refresh = 0
    var body: some View {
        NavigationStack {
            List {
                Section("Log") {
                    ShareLink(item: GateLog.shared.fileURL) { Label("Export gate log", systemImage: "square.and.arrow.up") }
                    ForEach(GateLog.shared.entries().suffix(20).reversed(), id: \.time) { e in
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
