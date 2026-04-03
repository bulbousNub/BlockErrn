import SwiftUI
import SwiftData
import UIKit

@main
struct BlockErrnApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container = ModelStorage.shared.container

    init() {
        _ = ModelStorage.shared
    }

    var body: some Scene {
        WindowGroup {
            Bootstrapper()
        }
        .modelContainer(container)
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
