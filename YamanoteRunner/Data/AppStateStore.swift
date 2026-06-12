import Foundation

@MainActor
final class AppStateStore: ObservableObject {
    @Published private(set) var hasCompletedInitialSetup: Bool
    @Published private(set) var startingStationName: String
    @Published private(set) var cumulativeDistanceKilometers: Double
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastSyncedTodayDistanceKilometers: Double
    @Published private(set) var lastAddedChallengeDistanceKilometers: Double
    @Published private(set) var lastDistanceSyncEvent: DistanceSyncEvent?
    @Published private(set) var unlockedBadgeIDs: Set<String>

    private let userDefaults: UserDefaults
    private let calendar: Calendar

    private enum Key {
        static let hasCompletedInitialSetup = "hasCompletedInitialSetup"
        static let startingStationName = "startingStation"
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
        cumulativeDistanceKilometers = userDefaults.double(forKey: Key.cumulativeDistanceKilometers)
        lastSyncedTodayDistanceKilometers = userDefaults.double(forKey: Key.lastSyncedTodayDistanceKilometers)
        lastAddedChallengeDistanceKilometers = 0
        lastDistanceSyncEvent = nil

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
            startingAt: startingStation
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

    func restartSetup() {
        hasCompletedInitialSetup = false
        userDefaults.set(false, forKey: Key.hasCompletedInitialSetup)
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
        if lastDistanceSyncEvent?.didCompleteLap == true {
            unlockBadge(RunnerBadge.fullLoopBadgeID)
        }

        userDefaults.set(cumulativeDistanceKilometers, forKey: Key.cumulativeDistanceKilometers)
        userDefaults.set(date, forKey: Key.lastSyncDate)
        userDefaults.set(normalizedTodayDistance, forKey: Key.lastSyncedTodayDistanceKilometers)
    }

    func unlockBadge(_ badgeID: String) {
        guard !unlockedBadgeIDs.contains(badgeID) else { return }
        unlockedBadgeIDs.insert(badgeID)
        userDefaults.set(Array(unlockedBadgeIDs).sorted(), forKey: Key.unlockedBadgeIDs)
    }

    private func makeDistanceSyncEvent(
        addedDistanceKilometers: Double,
        previousCumulativeDistanceKilometers: Double,
        currentCumulativeDistanceKilometers: Double
    ) -> DistanceSyncEvent {
        let progress = routeProgress
        let previousProgress = YamanoteRoute.progress(
            for: previousCumulativeDistanceKilometers,
            startingAt: startingStation
        )
        let passedStations = YamanoteRoute.passedStations(
            from: previousCumulativeDistanceKilometers,
            to: currentCumulativeDistanceKilometers,
            startingAt: startingStation
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
