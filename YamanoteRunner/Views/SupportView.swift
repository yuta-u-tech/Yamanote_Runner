import SwiftUI
import UIKit

struct SupportView: View {
    @Environment(\.openURL) private var openURL

    private let supportEmail = "yutautech@gmail.com"

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero

                VStack(spacing: 10) {
                    SupportActionButton(
                        symbol: "envelope.fill",
                        title: "メールで問い合わせる",
                        message: "不具合、購入、使い方の相談はこちら",
                        tint: .green
                    ) {
                        openSupportMail()
                    }

                    SupportActionButton(
                        symbol: "heart.text.square.fill",
                        title: "ヘルスケア連携を確認",
                        message: "設定アプリでアクセス許可を見直す",
                        tint: .pink
                    ) {
                        openAppSettings()
                    }
                }

                SupportSection(title: "よくある相談") {
                    SupportFAQRow(
                        symbol: "figure.walk",
                        question: "今日の距離が反映されない",
                        answer: "ヘルスケアの歩行・ランニング距離へのアクセス許可を確認し、ホーム画面へ戻って再取得してください。"
                    )

                    SupportFAQRow(
                        symbol: "tram.fill",
                        question: "進捗の駅を変更したい",
                        answer: "設定の開始駅と進行方向を変更すると、山手線の進み方を切り替えられます。"
                    )

                    SupportFAQRow(
                        symbol: "map.fill",
                        question: "マップ機能が使えない",
                        answer: "散歩マップは購読中に利用できます。購入済みの場合は購入の復元をお試しください。"
                    )
                }

                SupportSection(title: "問い合わせに含めると助かる情報") {
                    SupportChecklistRow(text: "発生した画面と操作")
                    SupportChecklistRow(text: "表示されたエラーメッセージ")
                    SupportChecklistRow(text: "ヘルスケア距離の取得状況")
                    SupportChecklistRow(text: "購読や復元に関する相談内容")
                }

                VStack(spacing: 8) {
                    Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Link("プライバシーポリシー", destination: URL(string: "https://example.com/privacy")!)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.green.opacity(0.12),
                    Color(.systemBackground),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("サポート")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.green.opacity(0.16))
                    Image(systemName: "tram.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text("山手ランナーを快適に使うために")
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text("距離取得、進捗、購読まわりで困った時はここから確認できます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                SupportStatusPill(symbol: "clock.fill", text: "通常1〜2日で返信")
                SupportStatusPill(symbol: "shield.checkered", text: "個人情報は最小限")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.green.opacity(0.16), lineWidth: 1)
        }
    }

    private func openSupportMail() {
        let subject = "山手ランナー サポート問い合わせ"
        let body = """
        お問い合わせ内容:

        発生した画面:
        表示されたメッセージ:
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        guard let url = components.url else { return }
        openURL(url)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct SupportActionButton: View {
    let symbol: String
    let title: String
    let message: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct SupportSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                content
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SupportFAQRow: View {
    let symbol: String
    let question: String
    let answer: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(question)
                    .font(.subheadline.weight(.semibold))
                Text(answer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 46)
        }
    }
}

private struct SupportChecklistRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(12)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 42)
        }
    }
}

private struct SupportStatusPill: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.green.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        SupportView()
    }
}
