import SwiftUI

struct MainTabView: View {
    @ObservedObject var appStateStore: AppStateStore

    var body: some View {
        TabView {
            HomeView(appStateStore: appStateStore)
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }

            NavigationStack {
                HistoryView(records: appStateStore.historyRecords)
            }
            .tabItem {
                Label("履歴", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                BadgeView(badges: RunnerBadge.all(unlockedBadgeIDs: appStateStore.unlockedBadgeIDs))
            }
            .tabItem {
                Label("バッジ", systemImage: "medal.fill")
            }
        }
        .tint(.green)
    }
}

#Preview {
    MainTabView(appStateStore: AppStateStore(userDefaults: .standard))
}
