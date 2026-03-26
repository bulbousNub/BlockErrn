import SwiftUI
import SwiftData

@main
struct FlexErrnApp: App {
    var body: some Scene {
        WindowGroup {
            Bootstrapper()
        }
        .modelContainer(for: [Block.self, Expense.self, AuditEntry.self, AppSettings.self])
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
