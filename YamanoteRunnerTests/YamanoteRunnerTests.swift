import XCTest
@testable import YamanoteRunner

final class YamanoteRunnerTests: XCTestCase {
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
    func testAppStateAddsOnlySameDayDistanceDelta() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = AppStateStore(userDefaults: userDefaults, calendar: fixedCalendar)
        let date = fixedCalendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10))!

        store.syncTodayDistance(2.0, at: date)
        store.syncTodayDistance(3.5, at: date.addingTimeInterval(60 * 60))

        XCTAssertEqual(store.cumulativeDistanceKilometers, 3.5, accuracy: 0.001)
        XCTAssertEqual(store.lastSyncedTodayDistanceKilometers, 3.5, accuracy: 0.001)
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
        XCTAssertEqual(store.lastSyncedTodayDistanceKilometers, 1.2, accuracy: 0.001)
    }

    func testRouteProgressStartsBetweenTokyoAndYurakucho() {
        let progress = YamanoteRoute.progress(for: 0.3)

        XCTAssertEqual(progress.completedLapCount, 0)
        XCTAssertEqual(progress.currentLapNumber, 1)
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
