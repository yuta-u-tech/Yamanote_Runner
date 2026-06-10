import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedInitialSetup") private var hasCompletedInitialSetup = false
    @AppStorage("startingStation") private var startingStationName = "東京"

    private var startingStation: YamanoteStation {
        YamanoteStation.named(startingStationName) ?? YamanoteStation.all[0]
    }

    var body: some View {
        if hasCompletedInitialSetup {
            HomeView(
                startingStation: startingStation,
                onSelectStation: saveStartingStation,
                onRestartSetup: restartSetup
            )
        } else {
            InitialSetupFlowView(onComplete: completeSetup)
        }
    }

    private func completeSetup(with station: YamanoteStation) {
        saveStartingStation(station)
        hasCompletedInitialSetup = true
    }

    private func saveStartingStation(_ station: YamanoteStation) {
        startingStationName = station.name
    }

    private func restartSetup() {
        hasCompletedInitialSetup = false
    }
}

#Preview {
    RootView()
}
