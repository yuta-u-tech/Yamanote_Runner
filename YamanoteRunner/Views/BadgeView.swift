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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: 8)], spacing: 8) {
                        ForEach(badges) { badge in
                            Button {
                                selectedBadge = badge
                            } label: {
                                BadgeCard(badge: badge)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
        VStack(spacing: 6) {
            BadgeArtworkImage(imageName: badge.imageName, size: 92, cornerRadius: 8)

            Text(badge.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("獲得済み")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, minHeight: 134)
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct BadgeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let badge: RunnerBadge
    private var artworkSize: CGFloat {
        verticalSizeClass == .compact ? 150 : 228
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    BadgeArtworkImage(imageName: badge.imageName, size: artworkSize, cornerRadius: 8)
                        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)

                    VStack(spacing: 6) {
                        Text(badge.title)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(badge.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Label("獲得済み", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
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

private struct BadgeArtworkImage: View {
    let imageName: String
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    NavigationStack {
        BadgeView()
    }
}
