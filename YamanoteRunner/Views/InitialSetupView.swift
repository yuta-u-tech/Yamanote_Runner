import SwiftUI

struct InitialSetupFlowView: View {
    let appStateStore: AppStateStore
    let onComplete: (YamanoteStation) -> Void

    var body: some View {
        NavigationStack {
            InitialSetupView(
                appStateStore: appStateStore,
                onComplete: onComplete
            )
        }
    }
}

struct InitialSetupView: View {
    @ObservedObject var appStateStore: AppStateStore
    let onComplete: (YamanoteStation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 68))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 12) {
                Text("山手線ランナー")
                    .font(.largeTitle.weight(.bold))

                Text("日々の移動を山手線の旅に変えて、一周達成を目指します。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(symbol: "point.topleft.down.curvedto.point.bottomright.up", text: "開始駅を選んでルートをスタート")
                FeatureRow(symbol: "heart.text.square", text: "移動距離との連携は今後追加予定")
                FeatureRow(symbol: "medal", text: "駅の通過とバッジ獲得を記録")
            }

            NavigationLink {
                DirectionSelectionView(appStateStore: appStateStore, title: "進行方向を選択")
            } label: {
                DirectionRow(direction: appStateStore.selectedDirection)
            }

            Spacer()

            NavigationLink {
                StationSelectionView(
                    selectedStation: nil,
                    title: "開始駅を選択",
                    actionTitle: "この駅から始める",
                    onSelect: onComplete
                )
            } label: {
                Text("はじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(24)
    }
}

private struct DirectionRow: View {
    let direction: YamanoteRouteDirection

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3)
                .frame(width: 42, height: 42)
                .background(.green.opacity(0.12))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("進行方向")
                    .font(.headline)
                Text(direction.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct FeatureRow: View {
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
    InitialSetupFlowView(appStateStore: AppStateStore()) { _ in }
}
