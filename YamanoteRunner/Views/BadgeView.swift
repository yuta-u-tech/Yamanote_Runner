import SwiftUI

struct BadgeView: View {
    let badges: [RunnerBadge]

    init(badges: [RunnerBadge] = RunnerBadge.previewBadges) {
        self.badges = badges
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(badges) { badge in
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: badge.symbol)
                            .font(.title)
                            .foregroundStyle(badge.isUnlocked ? .green : .secondary)

                        Text(badge.title)
                            .font(.headline)
                        Text(badge.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(badge.isUnlocked ? "獲得済み" : "未獲得")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(badge.isUnlocked ? .green : .secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .navigationTitle("バッジ")
    }
}

#Preview {
    NavigationStack {
        BadgeView()
    }
}
