import SwiftUI

struct InitialSetupFlowView: View {
    let onComplete: (YamanoteStation) -> Void

    var body: some View {
        NavigationStack {
            InitialSetupView(onComplete: onComplete)
        }
    }
}

struct InitialSetupView: View {
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
    InitialSetupFlowView { _ in }
}
