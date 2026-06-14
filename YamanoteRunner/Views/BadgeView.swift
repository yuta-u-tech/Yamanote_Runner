import SwiftUI

struct BadgeView: View {
    @State private var selectedBadge: RunnerBadge?

    private let badges: [RunnerBadge]

    init(badges: [RunnerBadge] = RunnerBadge.previewBadges) {
        self.badges = badges.filter(\.isUnlocked)
    }

    var body: some View {
        Group {
            if badges.isEmpty {
                ContentUnavailableView(
                    "獲得済みバッジはありません",
                    systemImage: "medal",
                    description: Text("駅を進めるとバッジがここに表示されます。")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 14)], spacing: 14) {
                        ForEach(badges) { badge in
                            Button {
                                selectedBadge = badge
                            } label: {
                                BadgeCard(badge: badge)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("バッジ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge)
        }
    }
}

private struct BadgeCard: View {
    let badge: RunnerBadge

    var body: some View {
        VStack(spacing: 10) {
            Image(badge.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(badge.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("獲得済み")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, minHeight: 158)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct BadgeDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let badge: RunnerBadge

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(badge.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.14), radius: 18, y: 8)

                VStack(spacing: 8) {
                    Text(badge.title)
                        .font(.title2.weight(.bold))
                    Text(badge.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Label("獲得済み", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)

                Spacer()
            }
            .padding(24)
            .navigationTitle("バッジ詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BadgeView()
    }
}
