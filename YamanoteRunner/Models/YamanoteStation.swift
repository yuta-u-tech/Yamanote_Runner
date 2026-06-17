import Foundation

struct YamanoteStation: Identifiable, Hashable {
    let name: String
    let neighborhood: String

    var id: String { name }

    static let all: [YamanoteStation] = [
        .init(name: "東京", neighborhood: "丸の内"),
        .init(name: "神田", neighborhood: "神田"),
        .init(name: "秋葉原", neighborhood: "電気街"),
        .init(name: "御徒町", neighborhood: "上野広小路"),
        .init(name: "上野", neighborhood: "上野公園"),
        .init(name: "鶯谷", neighborhood: "根岸"),
        .init(name: "日暮里", neighborhood: "谷中"),
        .init(name: "西日暮里", neighborhood: "道灌山"),
        .init(name: "田端", neighborhood: "田端"),
        .init(name: "駒込", neighborhood: "六義園"),
        .init(name: "巣鴨", neighborhood: "地蔵通り"),
        .init(name: "大塚", neighborhood: "南大塚"),
        .init(name: "池袋", neighborhood: "東口"),
        .init(name: "目白", neighborhood: "目白"),
        .init(name: "高田馬場", neighborhood: "早稲田口"),
        .init(name: "新大久保", neighborhood: "大久保"),
        .init(name: "新宿", neighborhood: "南口"),
        .init(name: "代々木", neighborhood: "代々木"),
        .init(name: "原宿", neighborhood: "表参道口"),
        .init(name: "渋谷", neighborhood: "ハチ公口"),
        .init(name: "恵比寿", neighborhood: "恵比寿"),
        .init(name: "目黒", neighborhood: "権之助坂"),
        .init(name: "五反田", neighborhood: "西五反田"),
        .init(name: "大崎", neighborhood: "大崎"),
        .init(name: "品川", neighborhood: "港南口"),
        .init(name: "高輪ゲートウェイ", neighborhood: "高輪"),
        .init(name: "田町", neighborhood: "芝浦"),
        .init(name: "浜松町", neighborhood: "竹芝"),
        .init(name: "新橋", neighborhood: "汐留"),
        .init(name: "有楽町", neighborhood: "銀座口")
    ]

    static func named(_ name: String) -> YamanoteStation? {
        all.first { $0.name == name }
    }

    static func next(after station: YamanoteStation) -> YamanoteStation {
        guard let index = all.firstIndex(of: station) else { return all[0] }
        return all[(index + 1) % all.count]
    }
}

struct YamanoteRouteSegment: Identifiable, Hashable {
    let from: YamanoteStation
    let to: YamanoteStation
    let distanceKilometers: Double

    var id: String { "\(from.id)-\(to.id)" }
}

struct YamanoteRouteProgress: Hashable {
    let totalDistanceKilometers: Double
    let completedLapCount: Int
    let distanceInCurrentLapKilometers: Double
    let startingStation: YamanoteStation
    let currentSegment: YamanoteRouteSegment
    let distanceFromSegmentStartKilometers: Double
    let distanceToNextStationKilometers: Double
    let passedStations: [YamanoteStation]

    var currentLapNumber: Int {
        completedLapCount + 1
    }

    var progressInCurrentLap: Double {
        guard YamanoteRoute.totalDistanceKilometers > 0 else { return 0 }
        return distanceInCurrentLapKilometers / YamanoteRoute.totalDistanceKilometers
    }

    var progressInCurrentSegment: Double {
        guard currentSegment.distanceKilometers > 0 else { return 0 }
        return distanceFromSegmentStartKilometers / currentSegment.distanceKilometers
    }
}

struct DistanceSyncEvent: Hashable {
    let addedDistanceKilometers: Double
    let passedStations: [YamanoteStation]
    let nextStation: YamanoteStation
    let distanceToNextStationKilometers: Double
    let completedLapCount: Int
    let currentLapNumber: Int

    var hasPassedStations: Bool {
        !passedStations.isEmpty
    }

    var didCompleteLap: Bool {
        completedLapCount > 0
    }
}

enum YamanoteRouteDirection: String, Hashable {
    case inner = "内回り"
    case outer = "外回り"
}

enum YamanoteRoute {
    static let outerSegments: [YamanoteRouteSegment] = zip(outerLoopStations, distancesToNextStationKilometers).map {
        YamanoteRouteSegment(from: $0.0, to: $0.1.to, distanceKilometers: $0.1.distance)
    }

    static let innerSegments: [YamanoteRouteSegment] = outerSegments.reversed().map {
        YamanoteRouteSegment(from: $0.to, to: $0.from, distanceKilometers: $0.distanceKilometers)
    }

    static let totalDistanceKilometers = 34.5

    static func progress(
        for totalDistanceKilometers: Double,
        startingAt startingStation: YamanoteStation = station("東京"),
        direction: YamanoteRouteDirection = .inner
    ) -> YamanoteRouteProgress {
        let normalizedTotalDistance = max(0, totalDistanceKilometers)
        let routeSegments = routeSegments(startingAt: startingStation, direction: direction)

        guard Self.totalDistanceKilometers > 0 else {
            return YamanoteRouteProgress(
                totalDistanceKilometers: normalizedTotalDistance,
                completedLapCount: 0,
                distanceInCurrentLapKilometers: 0,
                startingStation: startingStation,
                currentSegment: routeSegments[0],
                distanceFromSegmentStartKilometers: 0,
                distanceToNextStationKilometers: 0,
                passedStations: []
            )
        }

        let completedLapCount = Int(normalizedTotalDistance / Self.totalDistanceKilometers)
        let distanceInCurrentLap = normalizedTotalDistance.truncatingRemainder(dividingBy: Self.totalDistanceKilometers)
        let location = locate(distanceInCurrentLap, in: routeSegments)

        return YamanoteRouteProgress(
            totalDistanceKilometers: normalizedTotalDistance,
            completedLapCount: completedLapCount,
            distanceInCurrentLapKilometers: distanceInCurrentLap,
            startingStation: startingStation,
            currentSegment: location.segment,
            distanceFromSegmentStartKilometers: location.distanceFromSegmentStart,
            distanceToNextStationKilometers: location.segment.distanceKilometers - location.distanceFromSegmentStart,
            passedStations: Array(routeSegments.prefix(location.segmentIndex + 1).map(\.from))
        )
    }

    static func passedStations(
        from previousTotalDistanceKilometers: Double,
        to currentTotalDistanceKilometers: Double,
        startingAt startingStation: YamanoteStation = station("東京"),
        direction: YamanoteRouteDirection = .inner
    ) -> [YamanoteStation] {
        let previousDistance = max(0, previousTotalDistanceKilometers)
        let currentDistance = max(0, currentTotalDistanceKilometers)

        guard currentDistance > previousDistance, totalDistanceKilometers > 0 else {
            return []
        }

        let routeSegments = routeSegments(startingAt: startingStation, direction: direction)
        let stationMilestones = milestones(for: routeSegments)
        let firstLap = Int(previousDistance / totalDistanceKilometers)
        let lastLap = Int(currentDistance / totalDistanceKilometers)
        let epsilon = 0.000_001
        var passedStations: [YamanoteStation] = []

        for lap in firstLap...lastLap {
            let lapStartDistance = Double(lap) * totalDistanceKilometers

            for milestone in stationMilestones {
                let milestoneDistance = lapStartDistance + milestone.distanceKilometers
                if milestoneDistance > previousDistance + epsilon
                    && milestoneDistance <= currentDistance + epsilon {
                    passedStations.append(milestone.station)
                }
            }
        }

        return passedStations
    }

    private static let outerLoopStations: [YamanoteStation] = {
        let stationsAfterTokyo = YamanoteStation.all.dropFirst().reversed()
        return [YamanoteStation.all[0]] + stationsAfterTokyo
    }()

    private static let distancesToNextStationKilometers: [(to: YamanoteStation, distance: Double)] = [
        (station("有楽町"), 0.8),
        (station("新橋"), 1.1),
        (station("浜松町"), 1.2),
        (station("田町"), 1.5),
        (station("高輪ゲートウェイ"), 1.3),
        (station("品川"), 0.9),
        (station("大崎"), 2.0),
        (station("五反田"), 0.9),
        (station("目黒"), 1.2),
        (station("恵比寿"), 1.5),
        (station("渋谷"), 1.6),
        (station("原宿"), 1.2),
        (station("代々木"), 1.5),
        (station("新宿"), 0.7),
        (station("新大久保"), 1.3),
        (station("高田馬場"), 1.4),
        (station("目白"), 0.9),
        (station("池袋"), 1.2),
        (station("大塚"), 1.8),
        (station("巣鴨"), 1.1),
        (station("駒込"), 0.7),
        (station("田端"), 1.6),
        (station("西日暮里"), 0.8),
        (station("日暮里"), 0.5),
        (station("鶯谷"), 1.1),
        (station("上野"), 1.1),
        (station("御徒町"), 0.6),
        (station("秋葉原"), 1.0),
        (station("神田"), 0.7),
        (station("東京"), 1.3)
    ]

    private static func routeSegments(
        startingAt station: YamanoteStation,
        direction: YamanoteRouteDirection
    ) -> [YamanoteRouteSegment] {
        let allSegments = segments(for: direction)
        guard let index = allSegments.firstIndex(where: { $0.from == station }) else {
            return allSegments
        }

        return Array(allSegments[index...]) + Array(allSegments[..<index])
    }

    private static func segments(for direction: YamanoteRouteDirection) -> [YamanoteRouteSegment] {
        switch direction {
        case .inner:
            return innerSegments
        case .outer:
            return outerSegments
        }
    }

    private static func milestones(for segments: [YamanoteRouteSegment]) -> [
        (station: YamanoteStation, distanceKilometers: Double)
    ] {
        var distanceKilometers = 0.0

        return segments.map { segment in
            distanceKilometers += segment.distanceKilometers
            return (segment.to, distanceKilometers)
        }
    }

    private static func locate(_ distanceInCurrentLap: Double, in segments: [YamanoteRouteSegment]) -> (
        segment: YamanoteRouteSegment,
        segmentIndex: Int,
        distanceFromSegmentStart: Double
    ) {
        var traversedDistance = 0.0

        for (index, segment) in segments.enumerated() {
            let segmentEndDistance = traversedDistance + segment.distanceKilometers
            if distanceInCurrentLap < segmentEndDistance {
                return (segment, index, distanceInCurrentLap - traversedDistance)
            }
            traversedDistance = segmentEndDistance
        }

        return (segments[0], 0, 0)
    }

    private static func station(_ name: String) -> YamanoteStation {
        guard let station = YamanoteStation.named(name) else {
            preconditionFailure("Unknown Yamanote station: \(name)")
        }
        return station
    }
}
