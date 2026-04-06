import Foundation
import StoreKit
import Combine

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    // MARK: - Product Identifiers

    static let monthlyID = "com.tejay.BlockErrn.pro.monthly"
    static let yearlyID = "com.tejay.BlockErrn.pro.yearly"
    static let lifetimeID = "com.tejay.BlockErrn.pro.lifetime"

    private static let productIDs: Set<String> = [
        monthlyID,
        yearlyID,
        lifetimeID
    ]

    // MARK: - Persistence Key

    private static let purchasedKey = "BlockErrn_PurchasedProductIDs"

    // MARK: - Published State

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = [] {
        didSet {
            // Cache to UserDefaults so state is available immediately on next launch
            let array = Array(purchasedProductIDs)
            UserDefaults.standard.set(array, forKey: Self.purchasedKey)
        }
    }
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    var isProUnlocked: Bool {
        !purchasedProductIDs.isEmpty
    }

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyID }
    }

    var lifetimeProduct: Product? {
        products.first { $0.id == Self.lifetimeID }
    }

    // MARK: - Transaction Listener

    private var transactionListener: Task<Void, Error>?

    private init() {
        // Restore cached purchase state immediately so UI is correct on launch
        if let cached = UserDefaults.standard.stringArray(forKey: Self.purchasedKey) {
            purchasedProductIDs = Set(cached)
        }
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await hardRefreshEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts.sorted { lhs, rhs in
                let order: [String] = [Self.monthlyID, Self.yearlyID, Self.lifetimeID]
                let lhsIndex = order.firstIndex(of: lhs.id) ?? 99
                let rhsIndex = order.firstIndex(of: rhs.id) ?? 99
                return lhsIndex < rhsIndex
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            // Immediately mark this product as purchased so UI updates right away
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
            // Also do a full refresh from entitlements for consistency
            await refreshEntitlements()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await hardRefreshEntitlements()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Transaction Updates

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try await self.checkVerified(result)
                    await MainActor.run { _ =
                        self.purchasedProductIDs.insert(transaction.productID)
                    }
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    // Transaction verification failed
                }
            }
        }
    }

    /// Merge entitlements with known purchases (safe for post-purchase).
    /// Prevents a race where currentEntitlements hasn't caught up yet.
    private func refreshEntitlements() async {
        let entitled = await fetchCurrentEntitlements()
        let merged = purchasedProductIDs.union(entitled)
        if merged != purchasedProductIDs {
            purchasedProductIDs = merged
        }
    }

    /// Full replace from StoreKit entitlements (used on launch and restore).
    /// This will correctly remove expired subscriptions.
    private func hardRefreshEntitlements() async {
        let entitled = await fetchCurrentEntitlements()
        purchasedProductIDs = entitled
    }

    private func fetchCurrentEntitlements() async -> Set<String> {
        var entitled: Set<String> = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    entitled.insert(transaction.productID)
                }
            } catch {
                // Skip unverified transactions
            }
        }
        return entitled
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed."
        }
    }
}
