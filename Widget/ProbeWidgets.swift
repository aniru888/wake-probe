import WidgetKit
import SwiftUI
import AlarmKit

@main
struct ProbeWidgets: WidgetBundle {
    var body: some Widget { AlarmLiveActivity(); DefuseLiveActivity() }
}

/// Insurance: AlarmKit "expects a widget extension if an app supports a countdown
/// presentation". We don't use countdown for alarms, but ship this anyway.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<ProbeMetadata>.self) { context in
            switch context.state.mode {
            case .alert: Text("Alarm")
            case .countdown: Text("Counting down")
            case .paused: Text("Paused")
            @unknown default: Text("Alarm")
            }
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { Text("Alarm") }
            } compactLeading: { Text("A") } compactTrailing: { Text("") } minimal: { Text("A") }
        }
    }
}

struct DefuseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DefuseAttributes.self) { context in
            HStack {
                Text(timerInterval: Date()...context.state.deadline, countsDown: true).monospacedDigit()
                Spacer()
                Button(intent: DefuseIntent()) { Text("Still up (\(context.state.taps))") }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Button(intent: DefuseIntent()) { Text("Still up") }
                }
            } compactLeading: { Text("⏱") } compactTrailing: {
                Text(timerInterval: Date()...context.state.deadline, countsDown: true).monospacedDigit().frame(width: 44)
            } minimal: { Text("⏱") }
        }
    }
}
