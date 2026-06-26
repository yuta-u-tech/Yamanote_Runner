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

    #if DEBUG
    static let developerAccessUserDefaultsKey = "vol2.developerSubscriptionAccess"
    static let adminEmailEnvironmentKey = "YAMANOTE_ADMIN_EMAIL"
    static let adminPasscodeEnvironmentKey = "YAMANOTE_ADMIN_PASSCODE"
    #endif

    private let userDefaults: UserDefaults
    private let environment: [String: String]

    init(
        initialStatus: SubscriptionStatus = .loading,
        userDefaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.userDefaults = userDefaults
        self.environment = environment
        status = Self.isDeveloperAccessEnabled(userDefaults: userDefaults) ? .subscribed : initialStatus
    }

    func loadProducts() async {
        guard !isDeveloperAccessEnabled else { return }

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
        guard !isDeveloperAccessEnabled else {
            status = .subscribed
            return
        }

        #if DEBUG
        guard !restoreDeveloperAccessFromEnvironment() else { return }
        #endif

        do {
            try await AppStore.sync()
            await checkCurrentEntitlement()
        } catch {
            status = .error("購入の復元に失敗しました")
        }
    }

    func checkCurrentEntitlement() async {
        guard !isDeveloperAccessEnabled else {
            status = .subscribed
            return
        }

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

    private var isDeveloperAccessEnabled: Bool {
        Self.isDeveloperAccessEnabled(userDefaults: userDefaults)
    }

    #if DEBUG
    func restoreDeveloperAccessFromEnvironment() -> Bool {
        guard environment[Self.adminEmailEnvironmentKey]?.trimmedNonEmpty != nil,
              environment[Self.adminPasscodeEnvironmentKey]?.trimmedNonEmpty != nil
        else {
            return false
        }
        return enableDeveloperAccess()
    }

    private func enableDeveloperAccess() -> Bool {
        userDefaults.set(true, forKey: Self.developerAccessUserDefaultsKey)
        status = .subscribed
        return true
    }
    #endif

    private static func isDeveloperAccessEnabled(userDefaults: UserDefaults) -> Bool {
        #if DEBUG
        userDefaults.bool(forKey: developerAccessUserDefaultsKey)
        #else
        false
        #endif
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

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
