import Foundation
import StoreKit

enum SubscriptionStatus: Equatable {
    case loading
    case subscribed
    case notSubscribed
    case error(String)
}

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var status: SubscriptionStatus
    @Published private(set) var availableProducts: [Product] = []

    static let productIDs: Set<String> = ["com.yamanoterunner.pro.monthly"]

    private static let legacyDeveloperAccessKeys = [
        "vol2.developerSubscriptionAccess",
        "vol2.adminSubscriptionOverride"
    ]

    private let syncPurchases: () async throws -> Void
    private let currentEntitledProductIDs: () async -> Set<String>

    init(
        initialStatus: SubscriptionStatus = .loading,
        userDefaults: UserDefaults = .standard,
        syncPurchases: @escaping () async throws -> Void = { try await AppStore.sync() },
        currentEntitledProductIDs: @escaping () async -> Set<String> = {
            await SubscriptionService.loadCurrentEntitledProductIDs()
        }
    ) {
        Self.legacyDeveloperAccessKeys.forEach(userDefaults.removeObject(forKey:))
        self.syncPurchases = syncPurchases
        self.currentEntitledProductIDs = currentEntitledProductIDs
        status = initialStatus
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.productIDs)
            availableProducts = products.sorted { $0.price < $1.price }
        } catch {
            status = .error("商品情報の取得に失敗しました")
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            status = .subscribed
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await syncPurchases()
            await checkCurrentEntitlement()
        } catch {
            status = .error("購入の復元に失敗しました")
        }
    }

    func checkCurrentEntitlement() async {
        let entitledProductIDs = await currentEntitledProductIDs()
        status = entitledProductIDs.isDisjoint(with: Self.productIDs)
            ? .notSubscribed
            : .subscribed
    }

    private nonisolated static func loadCurrentEntitledProductIDs() async -> Set<String> {
        var productIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                productIDs.insert(transaction.productID)
            }
        }
        return productIDs
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let value):
            return value
        }
    }
}

enum SubscriptionError: Error {
    case failedVerification
}
