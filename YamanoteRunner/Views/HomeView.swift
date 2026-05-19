import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("山手線ランナー")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("日々の移動距離を山手線の進捗に変換して、駅を通過しながら一周達成を目指します。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ProgressView(value: 0.18)
                        .tint(.green)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("現在地")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("東京駅付近")
                                .font(.headline)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("次の駅まで")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("1.2 km")
                                .font(.headline)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()
            }
            .padding()
            .navigationTitle("ホーム")
        }
    }
}

#Preview {
    HomeView()
}
