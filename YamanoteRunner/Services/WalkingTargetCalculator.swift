import CoreLocation
import Foundation

struct WalkingTarget: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: Double
    let bearing: Double
    let label: String
}

enum WalkingTargetCalculator {
    private static let earthRadiusMeters = 6_371_000.0

    /// 現在地から bearing 方向へ distanceMeters 進んだ座標を返す
    /// - bearing: 度 (0=北, 90=東, 180=南, 270=西)
    static func destination(
        from origin: CLLocationCoordinate2D,
        bearingDegrees: Double,
        distanceMeters: Double
    ) -> CLLocationCoordinate2D {
        let R = earthRadiusMeters
        let d = distanceMeters
        let θ = bearingDegrees * .pi / 180
        let φ1 = origin.latitude * .pi / 180
        let λ1 = origin.longitude * .pi / 180

        let φ2 = asin(sin(φ1) * cos(d / R) + cos(φ1) * sin(d / R) * cos(θ))
        let λ2 = λ1 + atan2(
            sin(θ) * sin(d / R) * cos(φ1),
            cos(d / R) - sin(φ1) * sin(φ2)
        )

        return CLLocationCoordinate2D(
            latitude: φ2 * 180 / .pi,
            longitude: λ2 * 180 / .pi
        )
    }

    /// N/E/S/W の 4 方向の候補を返す
    static func cardinalCandidates(
        from origin: CLLocationCoordinate2D,
        distanceMeters: Double
    ) -> [WalkingTarget] {
        [(0.0, "北"), (90.0, "東"), (180.0, "南"), (270.0, "西")].map { bearing, label in
            WalkingTarget(
                id: UUID(),
                coordinate: destination(from: origin, bearingDegrees: bearing, distanceMeters: distanceMeters),
                distanceMeters: distanceMeters,
                bearing: bearing,
                label: label
            )
        }
    }
}
