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
            BadgeArtworkImage(imageName: badge.imageName, size: 94, cornerRadius: 18)

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
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let badge: RunnerBadge
    private var artworkSize: CGFloat {
        verticalSizeClass == .compact ? 160 : 260
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    BadgeArtworkImage(imageName: badge.imageName, size: artworkSize, cornerRadius: 30)
                        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)

                    VStack(spacing: 8) {
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
                .padding(24)
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
