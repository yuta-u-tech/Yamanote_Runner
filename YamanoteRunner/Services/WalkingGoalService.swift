import CoreLocation
import Foundation

struct WalkingGoalCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: WalkingGoalCategory
    let straightLineDistanceMeters: CLLocationDistance
    let distanceGapMeters: CLLocationDistance
    let address: String?
    let sourceName: String?

    static func == (lhs: WalkingGoalCandidate, rhs: WalkingGoalCandidate) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.category == rhs.category
            && lhs.straightLineDistanceMeters == rhs.straightLineDistanceMeters
            && lhs.distanceGapMeters == rhs.distanceGapMeters
            && lhs.address == rhs.address
            && lhs.sourceName == rhs.sourceName
    }
}

enum WalkingGoalCategory: String, CaseIterable, Hashable {
    case cafe
    case park
    case convenienceStore
    case landmark

    var searchQuery: String {
        switch self {
        case .cafe:
            return "カフェ"
        case .park:
            return "公園"
        case .convenienceStore:
            return "コンビニ"
        case .landmark:
            return "名所"
        }
    }

    var displayName: String {
        switch self {
        case .cafe:
            return "カフェ"
        case .park:
            return "公園"
        case .convenienceStore:
            return "コンビニ"
        case .landmark:
            return "ランドマーク"
        }
    }
}

enum WalkingGoalSearchState: Equatable {
    case idle
    case searching
    case empty
    case failed

    var message: String {
        switch self {
        case .idle:
            return "現在地の近くから、次の駅までの距離感に近い目的地を探します。"
        case .searching:
            return "候補を検索中です。"
        case .empty:
            return "距離が近い目的地候補が見つかりませんでした。"
        case .failed:
            return "候補を取得できませんでした。"
        }
    }
}

enum WalkingGuidanceStatus: Equatable {
    case idle
    case candidateSelected
    case guiding
    case arrived
    case failed
}

struct WalkingGuidanceState: Equatable {
    var status: WalkingGuidanceStatus = .idle
    var selectedCandidate: WalkingGoalCandidate?
    var initialDistanceMeters: CLLocationDistance?
    var remainingDistanceMeters: CLLocationDistance?

    var progress: Double {
        if status == .arrived {
            return 1
        }
        guard let initialDistanceMeters, let remainingDistanceMeters, initialDistanceMeters > 0 else {
            return 0
        }
        return min(1, max(0, 1 - remainingDistanceMeters / initialDistanceMeters))
    }

    mutating func select(_ candidate: WalkingGoalCandidate, from currentLocation: CLLocation) {
        selectedCandidate = candidate
        let remainingDistance = Self.distance(from: currentLocation, to: candidate)
        initialDistanceMeters = max(remainingDistance, 1)
        remainingDistanceMeters = remainingDistance
        status = .candidateSelected
    }

    mutating func start() {
        guard selectedCandidate != nil else {
            status = .failed
            return
        }
        status = .guiding
    }

    mutating func cancel() {
        status = .idle
        selectedCandidate = nil
        initialDistanceMeters = nil
        remainingDistanceMeters = nil
    }

    mutating func updateLocation(_ currentLocation: CLLocation, arrivalThresholdMeters: CLLocationDistance = 50) {
        guard let selectedCandidate else { return }
        let remainingDistance = Self.distance(from: currentLocation, to: selectedCandidate)
        remainingDistanceMeters = remainingDistance
        if initialDistanceMeters == nil {
            initialDistanceMeters = max(remainingDistance, 1)
        }
        if remainingDistance <= arrivalThresholdMeters {
            status = .arrived
        }
    }

    private static func distance(from location: CLLocation, to candidate: WalkingGoalCandidate) -> CLLocationDistance {
        location.distance(from: CLLocation(
            latitude: candidate.coordinate.latitude,
            longitude: candidate.coordinate.longitude
        ))
    }
}

enum WalkingGoalService {
    static func targetDistanceMeters(fromNextStationKilometers kilometers: Double) -> CLLocationDistance {
        max(0, kilometers * 1000)
    }

    static func searchRadiusMeters(forTargetDistanceMeters targetDistanceMeters: CLLocationDistance) -> CLLocationDistance {
        min(5_000, max(800, targetDistanceMeters * 1.8))
    }

    static func minimumCandidateDistanceMeters(forTargetDistanceMeters targetDistanceMeters: CLLocationDistance) -> CLLocationDistance {
        max(80, min(300, targetDistanceMeters * 0.25))
    }

    static func rankedCandidates(
        _ candidates: [WalkingGoalCandidate],
        targetDistanceMeters: CLLocationDistance,
        limit: Int = 6
    ) -> [WalkingGoalCandidate] {
        let minimumDistance = minimumCandidateDistanceMeters(forTargetDistanceMeters: targetDistanceMeters)
        return Array(
            candidates
                .filter { $0.straightLineDistanceMeters >= minimumDistance }
                .sorted { lhs, rhs in
                    if lhs.distanceGapMeters == rhs.distanceGapMeters {
                        return lhs.straightLineDistanceMeters < rhs.straightLineDistanceMeters
                    }
                    return lhs.distanceGapMeters < rhs.distanceGapMeters
                }
                .prefix(limit)
        )
    }
}
