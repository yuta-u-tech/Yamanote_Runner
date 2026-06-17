import Foundation
import HealthKit

enum HealthDistanceError: LocalizedError, Equatable {
    case unavailable
    case stepCountTypeUnavailable
    case distanceTypeUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "ヘルスケアデータを利用できません。"
        case .stepCountTypeUnavailable:
            "歩数を取得できません。"
        case .distanceTypeUnavailable:
            "歩行・ランニング距離を取得できません。"
        }
    }
}

struct DailyWalkingRunningDistance: Equatable {
    let date: Date
    let stepCount: Int
    let kilometers: Double
    let strideMeters: Double
    let isStrideEstimated: Bool
}

struct StepDistanceEstimator: Equatable {
    static let defaultHeightCentimeters = 170.0

    let heightCentimeters: Double?

    var normalizedHeightCentimeters: Double {
        guard let heightCentimeters, heightCentimeters.isFinite, heightCentimeters > 0 else {
            return Self.defaultHeightCentimeters
        }

        return min(max(heightCentimeters, 100), 220)
    }

    var estimatedStrideMeters: Double {
        normalizedHeightCentimeters * 0.415 / 100
    }

    func strideMeters(distanceKilometers: Double, stepCount: Int) -> (meters: Double, isEstimated: Bool) {
        guard stepCount > 0, distanceKilometers > 0 else {
            return (estimatedStrideMeters, true)
        }

        return (distanceKilometers * 1000 / Double(stepCount), false)
    }
}

final class HealthDistanceService {
    private let healthStore: HKHealthStore
    private let calendar: Calendar

    init(healthStore: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.healthStore = healthStore
        self.calendar = calendar
    }

    func todayWalkingRunningDistance(
        now: Date = Date(),
        heightCentimeters: Double? = nil
    ) async throws -> DailyWalkingRunningDistance {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthDistanceError.unavailable
        }

        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthDistanceError.stepCountTypeUnavailable
        }

        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw HealthDistanceError.distanceTypeUnavailable
        }

        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: [.strictStartDate]
        )
        let stepCount = Int(
            try await cumulativeQuantity(
                for: stepCountType,
                unit: .count(),
                predicate: predicate
            )
        )
        let kilometers = try await cumulativeQuantity(
            for: distanceType,
            unit: .meterUnit(with: .kilo),
            predicate: predicate
        )
        let estimator = StepDistanceEstimator(heightCentimeters: heightCentimeters)
        let stride = estimator.strideMeters(
            distanceKilometers: kilometers,
            stepCount: stepCount
        )

        return DailyWalkingRunningDistance(
            date: now,
            stepCount: stepCount,
            kilometers: kilometers,
            strideMeters: stride.meters,
            isStrideEstimated: stride.isEstimated
        )
    }

    private func cumulativeQuantity(
        for quantityType: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double {
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: quantityType, predicate: predicate),
            options: .cumulativeSum
        )
        let statistics = try await descriptor.result(for: healthStore)
        return statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }
}

@MainActor
final class TodayDistanceViewModel: ObservableObject {
    @Published private(set) var distanceKilometers: Double?
    @Published private(set) var stepCount: Int?
    @Published private(set) var strideMeters: Double?
    @Published private(set) var isStrideEstimated = true
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let distanceService: HealthDistanceService

    init(distanceService: HealthDistanceService = HealthDistanceService()) {
        self.distanceService = distanceService
    }

    var statusText: String {
        if isLoading {
            return "取得中"
        }

        if let errorMessage {
            return "取得失敗: \(errorMessage)"
        }

        guard let stepCount else {
            return "未取得"
        }

        return stepCount > 0 ? "取得成功" : "データなし"
    }

    func loadTodayDistance(heightCentimeters: Double? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let distance = try await distanceService.todayWalkingRunningDistance(
                heightCentimeters: heightCentimeters
            )
            distanceKilometers = distance.kilometers
            stepCount = distance.stepCount
            strideMeters = distance.strideMeters
            isStrideEstimated = distance.isStrideEstimated
        } catch {
            distanceKilometers = nil
            stepCount = nil
            strideMeters = nil
            isStrideEstimated = true
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
