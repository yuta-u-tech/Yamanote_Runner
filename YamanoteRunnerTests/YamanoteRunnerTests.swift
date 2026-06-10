import XCTest
@testable import YamanoteRunner

final class YamanoteRunnerTests: XCTestCase {
    func testRouteProgressStartsBetweenTokyoAndYurakucho() {
        let progress = YamanoteRoute.progress(for: 0.3)

        XCTAssertEqual(progress.completedLapCount, 0)
        XCTAssertEqual(progress.currentLapNumber, 1)
        XCTAssertEqual(progress.currentSegment.from.name, "東京")
        XCTAssertEqual(progress.currentSegment.to.name, "有楽町")
        XCTAssertEqual(progress.distanceFromSegmentStartKilometers, 0.3, accuracy: 0.001)
        XCTAssertEqual(progress.distanceToNextStationKilometers, 0.5, accuracy: 0.001)
        XCTAssertEqual(progress.passedStations.map(\.name), ["東京"])
    }

    func testRouteProgressCalculatesSecondLap() {
        let progress = YamanoteRoute.progress(for: YamanoteRoute.totalDistanceKilometers + 0.4)

        XCTAssertEqual(progress.completedLapCount, 1)
        XCTAssertEqual(progress.currentLapNumber, 2)
        XCTAssertEqual(progress.distanceInCurrentLapKilometers, 0.4, accuracy: 0.001)
        XCTAssertEqual(progress.currentSegment.from.name, "東京")
        XCTAssertEqual(progress.currentSegment.to.name, "有楽町")
        XCTAssertEqual(progress.distanceToNextStationKilometers, 0.4, accuracy: 0.001)
    }

    func testRouteProgressTracksPassedStationsWithinLap() {
        let progress = YamanoteRoute.progress(for: 2.0)

        XCTAssertEqual(progress.currentSegment.from.name, "新橋")
        XCTAssertEqual(progress.currentSegment.to.name, "浜松町")
        XCTAssertEqual(progress.distanceFromSegmentStartKilometers, 0.1, accuracy: 0.001)
        XCTAssertEqual(progress.passedStations.map(\.name), ["東京", "有楽町", "新橋"])
    }

    func testRouteProgressClampsNegativeDistanceToStart() {
        let progress = YamanoteRoute.progress(for: -5.0)

        XCTAssertEqual(progress.totalDistanceKilometers, 0)
        XCTAssertEqual(progress.currentSegment.from.name, "東京")
        XCTAssertEqual(progress.distanceToNextStationKilometers, 0.8, accuracy: 0.001)
    }
}
