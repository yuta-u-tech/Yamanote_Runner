enum StationRotation {
    static func rotate(stations: [Station], startId: Int) -> [Station] {
        guard let index = stations.firstIndex(where: { $0.id == startId }) else {
            return stations
        }

        return Array(stations[index...]) + Array(stations[..<index])
    }
}