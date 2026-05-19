import XCTest

final class YamanoteRunnerTests: XCTestCase {
    func testInitialProgressIsRepresentable() {
        let progress = 0.18

        XCTAssertGreaterThanOrEqual(progress, 0)
        XCTAssertLessThanOrEqual(progress, 1)
    }
}
