import XCTest
@testable import YamanoteRunner

final class YamanoteRunnerTests: XCTestCase {
    func testStepDistanceEstimatorUsesDefaultHeightFallback() {
        let estimator = StepDistanceEstimator(heightCentimeters: nil)

        XCTAssertEqual(estimator.normalizedHeightCentimeters, 170, accuracy: 0.001)
        XCTAssertEqual(estimator.estimatedStrideMeters, 0.7055, accuracy: 0.001)
        XCTAssertEqual(estimator.kilometers(for: 10_000), 7.055, accuracy: 0.001)
    }

    func testStepDistanceEstimatorUsesHeightBasedStride() {
        let shortEstimator = StepDistanceEstimator(heightCentimeters: 150)
        let tallEstimator = StepDistanceEstimator(heightCentimeters: 180)

        XCTAssertLessThan(shortEstimator.kilometers(for: 10_000), tallEstimator.kilometers(for: 10_000))
        XCTAssertEqual(tallEstimator.estimatedStrideMeters, 0.747, accuracy: 0.001)
        XCTAssertEqual(tallEstimator.kilometers(for: 0), 0, accuracy: 0.001)
    }

    func testStepDistanceEstimatorCalculatesObservedStrideFromDistanceAndSteps() {
        let estimator = StepDistanceEstimator(heightCentimeters: 170)
        let stride = estimator.strideMeters(distanceKilometers: 4.2, stepCount: 6_000)

        XCTAssertFalse(stride.isEstimated)
        XCTAssertEqual(stride.meters, 0.7, accuracy: 0.001)
    }

    func testStepDistanceEstimatorFallsBackWhenObservedStrideCannotBeCalculated() {
        let estimator = StepDistanceEstimator(heightCentimeters: 180)
        let stride = estimator.strideMeters(distanceKilometers: 4.2, stepCount: 0)

        XCTAssertTrue(stride.isEstimated)
        XCTAssertEqual(stride.meters, estimator.estimatedStrideMeters, accuracy: 0.001)
    }

    @MainActor
    func testAppStatePersistsInitialSetup() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults)

        store.completeInitialSetup(with: YamanoteStation.all[3])

        let restoredStore = AppStateStore(userDefaults: userDefaults)
        XCTAssertTrue(restoredStore.hasCompletedInitialSetup)
        XCTAssertEqual(restoredStore.startingStationName, YamanoteStation.all[3].name)
        XCTAssertEqual(restoredStore.unlockedBadgeIDs, [RunnerBadge.startBadgeID])
    }

    @MainActor
    func testAppStatePersistsSelectedDirectionAndUsesItForRouteProgress() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!

        store.saveSelectedDirection(.outer)
        store.syncTodayDistance(2.4, at: date)

        let event = store.lastDistanceSyncEvent!
        XCTAssertEqual(event.passedStations.map(\.name), ["神田", "秋葉原"])
        XCTAssertEqual(event.nextStation.name, "御徒町")
        XCTAssertEqual(event.distanceToNextStationKilometers, 0.6, accuracy: 0.001)

        let restoredStore = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        XCTAssertEqual(restoredStore.selectedDirection, .outer)
        XCTAssertEqual(restoredStore.routeProgress.currentSegment.from.name, "秋葉原")
        XCTAssertEqual(restoredStore.routeProgress.currentSegment.to.name, "御徒町")
    }

    @MainActor
    func testAppStateChangingStartingStationPreservesSelectedDirection() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults)

        store.saveSelectedDirection(.outer)
        store.saveStartingStation(YamanoteStation.named("新宿")!)

        XCTAssertEqual(store.selectedDirection, .outer)
        XCTAssertEqual(store.startingStationName, "新宿")
    }

    @MainActor
    func testAppStateAddsOnlySameDayDistanceDelta() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!

        store.syncTodayDistance(2.0, at: date)
        store.syncTodayDistance(3.5, at: date.addingTimeInterval(60 * 60))

        XCTAssertEqual(store.cumulativeDistanceKilometers, 3.5, accuracy: 0.001)
        XCTAssertEqual(store.lastAddedChallengeDistanceKilometers, 1.5, accuracy: 0.001)
        XCTAssertEqual(store.lastDistanceSyncEvent!.addedDistanceKilometers, 1.5, accuracy: 0.001)
        XCTAssertEqual(store.lastSyncedTodayDistanceKilometers, 3.5, accuracy: 0.001)
    }

    @MainActor
    func testAppStateAddsOnlyPositiveDifferenceFromLastSyncedTodayDistance() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!

        store.syncTodayDistance(1.2, at: date)
        let cumulativeDistanceBeforeSecondSync = store.cumulativeDistanceKilometers
        store.syncTodayDistance(3.5, at: date.addingTimeInterval(60 * 60))

        XCTAssertEqual(
            store.cumulativeDistanceKilometers - cumulativeDistanceBeforeSecondSync,
            2.3,
            accuracy: 0.001
        )
        XCTAssertEqual(store.cumulativeDistanceKilometers, 3.5, accuracy: 0.001)
        XCTAssertEqual(store.lastAddedChallengeDistanceKilometers, 2.3, accuracy: 0.001)
        XCTAssertEqual(store.lastDistanceSyncEvent!.addedDistanceKilometers, 2.3, accuracy: 0.001)
        XCTAssertEqual(store.lastSyncedTodayDistanceKilometers, 3.5, accuracy: 0.001)
    }

    @MainActor
    func testAppStateDoesNotSubtractWhenTodayDistanceDecreases() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!

        store.syncTodayDistance(3.5, at: date)
        store.syncTodayDistance(1.2, at: date.addingTimeInterval(60 * 60))

        XCTAssertEqual(store.cumulativeDistanceKilometers, 3.5, accuracy: 0.001)
        XCTAssertEqual(store.lastAddedChallengeDistanceKilometers, 0, accuracy: 0.001)
        XCTAssertEqual(store.lastDistanceSyncEvent?.passedStations, [])
        XCTAssertEqual(store.lastSyncedTodayDistanceKilometers, 1.2, accuracy: 0.001)
    }

    @MainActor
    func testAppStateStartsNewSyncDeltaOnNextDay() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let firstDate = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 23))!
        let nextDate = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 8))!

        store.syncTodayDistance(4.0, at: firstDate)
        store.syncTodayDistance(1.2, at: nextDate)

        XCTAssertEqual(store.cumulativeDistanceKilometers, 5.2, accuracy: 0.001)
        XCTAssertEqual(store.lastAddedChallengeDistanceKilometers, 1.2, accuracy: 0.001)
        XCTAssertEqual(store.lastSyncedTodayDistanceKilometers, 1.2, accuracy: 0.001)
    }

    @MainActor
    func testAppStatePersistsDistanceSyncState() {
        let userDefaults = makeIsolatedUserDefaults()
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)

        store.syncTodayDistance(1.2, at: date)

        let restoredStore = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        restoredStore.syncTodayDistance(3.5, at: date.addingTimeInterval(60 * 60))

        XCTAssertEqual(restoredStore.cumulativeDistanceKilometers, 3.5, accuracy: 0.001)
        XCTAssertEqual(restoredStore.lastSyncedTodayDistanceKilometers, 3.5, accuracy: 0.001)
    }

    func testRouteProgressStartsBetweenTokyoAndYurakucho() {
        let progress = YamanoteRoute.progress(for: 0.3)

        XCTAssertEqual(progress.completedLapCount, 0)
        XCTAssertEqual(progress.currentLapNumber, 1)
        XCTAssertEqual(progress.startingStation.name, "東京")
        XCTAssertEqual(progress.currentSegment.from.name, "東京")
        XCTAssertEqual(progress.currentSegment.to.name, "有楽町")
        XCTAssertEqual(progress.distanceFromSegmentStartKilometers, 0.3, accuracy: 0.001)
        XCTAssertEqual(progress.distanceToNextStationKilometers, 0.5, accuracy: 0.001)
        XCTAssertEqual(progress.passedStations.map(\.name), ["東京"])
    }

    func testRouteProgressCalculatesSecondLap() {
        let progress = YamanoteRoute.progress(for: YamanoteRoute.totalDistanceKilometers + 0.4)

        XCTAssertEqual(progress.completedLapCount, 1)
        XCTAssertEqual(progress.currentLapNumber, 2)
        XCTAssertEqual(progress.distanceInCurrentLapKilometers, 0.4, accuracy: 0.001)
        XCTAssertEqual(progress.currentSegment.from.name, "東京")
        XCTAssertEqual(progress.currentSegment.to.name, "有楽町")
        XCTAssertEqual(progress.distanceToNextStationKilometers, 0.4, accuracy: 0.001)
    }

    func testRouteProgressTracksPassedStationsWithinLap() {
        let progress = YamanoteRoute.progress(for: 2.0)

        XCTAssertEqual(progress.currentSegment.from.name, "新橋")
        XCTAssertEqual(progress.currentSegment.to.name, "浜松町")
        XCTAssertEqual(progress.distanceFromSegmentStartKilometers, 0.1, accuracy: 0.001)
        XCTAssertEqual(progress.passedStations.map(\.name), ["東京", "有楽町", "新橋"])
    }

    func testRouteProgressSupportsOuterDirection() {
        let progress = YamanoteRoute.progress(for: 0.3, direction: .outer)

        XCTAssertEqual(progress.completedLapCount, 0)
        XCTAssertEqual(progress.currentLapNumber, 1)
        XCTAssertEqual(progress.startingStation.name, "東京")
        XCTAssertEqual(progress.currentSegment.from.name, "東京")
        XCTAssertEqual(progress.currentSegment.to.name, "神田")
        XCTAssertEqual(progress.distanceFromSegmentStartKilometers, 0.3, accuracy: 0.001)
        XCTAssertEqual(progress.distanceToNextStationKilometers, 1.0, accuracy: 0.001)
        XCTAssertEqual(progress.passedStations.map(\.name), ["東京"])
    }

    func testRoutePassedStationsUsesOuterDirection() {
        let passedStations = YamanoteRoute.passedStations(from: 0, to: 2.4, direction: .outer)

        XCTAssertEqual(passedStations.map(\.name), ["神田", "秋葉原"])
    }

    func testRoutePassedStationsBetweenDistances() {
        let passedStations = YamanoteRoute.passedStations(from: 0, to: 2.4)

        XCTAssertEqual(passedStations.map(\.name), ["有楽町", "新橋"])
    }

    func testRoutePassedStationsReturnsEmptyWhenNoStationWasPassed() {
        let passedStations = YamanoteRoute.passedStations(from: 0, to: 0.3)

        XCTAssertEqual(passedStations, [])
    }

    func testRouteProgressTracksRecentPassedStationsUpToFive() {
        let progress = YamanoteRoute.progress(for: 6.0)

        XCTAssertEqual(progress.recentPassedStations.map(\.name), ["有楽町", "新橋", "浜松町", "田町", "高輪ゲートウェイ"])
    }

    func testRouteProgressLimitsRecentPassedStationsToFive() {
        let progress = YamanoteRoute.progress(for: 11.0)

        XCTAssertEqual(progress.recentPassedStations.map(\.name), ["高輪ゲートウェイ", "品川", "大崎", "五反田", "目黒"])
    }

    func testRouteProgressRecentPassedStationsAreEmptyBeforeFirstStation() {
        let progress = YamanoteRoute.progress(for: 0.3)

        XCTAssertEqual(progress.recentPassedStations, [])
    }

    func testRouteProgressRecentPassedStationsFollowDirection() {
        let progress = YamanoteRoute.progress(for: 3.0, direction: .outer)

        XCTAssertEqual(progress.recentPassedStations.map(\.name), ["神田", "秋葉原", "御徒町"])
    }

    func testRouteProgressRecentPassedStationsRotateFromStartingStation() {
        let progress = YamanoteRoute.progress(
            for: 3.0,
            startingAt: YamanoteStation.named("新宿")!
        )

        XCTAssertEqual(progress.recentPassedStations.map(\.name), ["新大久保", "高田馬場"])
    }

    @MainActor
    func testAppStateCreatesDistanceSyncEventWithPassedStationsAndNextStation() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!

        store.syncTodayDistance(2.4, at: date)

        let event = store.lastDistanceSyncEvent!
        XCTAssertEqual(event.addedDistanceKilometers, 2.4, accuracy: 0.001)
        XCTAssertEqual(event.passedStations.map(\.name), ["有楽町", "新橋"])
        XCTAssertEqual(event.nextStation.name, "浜松町")
        XCTAssertEqual(event.distanceToNextStationKilometers, 0.7, accuracy: 0.001)
    }

    func testRouteProgressCompletesLapAtThirtyFourPointFiveKilometers() {
        let progress = YamanoteRoute.progress(for: 34.5)

        XCTAssertEqual(YamanoteRoute.totalDistanceKilometers, 34.5, accuracy: 0.001)
        XCTAssertEqual(progress.completedLapCount, 1)
        XCTAssertEqual(progress.currentLapNumber, 2)
        XCTAssertEqual(progress.distanceInCurrentLapKilometers, 0, accuracy: 0.001)
        XCTAssertEqual(progress.currentSegment.from.name, "東京")
        XCTAssertEqual(progress.currentSegment.to.name, "有楽町")
    }

    func testRouteProgressCompletesLapInOuterDirection() {
        let progress = YamanoteRoute.progress(for: 34.5 + 0.4, direction: .outer)

        XCTAssertEqual(progress.completedLapCount, 1)
        XCTAssertEqual(progress.currentLapNumber, 2)
        XCTAssertEqual(progress.distanceInCurrentLapKilometers, 0.4, accuracy: 0.001)
        XCTAssertEqual(progress.currentSegment.from.name, "東京")
        XCTAssertEqual(progress.currentSegment.to.name, "神田")
        XCTAssertEqual(progress.distanceToNextStationKilometers, 0.9, accuracy: 0.001)
    }

    @MainActor
    func testAppStateCreatesLapCompletionEventAndUnlocksFullLoopBadge() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!

        store.syncTodayDistance(34.5, at: date)

        let event = store.lastDistanceSyncEvent!
        XCTAssertTrue(event.didCompleteLap)
        XCTAssertEqual(event.completedLapCount, 1)
        XCTAssertEqual(event.currentLapNumber, 2)
        XCTAssertEqual(store.routeProgress.currentLapNumber, 2)
        XCTAssertTrue(store.unlockedBadgeIDs.contains(RunnerBadge.fullLoopBadgeID))
    }

    @MainActor
    func testAppStateUnlocksThreeStationsBadge() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!

        store.syncTodayDistance(3.2, at: date)

        XCTAssertTrue(store.unlockedBadgeIDs.contains(RunnerBadge.threeStationsBadgeID))
    }

    @MainActor
    func testAppStateUnlocksHalfLoopBadge() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!

        store.syncTodayDistance(17.25, at: date)

        XCTAssertTrue(store.unlockedBadgeIDs.contains(RunnerBadge.halfLoopBadgeID))
    }

    func testRouteProgressRotatesRouteFromStartingStation() {
        let progress = YamanoteRoute.progress(
            for: 1.5,
            startingAt: YamanoteStation.named("新宿")!
        )

        XCTAssertEqual(progress.startingStation.name, "新宿")
        XCTAssertEqual(progress.currentSegment.from.name, "新大久保")
        XCTAssertEqual(progress.currentSegment.to.name, "高田馬場")
        XCTAssertEqual(progress.distanceFromSegmentStartKilometers, 0.2, accuracy: 0.001)
        XCTAssertEqual(progress.distanceToNextStationKilometers, 1.2, accuracy: 0.001)
        XCTAssertEqual(progress.passedStations.map(\.name), ["新宿", "新大久保"])
    }

    @MainActor
    func testAppStateRouteProgressUsesSavedStartingStation() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults)

        store.saveStartingStation(YamanoteStation.named("渋谷")!)
        store.syncTodayDistance(1.3)

        XCTAssertEqual(store.routeProgress.startingStation.name, "渋谷")
        XCTAssertEqual(store.routeProgress.currentSegment.from.name, "原宿")
        XCTAssertEqual(store.routeProgress.currentSegment.to.name, "代々木")
    }

    @MainActor
    func testAppStatePersistsValidHeight() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults)

        XCTAssertTrue(store.saveHeightCentimeters(170.45))

        let restoredStore = AppStateStore(userDefaults: userDefaults)
        XCTAssertEqual(restoredStore.heightCentimeters!, 170.5, accuracy: 0.001)
    }

    @MainActor
    func testAppStateRejectsInvalidHeightWithoutOverwritingSavedValue() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults)

        XCTAssertTrue(store.saveHeightCentimeters(170))
        XCTAssertFalse(store.saveHeightCentimeters(90))

        XCTAssertEqual(store.heightCentimeters!, 170, accuracy: 0.001)
    }

    @MainActor
    func testAppStateCanClearHeight() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults)

        XCTAssertTrue(store.saveHeightCentimeters(170))
        XCTAssertTrue(store.saveHeightCentimeters(nil))

        let restoredStore = AppStateStore(userDefaults: userDefaults)
        XCTAssertNil(restoredStore.heightCentimeters)
    }

    @MainActor
    func testAppStateTracksDistanceRefreshState() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults)

        store.beginDistanceRefresh()
        XCTAssertEqual(store.distanceRefreshState, .loading)

        store.failDistanceRefresh(message: "error")
        XCTAssertEqual(store.distanceRefreshState, .failed(message: "error"))
    }

    func testRouteProgressClampsNegativeDistanceToStart() {
        let progress = YamanoteRoute.progress(for: -5.0)

        XCTAssertEqual(progress.totalDistanceKilometers, 0)
        XCTAssertEqual(progress.currentSegment.from.name, "東京")
        XCTAssertEqual(progress.distanceToNextStationKilometers, 0.8, accuracy: 0.001)
    }

    private var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suiteName = "YamanoteRunnerTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }
}
