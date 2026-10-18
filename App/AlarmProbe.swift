import SwiftUI
import AlarmKit
import ActivityKit
import AppIntents
import CoreMotion

enum AlarmProbe {
    static func authorize() async -> Bool {
        let mgr = AlarmManager.shared
        if mgr.authorizationState == .notDetermined { _ = try? await mgr.requestAuthorization() }
        GateLog.shared.record("AUTH", "alarmkit", ["state": "\(mgr.authorizationState)"])
        return mgr.authorizationState == .authorized
    }

    @discardableResult
    static func schedule(gate: String, at date: Date, sound: String?) async -> UUID? {
        guard await authorize() else { return nil }
        let id = UUID()
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: "Probe \(gate)")
        } else {
            alert = AlarmPresentation.Alert(title: "Probe \(gate)",
                                            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"))
        }
        let attributes = AlarmAttributes<ProbeMetadata>(presentation: AlarmPresentation(alert: alert),
                                                        metadata: ProbeMetadata(), tintColor: .orange)
        let config = AlarmManager.AlarmConfiguration<ProbeMetadata>.alarm(
            schedule: .fixed(date),
            attributes: attributes,
            stopIntent: ProbeStopIntent(alarmID: id.uuidString, gate: gate),
            secondaryIntent: nil,
            sound: sound.map { .named($0) } ?? .default)
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
            GateLog.shared.record(gate, "scheduled", ["id": id.uuidString, "at": date.formatted(.iso8601), "sound": sound ?? "default"])
            return id
        } catch {
            GateLog.shared.record(gate, "schedule-error", ["error": "\(error)"])
            return nil
        }
    }

    static func reschedule(gate: String, after seconds: TimeInterval) async -> UUID? {
        await schedule(gate: gate, at: Date().addingTimeInterval(seconds), sound: nil)
    }

    static func cancel(_ id: UUID) {
        do { try AlarmManager.shared.cancel(id: id); GateLog.shared.record("CANCEL", "ok", ["id": id.uuidString]) }
        catch { GateLog.shared.record("CANCEL", "error", ["id": id.uuidString, "error": "\(error)"]) }
    }

    /// G9: read steps for the last 45 min and time how long it takes.
    static func logStepsLast45(gate: String) async {
        let started = Date()
        GateLog.shared.record(gate, "steps-start", [:])
        let pedometer = CMPedometer()
        let steps: Int? = await withCheckedContinuation { cont in
            pedometer.queryPedometerData(from: Date().addingTimeInterval(-45 * 60), to: Date()) { data, error in
                _ = pedometer
                if let error { GateLog.shared.record(gate, "steps-error", ["error": "\(error)"]) }
                cont.resume(returning: data?.numberOfSteps.intValue)
            }
        }
        GateLog.shared.record(gate, "steps45", ["steps": steps.map(String.init) ?? "nil",
                                                "ms": String(Int(Date().timeIntervalSince(started) * 1000)),
                                                "auth": "\(CMPedometer.authorizationStatus().rawValue)"])
    }
}

enum ProcessClock {
    static let launched = Date()
    private static var seen = false
    /// True only on the first call in this process (cold launch marker for G9).
    static func markFirst() -> Bool {
        defer { seen = true }
        return !seen
    }
}

struct ProbeStopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Probe stop"
    @Parameter(title: "alarmID") var alarmID: String
    @Parameter(title: "gate") var gate: String
    init(alarmID: String, gate: String) { self.alarmID = alarmID; self.gate = gate }
    init() { self.alarmID = ""; self.gate = "" }

    func perform() async throws -> some IntentResult {
        GateLog.shared.record(gate, "stop-intent-ran", [
            "id": alarmID,
            "processAgeMs": String(Int(Date().timeIntervalSince(ProcessClock.launched) * 1000)),
            "firstRecordThisProcess": "\(ProcessClock.markFirst())"])
        let d = UserDefaults.standard
        if gate == "G5", d.bool(forKey: "g5.enabled") {
            if d.integer(forKey: "g5.count") < 3 {
                let newID = await AlarmProbe.reschedule(gate: "G5", after: 15)   // G5: re-ring from inside the intent
                if newID != nil { d.set(d.integer(forKey: "g5.count") + 1, forKey: "g5.count") }
                GateLog.shared.record("G5", newID == nil ? "reschedule-failed" : "rescheduled", ["round": "\(d.integer(forKey: "g5.count"))"])
            } else {
                GateLog.shared.record("G5", "cap-reached")
            }
        }
        await AlarmProbe.logStepsLast45(gate: gate)                       // G9, after G5 so a hung query cannot block it
        return .result()
    }
}

struct AlarmGatesView: View {
    @State private var g2Date = Calendar.current.date(byAdding: .hour, value: 7 * 24 + 2, to: Date())!
    var body: some View {
        Form {
            Section("Setup") {
                Button("Allow motion access (G9 setup)") { Task { await AlarmProbe.logStepsLast45(gate: "G9-auth") } }
            }
            Section("G1 rings through silent + Focus (2 min)") {
                Button("Schedule G1 in 2 min") { Task { await AlarmProbe.schedule(gate: "G1", at: .now + 120, sound: nil) } }
                ResultButtons(gate: "G1", options: ["rang-silent+focus", "no-ring-silent+focus", "rang-normal-mode"])
            }
            Section("G8 custom quiet-then-loud sound (2 min)") {
                Button("Schedule G8 in 2 min") { Task { await AlarmProbe.schedule(gate: "G8", at: .now + 120, sound: "probe_ramp.wav") } }
                ResultButtons(gate: "G8", options: ["quiet-then-loud", "flat-loud", "default-sound", "silent", "chime-inaudible"])
                ResultButtons(gate: "G8", options: ["vibrated", "no-vibration"])
            }
            Section("G5 re-ring after Stop (3 rounds)") {
                Button("Arm G5 and schedule in 1 min") {
                    UserDefaults.standard.set(true, forKey: "g5.enabled"); UserDefaults.standard.set(0, forKey: "g5.count")
                    Task { await AlarmProbe.schedule(gate: "G5", at: .now + 60, sound: nil) }
                }
                ResultButtons(gate: "G5", options: ["re-rang-3x", "re-rang-<3", "no-re-ring"])
            }
            Section("G2 alarm after 7-day expiry") {
                DatePicker("Ring at", selection: $g2Date)
                Button("Schedule G2") { Task { await AlarmProbe.schedule(gate: "G2", at: g2Date, sound: nil) } }
                ResultButtons(gate: "G2")
            }
            Section("G9 steps readable at tap") {
                Text("Fires on every Stop. Check the log for 'steps45' with ms.")
            }
        }
        .navigationTitle("Alarm gates")
    }
}

struct ResultButtons: View {
    let gate: String
    var options: [String] = ["rang", "did-not-ring"]
    var body: some View {
        HStack {
            ForEach(options, id: \.self) { o in
                Button(o) { GateLog.shared.record(gate, "result", ["observed": o]) }.buttonStyle(.bordered)
            }
        }
    }
}
