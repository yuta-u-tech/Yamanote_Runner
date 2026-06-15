import Foundation

enum DistanceRefreshState: Equatable {
    case idle
    case loading
    case succeeded(date: Date)
    case failed(message: String)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}

@MainActor
final class AppStateStore: ObservableObject {
    @Published private(set) var hasCompletedInitialSetup: Bool
    @Published private(set) var startingStationName: String
    @Published private(set) var selectedDirection: YamanoteRouteDirection
    @Published private(set) var heightCentimeters: Double?
    @Published private(set) var cumulativeDistanceKilometers: Double
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastSyncedTodayDistanceKilometers: Double
    @Published private(set) var lastAddedChallengeDistanceKilometers: Double
    @Published private(set) var lastDistanceSyncEvent: DistanceSyncEvent?
    @Published private(set) var distanceRefreshState: DistanceRefreshState
    @Published private(set) var unlockedBadgeIDs: Set<String>

    private let userDefaults: UserDefaults
    private let calendar: Calendar
    static let heightRangeCentimeters: ClosedRange<Double> = 100...230

    private enum Key {
        static let hasCompletedInitialSetup = "hasCompletedInitialSetup"
        static let startingStationName = "startingStation"
        static let selectedDirection = "selectedDirection"
        static let heightCentimeters = "heightCentimeters"
        static let cumulativeDistanceKilometers = "cumulativeDistanceKilometers"
        static let lastSyncDate = "lastSyncDate"
        static let lastSyncedTodayDistanceKilometers = "lastSyncedTodayDistanceKilometers"
        static let unlockedBadgeIDs = "unlockedBadgeIDs"
    }

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar

        hasCompletedInitialSetup = userDefaults.bool(forKey: Key.hasCompletedInitialSetup)
        startingStationName = userDefaults.string(forKey: Key.startingStationName) ?? "東京"
        if let selectedDirectionName = userDefaults.string(forKey: Key.selectedDirection),
            let restoredDirection = YamanoteRouteDirection(rawValue: selectedDirectionName)
        {
            selectedDirection = restoredDirection
        } else {
            selectedDirection = .inner
        }
        if userDefaults.object(forKey: Key.heightCentimeters) == nil {
            heightCentimeters = nil
        } else {
            let restoredHeight = userDefaults.double(forKey: Key.heightCentimeters)
            heightCentimeters = Self.heightRangeCentimeters.contains(restoredHeight) ? restoredHeight : nil
        }
        cumulativeDistanceKilometers = userDefaults.double(forKey: Key.cumulativeDistanceKilometers)
        lastSyncedTodayDistanceKilometers = userDefaults.double(forKey: Key.lastSyncedTodayDistanceKilometers)
        lastAddedChallengeDistanceKilometers = 0
        lastDistanceSyncEvent = nil
        distanceRefreshState = .idle

        if let lastSyncDateObject = userDefaults.object(forKey: Key.lastSyncDate) as? Date {
            lastSyncDate = lastSyncDateObject
        } else {
            lastSyncDate = nil
        }

        let badgeIDs = userDefaults.stringArray(forKey: Key.unlockedBadgeIDs) ?? []
        unlockedBadgeIDs = Set(badgeIDs)
    }

    var startingStation: YamanoteStation {
        YamanoteStation.named(startingStationName) ?? YamanoteStation.all[0]
    }

    var routeProgress: YamanoteRouteProgress {
        YamanoteRoute.progress(
            for: cumulativeDistanceKilometers,
            startingAt: startingStation,
            direction: selectedDirection
        )
    }

    func completeInitialSetup(with station: YamanoteStation) {
        saveStartingStation(station)
        unlockBadge(RunnerBadge.startBadgeID)
        hasCompletedInitialSetup = true
        userDefaults.set(true, forKey: Key.hasCompletedInitialSetup)
    }

    func saveStartingStation(_ station: YamanoteStation) {
        startingStationName = station.name
        userDefaults.set(station.name, forKey: Key.startingStationName)
    }

    func saveSelectedDirection(_ direction: YamanoteRouteDirection) {
        selectedDirection = direction
        userDefaults.set(direction.rawValue, forKey: Key.selectedDirection)
    }

    func saveHeightCentimeters(_ heightCentimeters: Double?) -> Bool {
        guard let heightCentimeters else {
            self.heightCentimeters = nil
            userDefaults.removeObject(forKey: Key.heightCentimeters)
            return true
        }

        guard Self.heightRangeCentimeters.contains(heightCentimeters) else {
            return false
        }

        let roundedHeight = (heightCentimeters * 10).rounded() / 10
        self.heightCentimeters = roundedHeight
        userDefaults.set(roundedHeight, forKey: Key.heightCentimeters)
        return true
    }

    func restartSetup() {
        hasCompletedInitialSetup = false
        userDefaults.set(false, forKey: Key.hasCompletedInitialSetup)
    }

    func beginDistanceRefresh() {
        distanceRefreshState = .loading
    }

    func syncTodayDistance(_ todayDistanceKilometers: Double, at date: Date = Date()) {
        let normalizedTodayDistance = max(0, todayDistanceKilometers)
        let additionalDistance: Double

        if let lastSyncDate, calendar.isDate(lastSyncDate, inSameDayAs: date) {
            additionalDistance = max(0, normalizedTodayDistance - lastSyncedTodayDistanceKilometers)
        } else {
            additionalDistance = normalizedTodayDistance
        }

        let previousCumulativeDistanceKilometers = cumulativeDistanceKilometers
        cumulativeDistanceKilometers += additionalDistance
        lastSyncDate = date
        lastSyncedTodayDistanceKilometers = normalizedTodayDistance
        lastAddedChallengeDistanceKilometers = additionalDistance
        lastDistanceSyncEvent = makeDistanceSyncEvent(
            addedDistanceKilometers: additionalDistance,
            previousCumulativeDistanceKilometers: previousCumulativeDistanceKilometers,
            currentCumulativeDistanceKilometers: cumulativeDistanceKilometers
        )
        updateProgressBadges()

        userDefaults.set(cumulativeDistanceKilometers, forKey: Key.cumulativeDistanceKilometers)
        userDefaults.set(date, forKey: Key.lastSyncDate)
        userDefaults.set(normalizedTodayDistance, forKey: Key.lastSyncedTodayDistanceKilometers)
        distanceRefreshState = .succeeded(date: date)
    }

    func failDistanceRefresh(message: String) {
        distanceRefreshState = .failed(message: message)
    }

    func unlockBadge(_ badgeID: String) {
        guard !unlockedBadgeIDs.contains(badgeID) else { return }
        unlockedBadgeIDs.insert(badgeID)
        userDefaults.set(Array(unlockedBadgeIDs).sorted(), forKey: Key.unlockedBadgeIDs)
    }

    private func updateProgressBadges() {
        let progress = routeProgress
        let passedStationCount = max(0, progress.passedStations.count - 1)

        if passedStationCount >= 3 {
            unlockBadge(RunnerBadge.threeStationsBadgeID)
        }

        if progress.completedLapCount > 0 || progress.distanceInCurrentLapKilometers >= YamanoteRoute.totalDistanceKilometers / 2 {
            unlockBadge(RunnerBadge.halfLoopBadgeID)
        }

        if progress.completedLapCount > 0 {
            unlockBadge(RunnerBadge.fullLoopBadgeID)
        }
    }

    private func makeDistanceSyncEvent(
        addedDistanceKilometers: Double,
        previousCumulativeDistanceKilometers: Double,
        currentCumulativeDistanceKilometers: Double
    ) -> DistanceSyncEvent {
        let progress = routeProgress
        let previousProgress = YamanoteRoute.progress(
            for: previousCumulativeDistanceKilometers,
            startingAt: startingStation,
            direction: selectedDirection
        )
        let passedStations = YamanoteRoute.passedStations(
            from: previousCumulativeDistanceKilometers,
            to: currentCumulativeDistanceKilometers,
            startingAt: startingStation,
            direction: selectedDirection
        )

        return DistanceSyncEvent(
            addedDistanceKilometers: addedDistanceKilometers,
            passedStations: passedStations,
            nextStation: progress.currentSegment.to,
            distanceToNextStationKilometers: progress.distanceToNextStationKilometers,
            completedLapCount: progress.completedLapCount - previousProgress.completedLapCount,
            currentLapNumber: progress.currentLapNumber
        )
    }
}
