import WidgetKit
import SwiftUI
import AlarmKit

@main
struct ProbeWidgets: WidgetBundle {
    var body: some Widget { AlarmLiveActivity() }
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
