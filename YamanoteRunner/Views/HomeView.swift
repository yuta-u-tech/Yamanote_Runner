import SwiftUI

struct HomeView: View {
    @StateObject private var todayDistanceViewModel = TodayDistanceViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @ObservedObject var appStateStore: AppStateStore
    @State private var dashboardPage = 0

    private var usesCompactHeightLayout: Bool {
        verticalSizeClass == .compact
    }

    private var routeProgress: YamanoteRouteProgress {
        appStateStore.routeProgress
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: usesCompactHeightLayout ? 10 : 14) {
                    if usesCompactHeightLayout {
                        HStack(alignment: .top, spacing: 12) {
                            progressDashboard
                            currentLocationPanel
                        }
                    } else {
                        progressDashboard
                        currentLocationPanel
                    }

                    actionLinks
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.12),
                        Color(.systemBackground),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(appStateStore: appStateStore)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .task {
                await refreshTodayDistance()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await refreshTodayDistance()
                }
            }
        }
    }

    private func refreshTodayDistance() async {
        guard !appStateStore.distanceRefreshState.isLoading else { return }
        appStateStore.beginDistanceRefresh()
        await todayDistanceViewModel.loadTodayDistance(
            heightCentimeters: appStateStore.heightCentimeters
        )
        if let distanceKilometers = todayDistanceViewModel.distanceKilometers {
            appStateStore.syncTodayDistance(distanceKilometers)
        } else if let errorMessage = todayDistanceViewModel.errorMessage {
            appStateStore.failDistanceRefresh(message: errorMessage)
        } else {
            appStateStore.failDistanceRefresh(message: "距離を取得できませんでした。")
        }
    }

    private var progressDashboard: some View {
        dashboardContent
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.green.opacity(0.12), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var dashboardContent: some View {
        if usesCompactHeightLayout {
            HStack(alignment: .center, spacing: 12) {
                progressRing(size: 112)
                VStack(spacing: 8) {
                    progressMetricTiles
                }
            }
        } else {
            TabView(selection: $dashboardPage) {
                statsPage.tag(0)
                lineagePage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 284)
        }
    }

    private var statsPage: some View {
        VStack(spacing: 12) {
            ProgressRing(
                progress: routeProgress.progressInCurrentLap,
                label: progressPercentText,
                caption: "\(routeProgress.currentLapNumber)周目"
            )
            .frame(width: 136, height: 136)
            .frame(maxWidth: .infinity, alignment: .center)

            progressMetricGrid
        }
        .padding(.bottom, 18)
    }

    private var lineagePage: some View {
        YamanoteLineageView(routeProgress: routeProgress)
            .padding(.bottom, 18)
    }

    @ViewBuilder
    private var progressMetricTiles: some View {
        MetricTile(
            title: "今日",
            value: todayDistanceText,
            symbol: "figure.walk"
        )

        MetricTile(
            title: "歩数",
            value: todayStepCountText,
            symbol: "shoeprints.fill"
        )

        MetricTile(
            title: "累計",
            value: formattedKilometers(appStateStore.cumulativeDistanceKilometers),
            symbol: "sum"
        )

        MetricTile(
            title: "\(routeProgress.currentLapNumber)周目",
            value: lapProgressText,
            symbol: "arrow.triangle.2.circlepath"
        )
    }

    private var progressMetricGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                MetricTile(
                    title: "今日",
                    value: todayDistanceText,
                    symbol: "figure.walk"
                )

                MetricTile(
                    title: "歩数",
                    value: todayStepCountText,
                    symbol: "shoeprints.fill"
                )
            }

            HStack(spacing: 8) {
                MetricTile(
                    title: "累計",
                    value: formattedKilometers(appStateStore.cumulativeDistanceKilometers),
                    symbol: "sum"
                )

                MetricTile(
                    title: "\(routeProgress.currentLapNumber)周目",
                    value: lapProgressText,
                    symbol: "arrow.triangle.2.circlepath"
                )
            }
        }
    }

    private func progressRing(size: CGFloat) -> some View {
        ProgressRing(
            progress: routeProgress.progressInCurrentLap,
            label: progressPercentText,
            caption: "\(routeProgress.currentLapNumber)周目"
        )
        .frame(width: size, height: size)
    }

    private var currentLocationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("現在")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(routeProgress.currentSegment.from.name)〜\(routeProgress.currentSegment.to.name)")
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("次の駅まで")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("あと\(formattedKilometers(routeProgress.distanceToNextStationKilometers))")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }

            HStack {
                Text("進行方向")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(appStateStore.selectedDirection.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            HStack(spacing: 8) {
                Label(appStateStore.startingStation.name, systemImage: "tram.fill")
                Spacer()
                Label(appStateStore.selectedDirection.rawValue, systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)

            SegmentProgressBar(
                progress: routeProgress.progressInCurrentSegment,
                fromStationName: routeProgress.currentSegment.from.name,
                toStationName: routeProgress.currentSegment.to.name,
                progressText: segmentProgressText
            )

            if let event = appStateStore.lastDistanceSyncEvent {
                SyncEventSummary(event: event, formattedKilometers: formattedKilometers)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.green.opacity(0.12), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var actionLinks: some View {
        VStack(spacing: 10) {
            NavigationLink {
                BadgeView(badges: RunnerBadge.all(unlockedBadgeIDs: appStateStore.unlockedBadgeIDs))
            } label: {
                CompactActionButton(symbol: "medal.fill", title: "バッジ")
            }

            NavigationLink {
                HistoryView(records: appStateStore.historyRecords)
            } label: {
                CompactActionButton(symbol: "clock.arrow.circlepath", title: "履歴")
            }
        }
        .buttonStyle(.plain)
    }

    private var todayDistanceText: String {
        guard let distanceKilometers = todayDistanceViewModel.distanceKilometers else {
            return appStateStore.distanceRefreshState.isLoading ? "取得中" : "--km"
        }

        return formattedKilometers(distanceKilometers)
    }

    private var todayStepCountText: String {
        guard let stepCount = todayDistanceViewModel.stepCount else {
            return appStateStore.distanceRefreshState.isLoading ? "取得中" : "--歩"
        }

        return "\(stepCount.formatted())歩"
    }

    private var strideText: String {
        guard let strideMeters = todayDistanceViewModel.strideMeters else {
            let fallbackStride = StepDistanceEstimator(
                heightCentimeters: appStateStore.heightCentimeters
            ).estimatedStrideMeters
            return "\((fallbackStride * 100).formatted(.number.precision(.fractionLength(1))))cm"
        }

        let centimeters = strideMeters * 100
        return "\(centimeters.formatted(.number.precision(.fractionLength(1))))cm"
    }

    private var progressPercentText: String {
        routeProgress.progressInCurrentLap.formatted(.percent.precision(.fractionLength(0)))
    }

    private var segmentProgressText: String {
        routeProgress.progressInCurrentSegment.formatted(.percent.precision(.fractionLength(0)))
    }

    private var lapProgressText: String {
        routeProgress.progressInCurrentLap.formatted(.percent.precision(.fractionLength(0)))
    }

    private func formattedKilometers(_ distanceKilometers: Double) -> String {
        "\(distanceKilometers.formatted(.number.precision(.fractionLength(1))))km"
    }
}

private struct ProgressRing: View {
    let progress: Double
    let label: String
    let caption: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.green.opacity(0.14), lineWidth: 13)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("一周達成率 \(label)、\(caption)")
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(.green.opacity(0.12))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .padding(.horizontal, 8)
        .background(.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SegmentProgressBar: View {
    let progress: Double
    let fromStationName: String
    let toStationName: String
    let progressText: String

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("区間達成率")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(progressText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }

            GeometryReader { proxy in
                let trackWidth = proxy.size.width
                let markerOffset = max(0, min(trackWidth - 18, trackWidth * clampedProgress - 9))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.green.opacity(0.14))
                        .frame(height: 8)

                    Capsule()
                        .fill(.green)
                        .frame(width: max(8, trackWidth * clampedProgress), height: 8)

                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.green)
                        .background(.background, in: Circle())
                        .offset(x: markerOffset)
                }
                .frame(height: 22)
            }
            .frame(height: 22)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("0%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(fromStationName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("100%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(toStationName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(10)
        .background(.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(fromStationName)から\(toStationName)までの区間達成率 \(progressText)")
    }
}

private struct SyncEventSummary: View {
    let event: DistanceSyncEvent
    let formattedKilometers: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Label(
                eventTitle,
                systemImage: event.didCompleteLap ? "medal.fill" : event.hasPassedStations ? "checkmark.seal.fill" : "figure.walk"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(event.didCompleteLap || event.hasPassedStations ? .green : .secondary)

            if event.hasPassedStations {
                Text(event.passedStations.map { "\($0.name)通過" }.joined(separator: " / "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var eventTitle: String {
        if event.didCompleteLap {
            return "山手線一周達成、\(event.currentLapNumber)周目へ"
        }

        if event.hasPassedStations {
            return "+\(formattedKilometers(event.addedDistanceKilometers)) 区間が更新されました"
        }

        return "現在区間を進行中"
    }
}

private struct CompactActionButton: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.headline)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(.regularMaterial)
        .foregroundStyle(.primary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.green.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct HistoryView: View {
    let records: [DailyRunHistoryRecord]

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(
                    "履歴はまだありません",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("ヘルスケア距離を同期すると、日別の記録がここに表示されます。")
                )
            } else {
                ForEach(records) { record in
                    HistoryRecordRow(record: record)
                }
            }
        }
        .navigationTitle("履歴")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HistoryRecordRow: View {
    let record: DailyRunHistoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)

                Spacer()

                Text(formattedKilometers(record.distanceKilometers))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }

            HStack(spacing: 8) {
                Label(record.reachedStationName, systemImage: "tram.fill")
                Spacer()
                Label("\(record.currentLapNumber)周目", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)

            if !record.passedStationNames.isEmpty {
                Text(record.passedStationNames.map { "\($0)通過" }.joined(separator: " / "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedKilometers(_ distanceKilometers: Double) -> String {
        "\(distanceKilometers.formatted(.number.precision(.fractionLength(1))))km"
    }
}

private struct SettingsView: View {
    @ObservedObject var appStateStore: AppStateStore
    @State private var heightText = ""
    @State private var heightError: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("身長", systemImage: "ruler")
                    Spacer()
                    TextField("未設定", text: $heightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 96)
                    Text("cm")
                        .foregroundStyle(.secondary)
                }

                if let heightError {
                    Text(heightError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("身長を保存") {
                    saveHeight()
                }
            } header: {
                Text("ユーザー情報")
            } footer: {
                Text("身長は、歩数または距離が0で実績歩幅を計算できない場合の推定歩幅表示にだけ使います。山手線の進捗距離はHealthKitの歩行・ランニング距離を使用します。")
            }

            Section("進捗設定") {
                NavigationLink {
                    StationSelectionView(
                        selectedStation: appStateStore.startingStation,
                        title: "開始駅を変更",
                        actionTitle: "変更",
                        onSelect: appStateStore.saveStartingStation
                    )
                } label: {
                    SettingsValueRow(
                        symbol: "tram.fill",
                        title: "開始駅",
                        value: appStateStore.startingStation.name
                    )
                }

                NavigationLink {
                    DirectionSelectionView(
                        appStateStore: appStateStore,
                        title: "進行方向を変更"
                    )
                } label: {
                    SettingsValueRow(
                        symbol: "arrow.triangle.2.circlepath",
                        title: "進行方向",
                        value: appStateStore.selectedDirection.rawValue
                    )
                }
            }

            Section("ヘルスケア") {
                SettingsValueRow(
                    symbol: "heart.fill",
                    title: "距離データ",
                    value: distanceStatusText
                )

                SettingsValueRow(
                    symbol: "clock",
                    title: "最終更新",
                    value: lastRefreshText
                )
            }

            Section {
                Button("初回設定をやり直す", role: .destructive) {
                    appStateStore.restartSetup()
                }
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            heightText = appStateStore.heightCentimeters.map {
                $0.formatted(.number.precision(.fractionLength(0...1)))
            } ?? ""
        }
    }

    private var distanceStatusText: String {
        switch appStateStore.distanceRefreshState {
        case .idle:
            return "未取得"
        case .loading:
            return "更新中"
        case .succeeded:
            return "取得済み"
        case .failed:
            return "確認が必要"
        }
    }

    private var lastRefreshText: String {
        guard let lastSyncDate = appStateStore.lastSyncDate else {
            return "未取得"
        }

        return lastSyncDate.formatted(date: .omitted, time: .shortened)
    }

    private func saveHeight() {
        let trimmedText = heightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            _ = appStateStore.saveHeightCentimeters(nil)
            heightError = nil
            return
        }

        guard let heightCentimeters = Double(trimmedText) else {
            heightError = "数値で入力してください。"
            return
        }

        guard appStateStore.saveHeightCentimeters(heightCentimeters) else {
            let range = AppStateStore.heightRangeCentimeters
            heightError = "\(Int(range.lowerBound))〜\(Int(range.upperBound))cm の範囲で入力してください。"
            return
        }

        heightText = appStateStore.heightCentimeters.map {
            $0.formatted(.number.precision(.fractionLength(0...1)))
        } ?? ""
        heightError = nil
    }
}

private struct SettingsValueRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: symbol)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

#Preview {
    HomeView(
        appStateStore: AppStateStore(userDefaults: .standard)
    )
}
