import SwiftUI
import ActivityKit

enum LiveActivityProbe {
    static let window: TimeInterval = 180   // 3 min countdown for the probe

    static func start() async {
        let deadline = Date().addingTimeInterval(window)
        do {
            _ = try Activity.request(attributes: DefuseAttributes(name: "defuse"),
                                     content: ActivityContent(state: .init(deadline: deadline, taps: 0), staleDate: nil),
                                     pushType: nil)
            GateLog.shared.record("G3", "activity-started", ["deadline": deadline.formatted(.iso8601)])
        } catch {
            GateLog.shared.record("G3", "activity-error", ["error": "\(error)"])
            return
        }
        await replaceBackup(at: deadline)
    }

    static func defuse() async {
        let deadline = Date().addingTimeInterval(window)
        for activity in Activity<DefuseAttributes>.activities {
            let taps = activity.content.state.taps + 1
            await activity.update(ActivityContent(state: .init(deadline: deadline, taps: taps), staleDate: nil))
            GateLog.shared.record("G3", "defused", ["taps": "\(taps)", "newDeadline": deadline.formatted(.iso8601)])
        }
        await replaceBackup(at: deadline)
    }

    private static func replaceBackup(at date: Date) async {
        let d = UserDefaults.standard
        if let old = d.string(forKey: "g3.backupID").flatMap(UUID.init(uuidString:)) { AlarmProbe.cancel(old) }
        let new = await AlarmProbe.schedule(gate: "G3", at: date, sound: nil)
        d.set(new?.uuidString, forKey: "g3.backupID")
    }

    static func end() async {
        for a in Activity<DefuseAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
        if let old = UserDefaults.standard.string(forKey: "g3.backupID").flatMap(UUID.init(uuidString:)) { AlarmProbe.cancel(old) }
        GateLog.shared.record("G3", "ended")
    }
}

struct DefuseGateView: View {
    var body: some View {
        Form {
            Section("G3: lock-screen tap moves the backup alarm") {
                Button("Start defuse countdown (3 min)") { Task { await LiveActivityProbe.start() } }
                Button("End and cancel backup") { Task { await LiveActivityProbe.end() } }
                ResultButtons(gate: "G3", options: ["tap-moved-alarm", "tap-needed-unlock", "tap-did-nothing", "backup-rang-on-time"])
            }
        }
        .navigationTitle("Defuse gate")
    }
}
