import SwiftUI

struct StationSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let selectedStation: YamanoteStation?
    let title: String
    let actionTitle: String
    let onSelect: (YamanoteStation) -> Void

    private let majorStationNames = [
        "東京",
        "新宿",
        "渋谷",
        "池袋",
        "品川",
        "上野"
    ]

    private var majorStations: [YamanoteStation] {
        YamanoteStation.all.filter {
            majorStationNames.contains($0.name)
        }
    }

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
        List {
            if searchText.isEmpty {
                Section("主要駅") {
                    ForEach(majorStations) { station in
                        stationButton(station)
                    }
                }

                Section("ランダム") {
                    Button {
                        if let station = YamanoteStation.all.randomElement() {
                            onSelect(station)
                            dismiss()
                        }
                    } label: {
                        Label("ランダムで選択", systemImage: "shuffle")
                    }
                }

                Section("全駅") {
                    ForEach(YamanoteStation.all) { station in
                        stationButton(station)
                    }
                }
            } else {
                Section("検索結果") {
                    ForEach(stations) { station in
                        stationButton(station)
                    }
                }
            }
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

    private func stationButton(_ station: YamanoteStation) -> some View {
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