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
                    syncEventCard
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
        await todayDistanceViewModel.loadTodayDistance(
            heightCentimeters: appStateStore.heightCentimeters
        )
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
                Text("HealthKitの歩行・ランニング距離を反映し、歩数から歩幅を計算しています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            MetricRow(
                title: "今日の歩数",
                value: todayStepCountText
            )

            MetricRow(
                title: "取得状態",
                value: todayDistanceViewModel.statusText
            )

            MetricRow(
                title: todayDistanceViewModel.isStrideEstimated ? "推定歩幅" : "実績歩幅",
                value: strideText
            )

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

    private var todayStepCountText: String {
        guard let stepCount = todayDistanceViewModel.stepCount else {
            return todayDistanceViewModel.isLoading ? "取得中" : "--歩"
        }

        return "\(stepCount.formatted())歩"
    }

    private var strideText: String {
        guard let strideMeters = todayDistanceViewModel.strideMeters else {
            return "\(Int(appStateStore.heightCentimeters))cm設定"
        }

        let centimeters = strideMeters * 100
        return "\(centimeters.formatted(.number.precision(.fractionLength(1))))cm"
    }

    @ViewBuilder
    private var syncEventCard: some View {
        if let event = appStateStore.lastDistanceSyncEvent {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    "+\(formattedKilometers(event.addedDistanceKilometers)) 進みました！",
                    systemImage: event.hasPassedStations ? "party.popper.fill" : "figure.walk"
                )
                .font(.headline)
                .foregroundStyle(event.hasPassedStations ? .green : .primary)

                if event.didCompleteLap {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("山手線一周達成！", systemImage: "medal.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.green)
                        Text("\(event.currentLapNumber)周目に突入しました！")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if event.hasPassedStations {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(event.passedStations) { station in
                            Label("\(station.name)を通過！", systemImage: "checkmark.seal.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    Text("駅通過まで少し前進しました。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("次は \(event.nextStation.name)！")
                            .font(.subheadline.weight(.semibold))
                        Text("あと\(formattedKilometers(event.distanceToNextStationKilometers))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "tram.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
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

            NavigationLink {
                StepDistanceSettingsView(appStateStore: appStateStore)
            } label: {
                ActionRow(
                    symbol: "ruler.fill",
                    title: "歩幅設定",
                    description: "身長 \(Int(appStateStore.heightCentimeters))cm"
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

private struct StepDistanceSettingsView: View {
    @ObservedObject var appStateStore: AppStateStore
    @State private var heightCentimeters: Double

    init(appStateStore: AppStateStore) {
        self.appStateStore = appStateStore
        _heightCentimeters = State(initialValue: appStateStore.heightCentimeters)
    }

    var body: some View {
        Form {
            Section("身長") {
                Stepper(
                    "\(Int(heightCentimeters))cm",
                    value: $heightCentimeters,
                    in: 100...220,
                    step: 1
                )

                MetricRow(
                    title: "推定歩幅",
                    value: "\(estimatedStrideCentimeters.formatted(.number.precision(.fractionLength(1))))cm"
                )
            }

            Section {
                Button("保存") {
                    appStateStore.saveHeightCentimeters(heightCentimeters)
                }
            }
        }
        .navigationTitle("歩幅設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var estimatedStrideCentimeters: Double {
        StepDistanceEstimator(heightCentimeters: heightCentimeters).estimatedStrideMeters * 100
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
