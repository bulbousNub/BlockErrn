import Foundation
import CoreLocation
import Combine

final class MileageTracker: NSObject, ObservableObject {
    static let shared = MileageTracker()

    private let manager = CLLocationManager()
    private let metersPerMile = 1609.34

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isTracking: Bool = false
    @Published private var distanceMeters: Double = 0
    @Published private(set) var currentBlockID: UUID?

    private var lastLocation: CLLocation?

    private let backgroundTrackingAllowed: Bool
    private var pendingAlwaysAuthorizationRequest: Bool = false

    private override init() {
        self.authorizationStatus = CLLocationManager.authorizationStatus()
        #if targetEnvironment(simulator)
        self.backgroundTrackingAllowed = false
        #else
        self.backgroundTrackingAllowed = true
        #endif
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = backgroundTrackingAllowed
    }

    var currentMiles: Double {
        distanceMeters / metersPerMile
    }

    var canStartTracking: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined:
            return true
        default:
            return false
        }
    }

    func requestAuthorization() {
        switch authorizationStatus {
        case .notDetermined:
            pendingAlwaysAuthorizationRequest = backgroundTrackingAllowed
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse where backgroundTrackingAllowed:
            manager.requestAlwaysAuthorization()
            pendingAlwaysAuthorizationRequest = false
        default:
            break
        }
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startTracking(for blockID: UUID) {
        currentBlockID = blockID
        distanceMeters = 0
        lastLocation = nil
        isTracking = true
        manager.startUpdatingLocation()
    }

    func stopTracking(for blockID: UUID) -> Int? {
        guard isTracking, currentBlockID == blockID else { return nil }
        manager.stopUpdatingLocation()
        isTracking = false
        let miles = currentMiles
        distanceMeters = 0
        lastLocation = nil
        currentBlockID = nil
        return Int(miles.rounded())
    }
}

extension MileageTracker: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        guard backgroundTrackingAllowed,
              pendingAlwaysAuthorizationRequest,
              status == .authorizedWhenInUse else {
            return
        }
        pendingAlwaysAuthorizationRequest = false
        manager.requestAlwaysAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }
        for location in locations {
            if let last = lastLocation {
                distanceMeters += location.distance(from: last)
            }
            lastLocation = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // ignore for now
    }
}
