import Foundation

final class DeductionPreferenceStore {
    static let shared = DeductionPreferenceStore()

    private let key = "BlockErrnDeductionPreferences"
    private var cache: [String: [String: Bool]]?

    private let expenseKey = "BlockErrnExpenseExclusions"
    private var expenseCache: [String: Bool]?

    enum PreferenceType: String {
        case mileage
        case expenses
    }

    func shouldExclude(type: PreferenceType, blockID: UUID) -> Bool {
        loadCacheIfNeeded()
        let blockPrefs = cache?[blockID.uuidString]
        return blockPrefs?[type.rawValue] ?? false
    }

    func setExclude(_ exclude: Bool, type: PreferenceType, blockID: UUID) {
        loadCacheIfNeeded()
        var blockPrefs = cache?[blockID.uuidString] ?? [:]
        blockPrefs[type.rawValue] = exclude
        cache?[blockID.uuidString] = blockPrefs
        saveCache()
    }

    func isExpenseExcluded(_ expenseID: UUID) -> Bool {
        loadExpenseCacheIfNeeded()
        return expenseCache?[expenseID.uuidString] ?? false
    }

    func setExpenseExcluded(_ excluded: Bool, expenseID: UUID) {
        loadExpenseCacheIfNeeded()
        expenseCache?[expenseID.uuidString] = excluded
        saveExpenseCache()
    }

    private func loadCacheIfNeeded() {
        if cache != nil { return }
        if let stored = UserDefaults.standard.dictionary(forKey: key) as? [String: [String: Bool]] {
            cache = stored
        } else {
            cache = [:]
        }
    }

    private func saveCache() {
        guard let cache = cache else { return }
        UserDefaults.standard.set(cache, forKey: key)
    }

    private func loadExpenseCacheIfNeeded() {
        if expenseCache != nil { return }
        if let stored = UserDefaults.standard.dictionary(forKey: expenseKey) as? [String: Bool] {
            expenseCache = stored
        } else {
            expenseCache = [:]
        }
    }

    private func saveExpenseCache() {
        guard let expenseCache = expenseCache else { return }
        UserDefaults.standard.set(expenseCache, forKey: expenseKey)
    }
}
