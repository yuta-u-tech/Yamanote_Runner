import StoreKit
import SwiftUI

struct SubscriptionPaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showsAdminUnlock = false
    @State private var adminEmail = ""
    @State private var adminPasscode = ""
    @State private var errorMessage: String?

    private var product: Product? { subscriptionService.availableProducts.first }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("散歩マップ機能")
                        .font(.title2.weight(.bold))

                    Text("次の駅までの残り距離を\n現実の散歩目標に変換。\n地図で目標地点を確認できる。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    if let product {
                        Text("\(product.displayPrice) / 月")
                            .font(.title3.weight(.semibold))
                    }

                    Button {
                        Task { await startPurchase() }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("購読を開始する")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(product == nil || isPurchasing || isRestoring)

                    Button {
                        Task { await restore() }
                    } label: {
                        if isRestoring {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("購入を復元する")
                                .font(.subheadline)
                        }
                    }
                    .disabled(isPurchasing || isRestoring)
                }

                adminUnlockSection

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            HStack(spacing: 16) {
                Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("·")
                    .foregroundStyle(.secondary)
                Link("プライバシーポリシー", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)
        }
        .task {
            await subscriptionService.loadProducts()
        }
    }

    private var adminUnlockSection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsAdminUnlock.toggle()
                }
            } label: {
                Label("管理者として解除", systemImage: "person.badge.key.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)

            if showsAdminUnlock {
                VStack(spacing: 10) {
                    TextField("管理者メールアドレス", text: $adminEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("擬似パスコード", text: $adminPasscode)
                        .textContentType(.oneTimeCode)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        unlockAdmin()
                    } label: {
                        Text("管理者権限で開く")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(adminEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || adminPasscode.isEmpty)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func startPurchase() async {
        guard let product else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            _ = try await subscriptionService.purchase(product)
        } catch {
            errorMessage = "購入処理に失敗しました。もう一度お試しください。"
        }
    }

    private func restore() async {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }
        await subscriptionService.restorePurchases()
        if case .error(let msg) = subscriptionService.status {
            errorMessage = msg
        }
    }

    private func unlockAdmin() {
        errorMessage = nil
        switch subscriptionService.unlockAdmin(email: adminEmail, passcode: adminPasscode) {
        case .unlocked:
            adminEmail = ""
            adminPasscode = ""
        case .invalidCredentials:
            errorMessage = "管理者メールアドレスまたは擬似パスコードが違います。"
        case .notConfigured:
            errorMessage = "管理者用の環境変数が設定されていません。"
        }
    }
}

#Preview {
    SubscriptionPaywallView()
        .environmentObject(SubscriptionService())
}
