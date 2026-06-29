#if DEBUG
import Foundation

extension AppStateStore {
    static func makeDummy() -> AppStateStore {
        let suiteName = "com.yamanoterunner.dummy"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        defaults.set(true, forKey: "hasCompletedInitialSetup")
        defaults.set("渋谷", forKey: "startingStation")
        defaults.set("内回り", forKey: "selectedDirection")
        // 18.0km 内回り渋谷スタート → 上野〜鶯谷間 (52%)
        defaults.set(18.0, forKey: "cumulativeDistanceKilometers")
        defaults.set(3.2, forKey: "lastSyncedTodayDistanceKilometers")
        defaults.set(Date(), forKey: "lastSyncDate")
        defaults.set(
            [
                RunnerBadge.startBadgeID,
                RunnerBadge.threeStationsBadgeID,
                RunnerBadge.halfLoopBadgeID
            ],
            forKey: "unlockedBadgeIDs"
        )

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let distances = [3.2, 2.8, 1.9, 3.6, 2.4, 1.7, 2.9]
        let historyRecords = distances.enumerated().compactMap { offset, distance -> DailyRunHistoryRecord? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyRunHistoryRecord(
                id: String(Int(date.timeIntervalSince1970)),
                date: date,
                distanceKilometers: distance,
                stepCount: Int(distance * 1_350),
                passedStationNames: offset == 0 ? ["上野", "鶯谷"] : [],
                reachedStationName: offset == 0 ? "鶯谷" : "上野",
                currentLapNumber: 1,
                updatedAt: date
            )
        }
        if let historyData = try? JSONEncoder().encode(historyRecords) {
            defaults.set(historyData, forKey: "historyRecords")
        }

        return AppStateStore(userDefaults: defaults)
    }
}
#endif
