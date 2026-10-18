import SwiftUI
import CoreLocation

@MainActor
final class GeofenceProbe: NSObject, CLLocationManagerDelegate {
    static let shared = GeofenceProbe()
    private let lm = CLLocationManager()
    private var monitor: CLMonitor?
    private var session: CLServiceSession?

    override init() { super.init(); lm.delegate = self }

    /// Call on EVERY launch. WWDC23-10147: "your app needs to reinit monitor and await events whenever it is launched".
    func start() async {
        session = CLServiceSession(authorization: .always)
        let m = await CLMonitor("wakeProbeMonitor")
        monitor = m
        GateLog.shared.record("G7", "monitor-started", ["appState": Self.readable(UIApplication.shared.applicationState),
                                                        "auth": Self.readable(lm.authorizationStatus)])
        Task {
            do {
                for try await event in await m.events {
                    GateLog.shared.record("G7", "event", ["id": event.identifier, "state": "\(event.state)",
                                                          "eventDate": event.date.formatted(.iso8601),
                                                          "appState": Self.readable(UIApplication.shared.applicationState),
                                                          "authDenied": "\(event.authorizationDenied)",
                                                          "insufficientlyInUse": "\(event.insufficientlyInUse)",
                                                          "sessionRequired": "\(event.serviceSessionRequired)",
                                                          "accuracyLimited": "\(event.accuracyLimited)"])
                }
            } catch {
                GateLog.shared.record("G7", "events-error", ["error": "\(error)"])
            }
        }
    }

    nonisolated static func readable(_ s: UIApplication.State) -> String {
        switch s {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown(\(s.rawValue))"
        }
    }

    nonisolated static func readable(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "always"
        case .authorizedWhenInUse: return "whenInUse"
        @unknown default: return "unknown(\(s.rawValue))"
        }
    }

    func requestAlways() {
        lm.requestWhenInUseAuthorization()
    }

    func mapHere() { lm.requestLocation() }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in GateLog.shared.record("G7", "auth-changed", ["auth": Self.readable(status)]) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard let monitor else {
                GateLog.shared.record("G7", "map-failed", ["reason": "monitor not started"])
                return
            }
            await monitor.add(CLMonitor.CircularGeographicCondition(center: loc.coordinate, radius: 200),
                              identifier: "room", assuming: .satisfied)
            GateLog.shared.record("G7", "mapped", ["lat": "\(loc.coordinate.latitude)", "lon": "\(loc.coordinate.longitude)",
                                                   "accuracyM": "\(Int(loc.horizontalAccuracy))",
                                                   "auth": Self.readable(status)])
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in GateLog.shared.record("G7", "location-error", ["error": "\(error)"]) }
    }
}

struct GeofenceGateView: View {
    var body: some View {
        Form {
            Section("Setup (in your room)") {
                Button("1. Allow location (then set 'Always' in Settings)") { GeofenceProbe.shared.requestAlways() }
                Text("Settings › Privacy & Security › Location Services › Wake Probe › Always")
                    .font(.caption)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button("2. Map a 200 m fence here") { GeofenceProbe.shared.mapHere() }
            }
            Section("While walking away (app closed or open)") {
                Button("I just passed ~300 m from the room") { GateLog.shared.record("G7", "user-marker", ["at": "300m"]) }
            }
        }
        .navigationTitle("Geofence gate G7")
    }
}
