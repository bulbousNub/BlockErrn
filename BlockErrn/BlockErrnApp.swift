import SwiftUI
import SwiftData
import UIKit

@main
struct BlockErrnApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let container = ModelStorage.shared.container

    init() {
        _ = ModelStorage.shared
        _ = StoreKitManager.shared
        PhoneWatchSessionManager.shared.activateSession()
    }

    var body: some Scene {
        WindowGroup {
            Bootstrapper()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                ICloudAutoBackup.performIfEnabled(container: container)
            }
        }
    }
}

struct Bootstrapper: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    var body: some View {
        ContentView()
            .task {
                if settings.isEmpty {
                    let s = AppSettings()
                    context.insert(s)
                    try? context.save()
                }
            }
    }
}
