import Foundation

final class DeductionPreferenceStore {
    static let shared = DeductionPreferenceStore()

    private let key = "FlexErrnDeductionPreferences"
    private var cache: [String: [String: Bool]]?

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
}
