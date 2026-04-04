import Foundation
import WatchConnectivity
import Combine

/// Watch-side WCSession delegate.
/// Publishes state received from the iPhone and sends commands to it.
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    // MARK: - Published State

    @Published var activeBlocks: [WatchBlockSummary] = []
    @Published var upcomingBlocks: [WatchBlockSummary] = []
    @Published var isTracking: Bool = false
    @Published var trackingBlockID: UUID?
    @Published var currentMiles: Double = 0
    @Published var workModeBlockID: UUID?
    @Published var irsRate: String = "0.70"
    @Published var lastSyncDate: Date?
    @Published var isReachable: Bool = false

    private var session: WCSession?

    private override init() {
        super.init()
    }

    // MARK: - Activation

    func activateSession() {
        guard WCSession.isSupported() else {
            print("Watch: WCSession not supported")
            return
        }
        let wc = WCSession.default
        wc.delegate = self
        wc.activate()
        session = wc
        print("Watch: WCSession activated, reachable=\(wc.isReachable), activationState=\(wc.activationState.rawValue)")

        // Check for any applicationContext that arrived before activation
        let ctx = wc.receivedApplicationContext
        print("Watch: receivedApplicationContext keys=\(ctx.keys)")
        if let data = ctx[WatchMessageKey.stateSnapshot] as? Data {
            print("Watch: Found snapshot in applicationContext (\(data.count) bytes)")
            processSnapshot(data)
        }
    }

    // MARK: - Send Commands

    func sendCommand(_ command: WatchCommand, blockID: UUID? = nil, params: [String: String]? = nil) {
        guard let session, session.isReachable else { return }
        let message = WatchCommandMessage(command: command, blockID: blockID, params: params)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(message) else { return }
        let payload: [String: Any] = [WatchMessageKey.commandPayload: data]
        session.sendMessage(payload, replyHandler: nil) { error in
            print("Watch: Failed to send command \(command): \(error.localizedDescription)")
        }
    }

    func requestSync() {
        sendCommand(.requestSync)
    }

    // MARK: - State Processing

    private func processSnapshot(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(WatchStateSnapshot.self, from: data) else { return }
        DispatchQueue.main.async {
            self.activeBlocks = snapshot.activeBlocks
            self.upcomingBlocks = snapshot.upcomingBlocks
            self.isTracking = snapshot.isTracking
            self.trackingBlockID = snapshot.trackingBlockID
            self.currentMiles = snapshot.currentMiles
            self.workModeBlockID = snapshot.workModeBlockID
            self.irsRate = snapshot.irsRate
            self.lastSyncDate = snapshot.timestamp
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch: activationDidComplete state=\(activationState.rawValue) error=\(String(describing: error)) reachable=\(session.isReachable)")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        if activationState == .activated {
            // Check applicationContext first (always available, even if not reachable)
            let ctx = session.receivedApplicationContext
            print("Watch: applicationContext keys=\(ctx.keys)")
            if let data = ctx[WatchMessageKey.stateSnapshot] as? Data {
                print("Watch: Found snapshot in applicationContext (\(data.count) bytes)")
                processSnapshot(data)
            }
            // Also try live sync if reachable
            if session.isReachable {
                print("Watch: Phone is reachable, requesting sync")
                requestSync()
            } else {
                print("Watch: Phone is NOT reachable")
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let data = message[WatchMessageKey.stateSnapshot] as? Data {
            processSnapshot(data)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        if let data = message[WatchMessageKey.stateSnapshot] as? Data {
            processSnapshot(data)
        }
        replyHandler([WatchMessageKey.success: true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let data = userInfo[WatchMessageKey.stateSnapshot] as? Data {
            processSnapshot(data)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext[WatchMessageKey.stateSnapshot] as? Data {
            processSnapshot(data)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        if session.isReachable {
            requestSync()
        }
    }
}
