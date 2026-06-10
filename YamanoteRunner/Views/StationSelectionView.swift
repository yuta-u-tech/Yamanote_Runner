import SwiftUI

struct StationSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let selectedStation: YamanoteStation?
    let title: String
    let actionTitle: String
    let onSelect: (YamanoteStation) -> Void

    private var stations: [YamanoteStation] {
        if searchText.isEmpty {
            return YamanoteStation.all
        }

        return YamanoteStation.all.filter {
            $0.name.localizedStandardContains(searchText)
                || $0.neighborhood.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        List(stations) { station in
            Button {
                onSelect(station)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(station.name)
                            .font(.body.weight(.medium))
                        Text(station.neighborhood)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if station == selectedStation {
                        Label("設定中", systemImage: "checkmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.green)
                    } else {
                        Text(actionTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "駅名で検索")
        .overlay {
            if stations.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}

#Preview {
    NavigationStack {
        StationSelectionView(
            selectedStation: YamanoteStation.all[0],
            title: "開始駅を選択",
            actionTitle: "選択"
        ) { _ in }
    }
}
