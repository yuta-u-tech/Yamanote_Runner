import Foundation

struct RunnerBadge: Identifiable {
    let title: String
    let description: String
    let symbol: String
    let isUnlocked: Bool

    var id: String { title }

    static let previewBadges: [RunnerBadge] = [
        .init(title: "スタートライン", description: "開始駅を設定する", symbol: "flag.checkered", isUnlocked: true),
        .init(title: "3駅通過", description: "3つの駅を通過する", symbol: "figure.run", isUnlocked: false),
        .init(title: "半周達成", description: "山手線ルートの半分を進む", symbol: "circle.lefthalf.filled", isUnlocked: false),
        .init(title: "一周ランナー", description: "山手線を一周する", symbol: "medal.fill", isUnlocked: false)
    ]
}
