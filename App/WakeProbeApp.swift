import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = ProcessClock.launched
        GateLog.shared.record("G7", "launch", ["launchedForLocation": "\(launchOptions?[.location] != nil)",
                                               "appState": GeofenceProbe.readable(application.applicationState)])
        Task { @MainActor in await GeofenceProbe.shared.start() }
        return true
    }
}

@main
struct WakeProbeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
