import SwiftUI

struct DirectionSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var appStateStore: AppStateStore
    let title: String

    var body: some View {
        List {
            Section("進行方向") {
                Button {
                    select(.inner)
                } label: {
                    directionRow(for: .inner)
                }
                .buttonStyle(.plain)

                Button {
                    select(.outer)
                } label: {
                    directionRow(for: .outer)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ direction: YamanoteRouteDirection) {
        appStateStore.saveSelectedDirection(direction)
        dismiss()
    }

    private func directionRow(for direction: YamanoteRouteDirection) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(direction.rawValue)
                    .font(.body.weight(.medium))
                Text(directionDescription(for: direction))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if appStateStore.selectedDirection == direction {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("選択")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func directionDescription(for direction: YamanoteRouteDirection) -> String {
        switch direction {
        case .inner:
            return "東京から上野・池袋方面へ進みます"
        case .outer:
            return "東京から品川・渋谷方面へ進みます"
        }
    }
}
