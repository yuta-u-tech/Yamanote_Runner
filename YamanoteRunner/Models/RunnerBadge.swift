import Foundation

struct RunnerBadge: Identifiable {
    let id: String
    let title: String
    let description: String
    let symbol: String
    let imageName: String
    let isUnlocked: Bool

    static let startBadgeID = "start-line"
    static let fullLoopBadgeID = "full-loop"

    static func all(unlockedBadgeIDs: Set<String>) -> [RunnerBadge] {
        [
            .init(
                id: startBadgeID,
                title: "スタートライン",
                description: "開始駅を設定する",
                symbol: "flag.checkered",
                imageName: "badge_start_line",
                isUnlocked: unlockedBadgeIDs.contains(startBadgeID)
            ),
            .init(
                id: "three-stations",
                title: "3駅通過",
                description: "3つの駅を通過する",
                symbol: "figure.run",
                imageName: "badge_three_stations",
                isUnlocked: unlockedBadgeIDs.contains("three-stations")
            ),
            .init(
                id: "half-loop",
                title: "半周達成",
                description: "山手線ルートの半分を進む",
                symbol: "circle.lefthalf.filled",
                imageName: "badge_half_loop",
                isUnlocked: unlockedBadgeIDs.contains("half-loop")
            ),
            .init(
                id: fullLoopBadgeID,
                title: "一周ランナー",
                description: "山手線を一周する",
                symbol: "medal.fill",
                imageName: "badge_full_loop",
                isUnlocked: unlockedBadgeIDs.contains(fullLoopBadgeID)
            )
        ]
    }

    static let previewBadges: [RunnerBadge] = [
        .init(id: startBadgeID, title: "スタートライン", description: "開始駅を設定する", symbol: "flag.checkered", imageName: "badge_start_line", isUnlocked: true),
        .init(id: "three-stations", title: "3駅通過", description: "3つの駅を通過する", symbol: "figure.run", imageName: "badge_three_stations", isUnlocked: false),
        .init(id: "half-loop", title: "半周達成", description: "山手線ルートの半分を進む", symbol: "circle.lefthalf.filled", imageName: "badge_half_loop", isUnlocked: false),
        .init(id: "full-loop", title: "一周ランナー", description: "山手線を一周する", symbol: "medal.fill", imageName: "badge_full_loop", isUnlocked: false)
    ]
}
