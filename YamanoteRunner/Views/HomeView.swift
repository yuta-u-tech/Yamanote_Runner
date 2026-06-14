import SwiftUI

struct HomeView: View {
    @StateObject private var todayDistanceViewModel = TodayDistanceViewModel()

    @ObservedObject var appStateStore: AppStateStore

    private var routeProgress: YamanoteRouteProgress {
        appStateStore.routeProgress
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                progressDashboard
                currentLocationPanel
                actionLinks
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 10)
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
            .toolbarTitleDisplayMode(.inline)
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

    private var progressDashboard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ProgressRing(
                    progress: routeProgress.progressInCurrentLap,
                    label: progressPercentText,
                    caption: "\(routeProgress.currentLapNumber)周目"
                )
                .frame(width: 136, height: 136)

                VStack(spacing: 8) {
                    MetricTile(
                        title: "今日",
                        value: todayDistanceText,
                        symbol: "figure.walk"
                    )

                    MetricTile(
                        title: "今回",
                        value: "+\(formattedKilometers(appStateStore.lastAddedChallengeDistanceKilometers))",
                        symbol: "plus.circle"
                    )

                    MetricTile(
                        title: "累計",
                        value: formattedKilometers(appStateStore.cumulativeDistanceKilometers),
                        symbol: "sum"
                    )
                }
            }

            if let errorMessage = todayDistanceViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.green.opacity(0.12), lineWidth: 1)
        }
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
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("次の駅まで")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("あと\(formattedKilometers(routeProgress.distanceToNextStationKilometers))")
                        .font(.headline)
                }
            }

            HStack(spacing: 8) {
                Label(appStateStore.startingStation.name, systemImage: "tram.fill")
                Spacer()
                Label("山手線 \(routeProgress.currentLapNumber)周目", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)

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
    }

    private var actionLinks: some View {
        HStack(spacing: 12) {
            NavigationLink {
                StationSelectionView(
                    selectedStation: appStateStore.startingStation,
                    title: "開始駅を変更",
                    actionTitle: "変更",
                    onSelect: appStateStore.saveStartingStation
                )
            } label: {
                CompactActionButton(symbol: "tram.fill", title: "開始駅")
            }

            NavigationLink {
                BadgeView(badges: RunnerBadge.all(unlockedBadgeIDs: appStateStore.unlockedBadgeIDs))
            } label: {
                CompactActionButton(symbol: "medal.fill", title: "バッジ \(appStateStore.unlockedBadgeIDs.count)")
            }
        }
        .buttonStyle(.plain)
    }

    private var todayDistanceText: String {
        guard let distanceKilometers = todayDistanceViewModel.distanceKilometers else {
            return todayDistanceViewModel.isLoading ? "取得中" : "--km"
        }

        return formattedKilometers(distanceKilometers)
    }

    private var progressPercentText: String {
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
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .padding(.horizontal, 8)
        .background(.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            return "+\(formattedKilometers(event.addedDistanceKilometers)) 進みました"
        }

        return "駅通過まで少し前進"
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

#Preview {
    HomeView(
        appStateStore: AppStateStore(userDefaults: .standard)
    )
}
