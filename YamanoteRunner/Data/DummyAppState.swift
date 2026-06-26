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

        return AppStateStore(userDefaults: defaults)
    }
}
#endif
