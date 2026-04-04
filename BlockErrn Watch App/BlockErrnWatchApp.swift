import SwiftUI

@main
struct BlockErrnWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager.shared

    init() {
        WatchSessionManager.shared.activateSession()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(sessionManager)
        }
    }
}
