import Foundation
import StoreKit

struct ForgeSubscriptionPlan: Identifiable, Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
    let periodLabel: String
    let isBestValue: Bool
}

@Observable
@MainActor
final class ForgeSubscriptionService {
    private(set) var isPro = false
    private(set) var plans: [ForgeSubscriptionPlan] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let grantProForTesting: Bool
    private nonisolated(unsafe) var transactionUpdatesTask: Task<Void, Never>?

    init(grantProForTesting: Bool = UITestConfiguration.shouldGrantPro) {
        self.grantProForTesting = grantProForTesting
        if grantProForTesting {
            isPro = true
        }
        transactionUpdatesTask = Task { await listenForTransactions() }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func bootstrap() async {
        await refreshEntitlements()
        await loadProducts()
    }

    func refreshEntitlements() async {
        if grantProForTesting || UITestConfiguration.shouldGrantPro {
            isPro = true
            return
        }

        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ForgeSubscriptionProducts.all.contains(transaction.productID) {
                entitled = true
                break
            }
        }
        isPro = entitled
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: ForgeSubscriptionProducts.all)
            plans = products
                .sorted { lhs, rhs in
                    if lhs.id == ForgeSubscriptionProducts.annual { return true }
                    if rhs.id == ForgeSubscriptionProducts.annual { return false }
                    return lhs.displayPrice < rhs.displayPrice
                }
                .map { product in
                    ForgeSubscriptionPlan(
                        id: product.id,
                        displayName: product.displayName,
                        displayPrice: product.displayPrice,
                        periodLabel: product.id == ForgeSubscriptionProducts.annual ? "per year" : "per month",
                        isBestValue: product.id == ForgeSubscriptionProducts.annual
                    )
                }

            if plans.isEmpty {
                plans = fallbackPlans
            }
        } catch {
            lastError = "Could not load subscription plans."
            plans = fallbackPlans
        }
    }

    @discardableResult
    func purchase(planID: String) async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [planID])
            guard let product = products.first else {
                lastError = "Plan unavailable in the App Store."
                return false
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "Purchase could not be verified."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .userCancelled:
                return false
            case .pending:
                lastError = "Purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed. Try again."
            return false
        }
    }

    func restore() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro {
                lastError = "No active subscription found."
            }
        } catch {
            lastError = "Could not restore purchases."
        }
    }

    private var fallbackPlans: [ForgeSubscriptionPlan] {
        [
            ForgeSubscriptionPlan(
                id: ForgeSubscriptionProducts.annual,
                displayName: "HotBod Pro Annual",
                displayPrice: "$79.99",
                periodLabel: "per year",
                isBestValue: true
            ),
            ForgeSubscriptionPlan(
                id: ForgeSubscriptionProducts.monthly,
                displayName: "HotBod Pro Monthly",
                displayPrice: "$9.99",
                periodLabel: "per month",
                isBestValue: false
            )
        ]
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }
}
