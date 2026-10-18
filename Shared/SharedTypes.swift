import Foundation
import AlarmKit
import ActivityKit
import AppIntents

/// Empty metadata is allowed: "The implementation can be empty." (AlarmMetadata docs)
struct ProbeMetadata: AlarmMetadata {}

struct DefuseAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var deadline: Date
        var taps: Int
    }
    var name: String
}

/// Runs in the app's process ("the system runs the app intent in the app's process",
/// WidgetKit docs). The widget compiles this file too, so app-only code is fenced off.
struct DefuseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Still up"
    init() {}
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await LiveActivityProbe.defuse()
        #endif
        return .result()
    }
}
