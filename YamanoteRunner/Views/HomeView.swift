import SwiftUI

struct HomeView: View {
    @StateObject private var todayDistanceViewModel = TodayDistanceViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @ObservedObject var appStateStore: AppStateStore
    @State private var progressDisplayMode: ProgressDisplayMode = .percent

    private var usesCompactHeightLayout: Bool {
        verticalSizeClass == .compact
    }

    private var routeProgress: YamanoteRouteProgress {
        appStateStore.routeProgress
    }

    var body: some View {
        NavigationStack {
            Group {
                if usesCompactHeightLayout {
                    compactLayout
                } else {
                    portraitLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var portraitLayout: some View {
        GeometryReader { geo in
            let ringSize = min(200, geo.size.height * 0.30)

            VStack(spacing: 12) {
                ProgressRing(
                    progress: routeProgress.progressInCurrentLap,
                    label: progressRingLabel,
                    caption: progressRingCaption,
                    accessibilityLabel: progressRingAccessibilityLabel
                )
                .onTapGesture { toggleProgressDisplayMode() }
                .frame(width: ringSize, height: ringSize)

                HStack(spacing: 10) {
                    MetricTile(title: "今日", value: todayDistanceText, symbol: "figure.walk")
                    MetricTile(title: "累計", value: formattedKilometers(appStateStore.cumulativeDistanceKilometers), symbol: "sum")
                }

                locationCard
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    private var compactLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            ProgressRing(
                progress: routeProgress.progressInCurrentLap,
                label: progressRingLabel,
                caption: progressRingCaption,
                accessibilityLabel: progressRingAccessibilityLabel
            )
            .onTapGesture { toggleProgressDisplayMode() }
            .frame(width: 110, height: 110)

            VStack(spacing: 10) {
                locationCard

                HStack(spacing: 8) {
                    MetricTile(title: "今日", value: todayDistanceText, symbol: "figure.walk")
                    MetricTile(title: "累計", value: formattedKilometers(appStateStore.cumulativeDistanceKilometers), symbol: "sum")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func refreshTodayDistance() async {
        guard !appStateStore.distanceRefreshState.isLoading else { return }
        appStateStore.beginDistanceRefresh()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dummy") {
            todayDistanceViewModel.loadDummyData(distanceKilometers: 3.2, stepCount: 4200)
            appStateStore.syncTodayDistance(3.2)
            return
        }
        #endif

        await todayDistanceViewModel.loadTodayDistance(
            heightCentimeters: appStateStore.heightCentimeters
        )
        if let distanceKilometers = todayDistanceViewModel.distanceKilometers {
            appStateStore.syncTodayDistance(distanceKilometers)
            appStateStore.syncHistoryRecords(todayDistanceViewModel.recentDailyDistances)
        } else if let errorMessage = todayDistanceViewModel.errorMessage {
            appStateStore.failDistanceRefresh(message: errorMessage)
        } else {
            appStateStore.failDistanceRefresh(message: "距離を取得できませんでした。")
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            stationHeader
                .padding(.bottom, 12)

            SegmentProgressBar(
                progress: routeProgress.progressInCurrentSegment,
                fromStationName: routeProgress.currentSegment.from.name,
                toStationName: routeProgress.currentSegment.to.name,
                progressText: segmentProgressText
            )

            if let event = appStateStore.lastDistanceSyncEvent {
                SyncEventSummary(event: event, formattedKilometers: formattedKilometers)
                    .padding(.top, 4)
            }

            Divider()
                .padding(.top, 8)

            StationScrollList(
                entries: stationEntries(),
                nextStationID: routeProgress.currentSegment.to.id
            )
            .frame(maxHeight: .infinity)

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "tram.fill")
                    .font(.caption2)
                Text(appStateStore.startingStation.name)
                Text("·")
                Text(appStateStore.selectedDirection.rawValue)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 8)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.green.opacity(0.12), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
    }

    private func stationEntries() -> [StationListEntry] {
        let allStations = YamanoteRoute.allStations(
            startingAt: appStateStore.startingStation,
            direction: appStateStore.selectedDirection
        )
        let passedSet = Set(routeProgress.passedStations.map(\.id))
        let nextID = routeProgress.currentSegment.to.id

        return allStations.map { station in
            let status: StationStatus
            if passedSet.contains(station.id) {
                status = .passed
            } else if station.id == nextID {
                status = .next
            } else {
                status = .upcoming
            }
            return StationListEntry(station: station, status: status)
        }
    }

    private var stationHeader: some View {
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
    }

    private var todayDistanceText: String {
        guard let distanceKilometers = todayDistanceViewModel.distanceKilometers else {
            return appStateStore.distanceRefreshState.isLoading ? "取得中" : "--km"
        }

        return formattedKilometers(distanceKilometers)
    }

    private var progressPercentText: String {
        routeProgress.progressInCurrentLap.formatted(.percent.precision(.fractionLength(0)))
    }

    private var passedStationsFractionText: String {
        "\(passedStationCountInCurrentLap) / \(YamanoteStation.all.count)"
    }

    private var passedStationCountInCurrentLap: Int {
        max(0, routeProgress.passedStations.count - 1)
    }

    private var progressRingLabel: String {
        switch progressDisplayMode {
        case .percent:
            return progressPercentText
        case .stations:
            return passedStationsFractionText
        }
    }

    private var progressRingCaption: String {
        switch progressDisplayMode {
        case .percent:
            return "\(routeProgress.currentLapNumber)周目"
        case .stations:
            return "通過駅"
        }
    }

    private var progressRingAccessibilityLabel: String {
        switch progressDisplayMode {
        case .percent:
            return "一周達成率 \(progressPercentText)、\(routeProgress.currentLapNumber)周目。タップで通過駅数を表示"
        case .stations:
            return "通過駅数 \(passedStationsFractionText)。タップで達成率を表示"
        }
    }

    private var segmentProgressText: String {
        routeProgress.progressInCurrentSegment.formatted(.percent.precision(.fractionLength(0)))
    }

    private func formattedKilometers(_ distanceKilometers: Double) -> String {
        "\(distanceKilometers.formatted(.number.precision(.fractionLength(1))))km"
    }

    private func toggleProgressDisplayMode() {
        progressDisplayMode = progressDisplayMode == .percent ? .stations : .percent
    }
}

private enum ProgressDisplayMode {
    case percent
    case stations
}

private struct ProgressRing: View {
    let progress: Double
    let label: String
    let caption: String
    let accessibilityLabel: String

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
        .accessibilityLabel(accessibilityLabel)
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

private enum StationStatus {
    case passed, next, upcoming
}

private struct StationListEntry: Identifiable {
    let station: YamanoteStation
    let status: StationStatus
    var id: String { station.id }
}

private struct StationScrollList: View {
    let entries: [StationListEntry]
    let nextStationID: String

    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        StationRow(entry: entry)
                            .id(entry.id)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in resetTask?.cancel() }
                    .onEnded { _ in scheduleReset(proxy: proxy) }
            )
            .task {
                try? await Task.sleep(for: .milliseconds(80))
                proxy.scrollTo(nextStationID, anchor: .center)
            }
            .onChange(of: nextStationID) { _, id in
                withAnimation {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func scheduleReset(proxy: ScrollViewProxy) {
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.6)) {
                    proxy.scrollTo(nextStationID, anchor: .center)
                }
            }
        }
    }
}

private struct StationRow: View {
    let entry: StationListEntry

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(entry.station.name)
                .font(entry.status == .next ? .caption.weight(.bold) : .caption)
                .foregroundStyle(entry.status == .passed ? .secondary : .primary)
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(rowBackground)
    }

    private var dotColor: Color {
        switch entry.status {
        case .passed:   return Color(.systemGray3)
        case .next:     return .green
        case .upcoming: return Color(.systemGray4)
        }
    }

    private var rowBackground: Color {
        switch entry.status {
        case .passed:   return Color(.systemGray6)
        case .next:     return Color.green.opacity(0.12)
        case .upcoming: return .clear
        }
    }
}

#Preview {
    HomeView(
        appStateStore: AppStateStore(userDefaults: .standard)
    )
}
