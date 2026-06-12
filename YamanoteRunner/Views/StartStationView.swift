import SwiftUI

struct StartStationView: View {
    @StateObject private var viewModel = StartStationViewModel()

    private let majorStationNames = [
        "東京",
        "新宿",
        "渋谷",
        "池袋",
        "品川",
        "上野"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("主要駅") {
                    ForEach(viewModel.stations.filter {
                        majorStationNames.contains($0.name)
                    }) { station in
                        Button(station.name) {
                            viewModel.select(station)
                        }
                    }
                }

                Section("全駅") {
                    ForEach(viewModel.stations) { station in
                        Button(station.name) {
                            viewModel.select(station)
                        }
                    }
                }

                Section {
                    Button("ランダム選択") {
                        viewModel.selectRandom()
                    }
                }
            }
            .navigationTitle("出発駅を選択")
        }
    }
}