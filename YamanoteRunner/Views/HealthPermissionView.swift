import SwiftUI

struct HealthPermissionView: View {
    let authorizationState: HealthKitAuthorizationState
    let requestAuthorization: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.largeTitle.weight(.bold))

                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if authorizationState == .denied {
                VStack(alignment: .leading, spacing: 12) {
                    PermissionGuideRow(symbol: "gearshape", text: "設定アプリを開く")
                    PermissionGuideRow(symbol: "heart.text.square", text: "ヘルスケアのデータアクセスを許可")
                    PermissionGuideRow(symbol: "figure.walk", text: "歩行・ランニング距離をオン")
                }
            }

            Spacer()

            Button {
                Task {
                    await requestAuthorization()
                }
            } label: {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(authorizationState == .requesting || authorizationState == .unavailable)
        }
        .padding(24)
        .task {
            if authorizationState == .notDetermined {
                await requestAuthorization()
            }
        }
    }

    private var title: String {
        switch authorizationState {
        case .unavailable:
            "HealthKitを利用できません"
        case .denied:
            "ヘルスケア連携がオフです"
        default:
            "ヘルスケア連携"
        }
    }

    private var message: String {
        switch authorizationState {
        case .unavailable:
            "この端末ではヘルスケアデータを利用できません。対応端末で確認してください。"
        case .denied:
            "歩行・ランニング距離を反映するには、設定からヘルスケアの読み取りを許可してください。"
        case .requesting:
            "歩行・ランニング距離の読み取り権限を確認しています。"
        default:
            "毎日の歩行・ランニング距離を山手線一周の進捗に反映します。"
        }
    }

    private var buttonTitle: String {
        switch authorizationState {
        case .denied:
            "もう一度確認する"
        case .requesting:
            "確認中"
        default:
            "HealthKit連携を許可"
        }
    }

    private var iconName: String {
        authorizationState == .denied ? "exclamationmark.circle.fill" : "heart.text.square.fill"
    }

    private var iconColor: Color {
        authorizationState == .denied ? .orange : .green
    }
}

private struct PermissionGuideRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .frame(width: 26)
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    HealthPermissionView(authorizationState: .notDetermined) {}
}
