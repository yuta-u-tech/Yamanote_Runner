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

    init(initialStatus: SubscriptionStatus = .loading) {
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
            try await AppStore.sync()
            await checkCurrentEntitlement()
        } catch {
            status = .error("購入の復元に失敗しました")
        }
    }

    func checkCurrentEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                status = .subscribed
                return
            }
        }
        status = .notSubscribed
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
