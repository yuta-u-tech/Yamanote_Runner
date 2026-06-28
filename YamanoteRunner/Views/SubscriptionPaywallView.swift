import StoreKit
import SwiftUI

struct SubscriptionPaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var isPurchasing = false
    @State private var isRestoring = false
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
                Link(
                    "プライバシーポリシー",
                    destination: URL(string: "https://yuta-u-tech.github.io/Supports/apps/yamanote-runner/privacy/")!
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)
        }
        .task {
            await subscriptionService.loadProducts()
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
}

#Preview {
    SubscriptionPaywallView()
        .environmentObject(SubscriptionService())
}
