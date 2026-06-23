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
}
