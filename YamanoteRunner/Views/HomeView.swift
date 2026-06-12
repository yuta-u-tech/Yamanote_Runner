import SwiftUI

struct HomeView: View {
    @StateObject private var todayDistanceViewModel = TodayDistanceViewModel()

    @ObservedObject var appStateStore: AppStateStore

    private var routeProgress: YamanoteRouteProgress {
        appStateStore.routeProgress
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
                                await refreshTodayDistance()
                            }
                        } label: {
                            Label("距離を再取得", systemImage: "arrow.clockwise")
                        }
                        Button("初回設定をやり直す", action: appStateStore.restartSetup)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await refreshTodayDistance()
            }
        }
    }

    private func refreshTodayDistance() async {
        await todayDistanceViewModel.loadTodayDistance()
        if let distanceKilometers = todayDistanceViewModel.distanceKilometers {
            appStateStore.syncTodayDistance(distanceKilometers)
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
                    Text("今日の移動距離")
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

            Divider()

            MetricRow(
                title: "今回同期で増えた距離",
                value: "+\(formattedKilometers(appStateStore.lastAddedChallengeDistanceKilometers))"
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var todayDistanceText: String {
        guard let distanceKilometers = todayDistanceViewModel.distanceKilometers else {
            return todayDistanceViewModel.isLoading ? "取得中" : "--km"
        }

        return formattedKilometers(distanceKilometers)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("一周達成率")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(progressPercentText)
                        .font(.title2.weight(.bold))
                }

                Spacer()

                Label("山手線 \(routeProgress.currentLapNumber)周目", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.12))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }

            ProgressView(value: routeProgress.progressInCurrentLap)
                .tint(.green)

            HStack {
                VStack(alignment: .leading) {
                    Text("開始駅")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appStateStore.startingStation.name)
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("現在")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(routeProgress.currentSegment.from.name)〜\(routeProgress.currentSegment.to.name)")
                        .font(.headline)
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("累計距離")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(appStateStore.cumulativeDistanceKilometers.formatted(.number.precision(.fractionLength(2)))) km")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("次の駅まで")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("あと\(formattedKilometers(routeProgress.distanceToNextStationKilometers))")
                        .font(.subheadline.weight(.semibold))
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
                    selectedStation: appStateStore.startingStation,
                    title: "開始駅を変更",
                    actionTitle: "変更",
                    onSelect: appStateStore.saveStartingStation
                )
            } label: {
                ActionRow(
                    symbol: "tram.fill",
                    title: "開始駅を変更",
                    description: "全30駅から選択"
                )
            }

            NavigationLink {
                BadgeView(badges: RunnerBadge.all(unlockedBadgeIDs: appStateStore.unlockedBadgeIDs))
            } label: {
                ActionRow(
                    symbol: "medal.fill",
                    title: "バッジを見る",
                    description: "獲得済み \(appStateStore.unlockedBadgeIDs.count) / 4"
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var progressPercentText: String {
        routeProgress.progressInCurrentLap.formatted(.percent.precision(.fractionLength(0)))
    }

    private func formattedKilometers(_ distanceKilometers: Double) -> String {
        "\(distanceKilometers.formatted(.number.precision(.fractionLength(1))))km"
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
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
        appStateStore: AppStateStore(userDefaults: .standard)
    )
}
