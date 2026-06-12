import Foundation

@MainActor
final class StartStationViewModel: ObservableObject {
    @Published var selectedStation: Station?

    private let service = StartStationService()

    let stations = YamanoteStations.all

    init() {
        load()
    }

    func load() {
        let id = service.load()
        selectedStation = stations.first { $0.id == id } ?? stations[0]
    }

    func select(_ station: Station) {
        selectedStation = station
        service.save(id: station.id)
    }

    func selectRandom() {
        if let station = stations.randomElement() {
            select(station)
        }
    }

    var rotatedStations: [Station] {
        guard let station = selectedStation else {
            return stations
        }

        return StationRotation.rotate(
            stations: stations,
            startId: station.id
        )
    }
}