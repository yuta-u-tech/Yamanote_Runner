import SwiftUI

struct HomeView: View {
    @StateObject private var todayDistanceViewModel = TodayDistanceViewModel()

    let startingStation: YamanoteStation
    let onSelectStation: (YamanoteStation) -> Void
    let onRestartSetup: () -> Void

    private let previewProgress = 0.18

    private var nextStation: YamanoteStation {
        YamanoteStation.next(after: startingStation)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    overviewHeader
                    todayDistanceCard
                    progressCard
                    actionLinks
                }
                .padding()
            }
            .navigationTitle("ホーム")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                await todayDistanceViewModel.loadTodayDistance()
                            }
                        } label: {
                            Label("距離を再取得", systemImage: "arrow.clockwise")
                        }
                        Button("初回設定をやり直す", action: onRestartSetup)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await todayDistanceViewModel.loadTodayDistance()
            }
        }
    }

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("山手線ランナー")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("毎日の移動距離を反映して、一周達成を目指します。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var todayDistanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日の距離")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(todayDistanceText)
                        .font(.title2.weight(.bold))
                }

                Spacer()

                if todayDistanceViewModel.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage = todayDistanceViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("ヘルスケアの歩行・ランニング距離を反映しています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var todayDistanceText: String {
        guard let distanceKilometers = todayDistanceViewModel.distanceKilometers else {
            return todayDistanceViewModel.isLoading ? "取得中" : "-- km"
        }

        return "\(distanceKilometers.formatted(.number.precision(.fractionLength(2)))) km"
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("一周の進捗")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("18%")
                        .font(.title2.weight(.bold))
                }

                Spacer()

                Label("仮データ", systemImage: "hammer")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.12))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }

            ProgressView(value: previewProgress)
                .tint(.green)

            HStack {
                VStack(alignment: .leading) {
                    Text("開始駅")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(startingStation.name)
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("次の駅")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(nextStation.name)
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionLinks: some View {
        VStack(spacing: 12) {
            NavigationLink {
                StationSelectionView(
                    selectedStation: startingStation,
                    title: "開始駅を変更",
                    actionTitle: "変更",
                    onSelect: onSelectStation
                )
            } label: {
                ActionRow(
                    symbol: "tram.fill",
                    title: "開始駅を変更",
                    description: "全30駅から選択"
                )
            }

            NavigationLink {
                BadgeView()
            } label: {
                ActionRow(
                    symbol: "medal.fill",
                    title: "バッジを見る",
                    description: "獲得済み 1 / 4"
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ActionRow: View {
    let symbol: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 42, height: 42)
                .background(.green.opacity(0.12))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(description)
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

#Preview {
    HomeView(
        startingStation: YamanoteStation.all[0],
        onSelectStation: { _ in },
        onRestartSetup: {}
    )
}
