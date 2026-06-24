import CoreLocation
import XCTest
@testable import YamanoteRunner

final class WalkingTargetCalculatorTests: XCTestCase {
    private let origin = CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0)
    private let accuracy = 1.0  // 1m 以内の誤差を許容

    func testNorthDestinationIncreasesLatitude() {
        let result = WalkingTargetCalculator.destination(
            from: origin, bearingDegrees: 0, distanceMeters: 1000
        )
        XCTAssertGreaterThan(result.latitude, origin.latitude)
        XCTAssertEqual(result.longitude, origin.longitude, accuracy: 0.0001)
    }

    func testNorthDestinationApproximateLatitudeOffset() {
        let result = WalkingTargetCalculator.destination(
            from: origin, bearingDegrees: 0, distanceMeters: 1000
        )
        // 1000m ÷ 111000m/° ≈ 0.009°
        XCTAssertEqual(result.latitude - origin.latitude, 0.009, accuracy: 0.0005)
    }

    func testEastDestinationIncreasesLongitude() {
        let result = WalkingTargetCalculator.destination(
            from: origin, bearingDegrees: 90, distanceMeters: 1000
        )
        XCTAssertGreaterThan(result.longitude, origin.longitude)
        XCTAssertEqual(result.latitude, origin.latitude, accuracy: 0.0001)
    }

    func testSouthDestinationDecreasesLatitude() {
        let result = WalkingTargetCalculator.destination(
            from: origin, bearingDegrees: 180, distanceMeters: 1000
        )
        XCTAssertLessThan(result.latitude, origin.latitude)
    }

    func testWestDestinationDecreasesLongitude() {
        let result = WalkingTargetCalculator.destination(
            from: origin, bearingDegrees: 270, distanceMeters: 1000
        )
        XCTAssertLessThan(result.longitude, origin.longitude)
    }

    func testZeroDistanceReturnsOrigin() {
        let result = WalkingTargetCalculator.destination(
            from: origin, bearingDegrees: 45, distanceMeters: 0
        )
        XCTAssertEqual(result.latitude, origin.latitude, accuracy: 0.000001)
        XCTAssertEqual(result.longitude, origin.longitude, accuracy: 0.000001)
    }

    func testRoundTripNorthSouth() {
        let north = WalkingTargetCalculator.destination(
            from: origin, bearingDegrees: 0, distanceMeters: 1000
        )
        let back = WalkingTargetCalculator.destination(
            from: north, bearingDegrees: 180, distanceMeters: 1000
        )
        XCTAssertEqual(back.latitude, origin.latitude, accuracy: 0.000001)
        XCTAssertEqual(back.longitude, origin.longitude, accuracy: 0.000001)
    }

    func testRoundTripEastWest() {
        let east = WalkingTargetCalculator.destination(
            from: origin, bearingDegrees: 90, distanceMeters: 1000
        )
        let back = WalkingTargetCalculator.destination(
            from: east, bearingDegrees: 270, distanceMeters: 1000
        )
        XCTAssertEqual(back.latitude, origin.latitude, accuracy: 0.000001)
        XCTAssertEqual(back.longitude, origin.longitude, accuracy: 0.000001)
    }

    func testCardinalCandidatesReturnsFourTargets() {
        let candidates = WalkingTargetCalculator.cardinalCandidates(
            from: origin, distanceMeters: 500
        )
        XCTAssertEqual(candidates.count, 4)
    }

    func testCardinalCandidatesLabels() {
        let candidates = WalkingTargetCalculator.cardinalCandidates(
            from: origin, distanceMeters: 500
        )
        XCTAssertEqual(candidates.map(\.label), ["北", "東", "南", "西"])
    }

    func testCardinalCandidatesDistanceMatchesInput() {
        let distanceMeters = 800.0
        let candidates = WalkingTargetCalculator.cardinalCandidates(
            from: origin, distanceMeters: distanceMeters
        )
        for candidate in candidates {
            XCTAssertEqual(candidate.distanceMeters, distanceMeters)
        }
    }

    func testCardinalCandidatesHaveUniqueIDs() {
        let candidates = WalkingTargetCalculator.cardinalCandidates(
            from: origin, distanceMeters: 500
        )
        let ids = Set(candidates.map(\.id))
        XCTAssertEqual(ids.count, 4)
    }

    func testDestinationDistanceAccuracy() {
        // 計算した目標地点と元の座標の実距離が指定距離と近いことを確認
        let distanceMeters = 1000.0
        let result = WalkingTargetCalculator.destination(
            from: origin, bearingDegrees: 45, distanceMeters: distanceMeters
        )
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let resultLocation = CLLocation(latitude: result.latitude, longitude: result.longitude)
        let actualDistance = originLocation.distance(from: resultLocation)
        XCTAssertEqual(actualDistance, distanceMeters, accuracy: accuracy)
    }

    func testWalkingGoalTargetDistanceConvertsNextStationKilometersToMeters() {
        XCTAssertEqual(
            WalkingGoalService.targetDistanceMeters(fromNextStationKilometers: 1.3),
            1300,
            accuracy: 0.001
        )
    }

    func testWalkingGoalRankingSortsByDistanceGap() {
        let candidates = [
            makeGoalCandidate(id: "far-gap", distanceMeters: 1500, gapMeters: 300),
            makeGoalCandidate(id: "closest-gap", distanceMeters: 1180, gapMeters: 20),
            makeGoalCandidate(id: "middle-gap", distanceMeters: 1100, gapMeters: 100)
        ]

        let ranked = WalkingGoalService.rankedCandidates(candidates, targetDistanceMeters: 1200)

        XCTAssertEqual(ranked.map(\.id), ["closest-gap", "middle-gap", "far-gap"])
    }

    func testWalkingGoalRankingFiltersExtremelyCloseCandidatesForMeaningfulTarget() {
        let candidates = [
            makeGoalCandidate(id: "too-close", distanceMeters: 100, gapMeters: 900),
            makeGoalCandidate(id: "usable", distanceMeters: 850, gapMeters: 150)
        ]

        let ranked = WalkingGoalService.rankedCandidates(candidates, targetDistanceMeters: 1000)

        XCTAssertEqual(ranked.map(\.id), ["usable"])
    }

    func testWalkingGuidanceTransitionsFromSelectionToGuidingAndCancel() {
        var state = WalkingGuidanceState()
        let currentLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let candidate = makeGoalCandidate(id: "park", distanceMeters: 500, gapMeters: 20)

        state.select(candidate, from: currentLocation)
        XCTAssertEqual(state.status, .candidateSelected)
        XCTAssertEqual(state.selectedCandidate?.id, "park")

        state.start()
        XCTAssertEqual(state.status, .guiding)

        state.cancel()
        XCTAssertEqual(state.status, .idle)
        XCTAssertNil(state.selectedCandidate)
    }

    func testWalkingGuidanceStartFromCurrentLocationUpdatesRemainingDistanceAndDirection() {
        var state = WalkingGuidanceState()
        let currentLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let candidate = makeGoalCandidate(id: "east-park", distanceMeters: 500, gapMeters: 20)

        state.select(candidate, from: currentLocation)
        state.start(from: currentLocation)

        XCTAssertEqual(state.status, .guiding)
        XCTAssertEqual(state.remainingDistanceMeters ?? 0, 500, accuracy: 2)
        XCTAssertEqual(state.directionText(), "東")
    }

    func testWalkingGuidanceSelectionResetsInitialDistanceForNewCandidate() {
        var state = WalkingGuidanceState()
        let currentLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let firstCandidate = makeGoalCandidate(id: "near", distanceMeters: 300, gapMeters: 20)
        let secondCandidate = makeGoalCandidate(id: "far", distanceMeters: 800, gapMeters: 10)

        state.select(firstCandidate, from: currentLocation)
        state.select(secondCandidate, from: currentLocation)

        XCTAssertEqual(state.initialDistanceMeters ?? 0, 800, accuracy: 2)
        XCTAssertEqual(state.remainingDistanceMeters ?? 0, 800, accuracy: 2)
    }

    func testWalkingGuidanceUsesRouteDistanceAsInitialDistanceBeforeStart() {
        var state = WalkingGuidanceState()
        let currentLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let candidate = makeGoalCandidate(id: "route-park", distanceMeters: 500, gapMeters: 20)

        state.select(candidate, from: currentLocation)
        state.updateRouteDistance(720)

        XCTAssertEqual(state.initialDistanceMeters ?? 0, 720, accuracy: 0.001)
        XCTAssertEqual(state.remainingDistanceMeters ?? 0, 720, accuracy: 0.001)
    }

    func testWalkingGuidanceDetectsArrivalWithinThreshold() {
        var state = WalkingGuidanceState()
        let currentLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let nearbyCoordinate = WalkingTargetCalculator.destination(
            from: origin,
            bearingDegrees: 90,
            distanceMeters: 40
        )
        let candidate = WalkingGoalCandidate(
            id: "nearby",
            name: "近い公園",
            coordinate: nearbyCoordinate,
            category: .park,
            straightLineDistanceMeters: 40,
            distanceGapMeters: 0,
            address: nil,
            sourceName: nil
        )

        state.select(candidate, from: currentLocation)
        state.start()
        state.updateLocation(currentLocation, arrivalThresholdMeters: 50)

        XCTAssertEqual(state.status, .arrived)
        XCTAssertEqual(state.progress, 1, accuracy: 0.001)
    }

    func testWalkingGuidanceUsesRouteDistanceForRemainingProgress() {
        var state = WalkingGuidanceState()
        let currentLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let candidate = makeGoalCandidate(id: "route", distanceMeters: 500, gapMeters: 20)

        state.select(candidate, from: currentLocation)
        state.start()
        state.updateRouteDistance(800, resetInitialDistance: true)
        state.updateRouteDistance(200)

        XCTAssertEqual(state.remainingDistanceMeters ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(state.progress, 0.75, accuracy: 0.001)
        XCTAssertEqual(state.status, .guiding)
    }

    @MainActor
    func testWalkingGuidanceDoesNotMutateYamanoteCumulativeProgress() {
        let suiteName = "WalkingGuidanceNoMutation-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set(1.2, forKey: "cumulativeDistanceKilometers")
        let store = AppStateStore(userDefaults: userDefaults)
        let beforeDistance = store.cumulativeDistanceKilometers
        let beforeSegment = store.routeProgress.currentSegment

        var state = WalkingGuidanceState()
        let currentLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let candidate = makeGoalCandidate(id: "cafe", distanceMeters: 500, gapMeters: 50)
        state.select(candidate, from: currentLocation)
        state.start()
        state.updateLocation(currentLocation)

        XCTAssertEqual(store.cumulativeDistanceKilometers, beforeDistance, accuracy: 0.001)
        XCTAssertEqual(store.routeProgress.currentSegment.from.name, beforeSegment.from.name)
        XCTAssertEqual(store.routeProgress.currentSegment.to.name, beforeSegment.to.name)
    }

    private func makeGoalCandidate(
        id: String,
        distanceMeters: CLLocationDistance,
        gapMeters: CLLocationDistance
    ) -> WalkingGoalCandidate {
        WalkingGoalCandidate(
            id: id,
            name: id,
            coordinate: WalkingTargetCalculator.destination(
                from: origin,
                bearingDegrees: 90,
                distanceMeters: distanceMeters
            ),
            category: .park,
            straightLineDistanceMeters: distanceMeters,
            distanceGapMeters: gapMeters,
            address: nil,
            sourceName: nil
        )
    }

}
