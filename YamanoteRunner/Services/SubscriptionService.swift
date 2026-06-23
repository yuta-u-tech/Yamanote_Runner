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
    static let adminOverrideUserDefaultsKey = "vol2.adminSubscriptionOverride"
    static let adminEmailEnvironmentKey = "YAMANOTE_ADMIN_EMAIL"
    static let adminPasscodeEnvironmentKey = "YAMANOTE_ADMIN_PASSCODE"
    static let adminRestoreEmail = "yuta_Hinu_auth@email.com"
    static let adminRestorePasscode = "yuta_Hinu_pass"

    private let userDefaults: UserDefaults
    private let environment: [String: String]

    init(
        initialStatus: SubscriptionStatus = .loading,
        userDefaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.userDefaults = userDefaults
        self.environment = environment
        status = Self.isAdminOverrideEnabled(userDefaults: userDefaults) ? .subscribed : initialStatus
    }

    func loadProducts() async {
        guard !isAdminOverrideEnabled else { return }

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
        guard !isAdminOverrideEnabled else {
            status = .subscribed
            return
        }

        guard !restoreAdminOverrideIfConfigured() else { return }

        do {
            try await AppStore.sync()
            await checkCurrentEntitlement()
        } catch {
            status = .error("購入の復元に失敗しました")
        }
    }

    func checkCurrentEntitlement() async {
        guard !isAdminOverrideEnabled else {
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

    private var isAdminOverrideEnabled: Bool {
        Self.isAdminOverrideEnabled(userDefaults: userDefaults)
    }

    func restoreAdminOverrideIfConfigured() -> Bool {
        guard let configuredEmail = environment[Self.adminEmailEnvironmentKey]?.trimmedNonEmpty,
              let configuredPasscode = environment[Self.adminPasscodeEnvironmentKey]?.trimmedNonEmpty,
              configuredEmail.lowercased() == Self.adminRestoreEmail.lowercased(),
              configuredPasscode == Self.adminRestorePasscode
        else {
            return false
        }

        userDefaults.set(true, forKey: Self.adminOverrideUserDefaultsKey)
        status = .subscribed
        return true
    }

    private static func isAdminOverrideEnabled(userDefaults: UserDefaults) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-adminSubscription")
            || arguments.contains("-admin")
            || userDefaults.bool(forKey: adminOverrideUserDefaultsKey)
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
