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
        GateLog.shared.record("G7", "monitor-started", ["launchState": "\(UIApplication.shared.applicationState.rawValue)"])
        Task {
            do {
                for try await event in await m.events {
                    GateLog.shared.record("G7", "event", ["id": event.identifier, "state": "\(event.state)",
                                                          "eventDate": event.date.formatted(.iso8601)])
                }
            } catch {
                GateLog.shared.record("G7", "events-error", ["error": "\(error)"])
            }
        }
    }

    func requestAlways() {
        lm.requestWhenInUseAuthorization()
        lm.requestAlwaysAuthorization()
    }

    func mapHere() { lm.requestLocation() }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            await monitor?.add(CLMonitor.CircularGeographicCondition(center: loc.coordinate, radius: 200),
                               identifier: "room", assuming: .satisfied)
            GateLog.shared.record("G7", "mapped", ["lat": "\(loc.coordinate.latitude)", "lon": "\(loc.coordinate.longitude)",
                                                   "accuracyM": "\(Int(loc.horizontalAccuracy))"])
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
                Button("1. Allow location: choose 'Always'") { GeofenceProbe.shared.requestAlways() }
                Button("2. Map a 200 m fence here") { GeofenceProbe.shared.mapHere() }
            }
            Section("While walking away (app closed or open)") {
                Button("I just passed ~300 m from the room") { GateLog.shared.record("G7", "user-marker", ["at": "300m"]) }
            }
        }
        .navigationTitle("Geofence gate G7")
    }
}
