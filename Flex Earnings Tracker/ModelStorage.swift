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
        container = try ModelContainer(for: Block.self, Expense.self, AuditEntry.self, AppSettings.self)
    }

    var context: ModelContext {
        container.mainContext
    }
}
