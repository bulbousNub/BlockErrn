import Foundation
import CoreLocation
import Combine
import CoreMotion

final class MileageTracker: NSObject, ObservableObject {
    static let shared = MileageTracker()

    private let manager = CLLocationManager()
    private let activityManager = CMMotionActivityManager()
    private let metersPerMile = 1609.34

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isTracking: Bool = false
    @Published private var distanceMeters: Double = 0
    @Published private(set) var currentBlockID: UUID?
    @Published private(set) var motionAuthorizationStatus: CMAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
    @Published private(set) var isInVehicle: Bool = false

    private var lastLocation: CLLocation?
    private var routePoints: [RoutePoint] = []
    private var lastDrivingLocation: CLLocation?
    private var lastActivity: CMMotionActivity?
    private var trackingActivityUpdatesActive: Bool = false
    private var permissionActivityUpdatesActive: Bool = false
    private var activityUpdatesRunning: Bool = false

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
        motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
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

    func requestMotionAuthorization() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
        permissionActivityUpdatesActive = true
        updateActivityUpdatesState()
    }

    func startTracking(for blockID: UUID) {
        currentBlockID = blockID
        distanceMeters = 0
        lastLocation = nil
        routePoints = []
        lastDrivingLocation = nil
        isTracking = true
        trackingActivityUpdatesActive = true
        updateActivityUpdatesState()
        manager.startUpdatingLocation()
    }

    func stopTracking(for blockID: UUID) -> (Double, [RoutePoint])? {
        guard isTracking, currentBlockID == blockID else { return nil }
        manager.stopUpdatingLocation()
        isTracking = false
        let miles = currentMiles
        distanceMeters = 0
        lastLocation = nil
        lastDrivingLocation = nil
        currentBlockID = nil
        trackingActivityUpdatesActive = false
        updateActivityUpdatesState()
        lastActivity = nil
        isInVehicle = false
        return (miles, routePoints)
    }

    var currentRoutePoints: [RoutePoint] {
        routePoints
    }

    private func updateActivityUpdatesState() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        let shouldRun = trackingActivityUpdatesActive || permissionActivityUpdatesActive
        if shouldRun && !activityUpdatesRunning {
            activityUpdatesRunning = true
            activityManager.startActivityUpdates(to: OperationQueue.main) { [weak self] activity in
                self?.handleActivity(activity)
            }
        } else if !shouldRun && activityUpdatesRunning {
            activityUpdatesRunning = false
            activityManager.stopActivityUpdates()
        }
    }

    private func handleActivity(_ activity: CMMotionActivity?) {
        guard let activity else { return }
        lastActivity = activity
        isInVehicle = activity.automotive
        motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
        if permissionActivityUpdatesActive && !trackingActivityUpdatesActive {
            permissionActivityUpdatesActive = false
            updateActivityUpdatesState()
        }
    }

    private func shouldAccumulateDistance(for location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0 else { return false }
        if let activity = lastActivity {
            if activity.automotive {
                return true
            }
            if activity.walking || activity.running || activity.cycling || activity.stationary {
                return false
            }
        }
        let speed = max(location.speed, 0)
        return speed >= 5.0
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
            if shouldAccumulateDistance(for: location) {
                if let lastDriving = lastDrivingLocation {
                    distanceMeters += location.distance(from: lastDriving)
                }
                lastDrivingLocation = location
            } else {
                lastDrivingLocation = nil
            }
            lastLocation = location
            routePoints.append(RoutePoint(location: location))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // ignore for now
    }
}
