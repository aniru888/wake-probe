import SwiftUI
import ActivityKit
import UIKit

enum LiveActivityProbe {
    static let window: TimeInterval = LiveWindow.seconds   // 3 min countdown for the probe

    static func start() async {
        let deadline = Date().addingTimeInterval(window)
        do {
            _ = try Activity.request(attributes: DefuseAttributes(name: "defuse"),
                                     content: ActivityContent(state: .init(deadline: deadline, taps: 0), staleDate: deadline),
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
        GateLog.shared.record("G3", "defuse-called", ["activities": "\(Activity<DefuseAttributes>.activities.count)"])
        for activity in Activity<DefuseAttributes>.activities {
            let taps = activity.content.state.taps + 1
            await activity.update(ActivityContent(state: .init(deadline: deadline, taps: taps), staleDate: deadline))
            GateLog.shared.record("G3", "defused", ["taps": "\(taps)", "newDeadline": deadline.formatted(.iso8601),
                "firstRecordThisProcess": "\(ProcessClock.markFirst())",
                "processAgeMs": String(Int(Date().timeIntervalSince(ProcessClock.launched) * 1000)),
                "appState": "\(await MainActor.run { UIApplication.shared.applicationState.rawValue })"])
        }
        await replaceBackup(at: deadline)
    }

    private static func replaceBackup(at date: Date) async {
        let d = UserDefaults.standard
        let old = d.string(forKey: "g3.backupID").flatMap(UUID.init(uuidString:))
        if let old { AlarmProbe.cancel(old) }
        let new = await AlarmProbe.schedule(gate: "G3", at: date, sound: nil)
        d.set(new?.uuidString, forKey: "g3.backupID")
        GateLog.shared.record("G3", new == nil ? "backup-missing" : "backup-moved", ["old": old?.uuidString ?? "none", "new": new?.uuidString ?? "none", "at": date.formatted(.iso8601)])
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
