import Foundation

final class StartStationService {
    private let key = "startStationId"

    func save(id: Int) {
        UserDefaults.standard.set(id, forKey: key)
    }

    func load() -> Int {
        UserDefaults.standard.integer(forKey: key)
    }
}