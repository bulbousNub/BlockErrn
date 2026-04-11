import SwiftUI
import StoreKit

struct ProUpgradeView: View {
    @ObservedObject private var store = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var purchaseError: String?
    @State private var showRestoreSuccess = false

    /// When true, shown during onboarding with slightly different layout
    var isOnboarding: Bool = false

    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient.ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    comparisonSection
                    pricingSection
                    trialNote
                    restoreButton
                    if let error = purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    if showRestoreSuccess {
                        Text("Purchases restored successfully!")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("BlockErrn Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOnboarding {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            // Default-select lifetime (best value)
            if selectedProduct == nil {
                selectedProduct = store.lifetimeProduct
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.yellow)
                .shadow(color: .yellow.opacity(0.4), radius: 12, x: 0, y: 4)
            Text("BlockErrn Pro")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.primary)
            Text("Unlock the full power of your earnings tracker")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Feature")
                    .font(.caption)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .font(.caption)
                    .bold()
                    .frame(width: 50)
                Text("Pro")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.yellow)
                    .frame(width: 50)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))

            comparisonRow("Block tracking", free: true, pro: true)
            comparisonRow("Mileage GPS tracking", free: true, pro: true)
            comparisonRow("Expense logging", free: true, pro: true)
            comparisonRow("Current week trends", free: true, pro: true)
            comparisonRow("Basic CSV export", free: true, pro: true)
            comparisonRow("Local backup", free: true, pro: true)
            comparisonRow("Apple Watch app", free: true, pro: true)
            comparisonRow("CarPlay dashboard", free: true, pro: true)

            Divider().background(.white.opacity(0.2))

            comparisonRow("Receipt capture", free: false, pro: true)
            comparisonRow("Full trend history", free: false, pro: true)
            comparisonRow("iCloud backup", free: false, pro: true)
            comparisonRow("PDF reports", free: false, pro: true)
            comparisonRow("CSV column config", free: false, pro: true)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: BlockErrnTheme.cardShadowColor, radius: 20, x: 0, y: 10)
    }

    private func comparisonRow(_ feature: String, free: Bool, pro: Bool) -> some View {
        HStack {
            Text(feature)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: free ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption)
                .foregroundStyle(free ? .green : .secondary.opacity(0.5))
                .frame(width: 50)
            Image(systemName: pro ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption)
                .foregroundStyle(pro ? .green : .secondary.opacity(0.5))
                .frame(width: 50)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 12) {
            if store.isLoading && store.products.isEmpty {
                ProgressView("Loading plans...")
                    .padding()
            } else {
                if let monthly = store.monthlyProduct {
                    planCard(
                        product: monthly,
                        title: "Monthly",
                        subtitle: "\(monthly.displayPrice)/month",
                        badge: nil
                    )
                }
                if let yearly = store.yearlyProduct {
                    planCard(
                        product: yearly,
                        title: "Yearly",
                        subtitle: "\(yearly.displayPrice)/year",
                        badge: "Save 15%"
                    )
                }
                if let lifetime = store.lifetimeProduct {
                    planCard(
                        product: lifetime,
                        title: "Lifetime",
                        subtitle: "\(lifetime.displayPrice) one-time",
                        badge: "Best Value"
                    )
                }

                if selectedProduct != nil {
                    Button {
                        Task { await purchaseSelected() }
                    } label: {
                        Group {
                            if store.isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text(purchaseButtonTitle)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.yellow)
                    .foregroundColor(.black)
                    .disabled(store.isLoading)
                }
            }
        }
    }

    private var purchaseButtonTitle: String {
        guard let product = selectedProduct else { return "Select a plan" }
        if product.id == StoreKitManager.lifetimeID {
            return "Buy Lifetime — \(product.displayPrice)"
        }
        if let subscription = product.subscription,
           subscription.introductoryOffer != nil {
            return "Start Free Trial"
        }
        return "Subscribe — \(product.displayPrice)"
    }

    private func planCard(product: Product, title: String, subtitle: String, badge: String?) -> some View {
        let isSelected = selectedProduct?.id == product.id

        return Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(product.id == StoreKitManager.lifetimeID ? Color.yellow : Color.green)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .yellow : .secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.yellow.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.yellow : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trial Note

    private var trialNote: some View {
        VStack(spacing: 6) {
            Text("All subscription plans include a 1-week free trial.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Text("Cancel anytime. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task {
                await store.restorePurchases()
                if store.isProUnlocked {
                    showRestoreSuccess = true
                    if !isOnboarding {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                    }
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .underline()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func purchaseSelected() async {
        guard let product = selectedProduct else { return }
        purchaseError = nil
        do {
            let transaction = try await store.purchase(product)
            if transaction != nil && !isOnboarding {
                dismiss()
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

// MARK: - Reusable Pro Locked Banner

struct ProLockedBanner: View {
    let feature: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock with BlockErrn Pro")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.primary)
                    Text("\(feature) is a Pro feature.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
