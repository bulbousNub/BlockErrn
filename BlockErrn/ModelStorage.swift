import SwiftData

@MainActor
final class ModelStorage {
    static let shared: ModelStorage = {
        do {
            return try ModelStorage()
        } catch {
            fatalError("Failed to configure ModelContainer: \(error)")
        }
    }()

    let container: ModelContainer

    private init() throws {
        let schema = Schema([Block.self, Expense.self, AuditEntry.self, AppSettings.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    var context: ModelContext {
        container.mainContext
    }
}
