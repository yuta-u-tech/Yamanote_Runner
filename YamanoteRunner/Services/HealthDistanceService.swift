import Foundation
import HealthKit

enum HealthDistanceError: LocalizedError, Equatable {
    case unavailable
    case stepCountTypeUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "ヘルスケアデータを利用できません。"
        case .stepCountTypeUnavailable:
            "歩数を取得できません。"
        }
    }
}

struct DailyWalkingRunningDistance: Equatable {
    let date: Date
    let stepCount: Int
    let kilometers: Double
    let estimatedStrideMeters: Double
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

    func kilometers(for stepCount: Int) -> Double {
        guard stepCount > 0 else { return 0 }
        return Double(stepCount) * estimatedStrideMeters / 1000
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

        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: [.strictStartDate]
        )
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: stepCountType, predicate: predicate),
            options: .cumulativeSum
        )

        let statistics = try await descriptor.result(for: healthStore)
        let stepCount = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
        let estimator = StepDistanceEstimator(heightCentimeters: heightCentimeters)

        return DailyWalkingRunningDistance(
            date: now,
            stepCount: stepCount,
            kilometers: estimator.kilometers(for: stepCount),
            estimatedStrideMeters: estimator.estimatedStrideMeters
        )
    }
}

@MainActor
final class TodayDistanceViewModel: ObservableObject {
    @Published private(set) var distanceKilometers: Double?
    @Published private(set) var stepCount: Int?
    @Published private(set) var estimatedStrideMeters: Double?
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
            estimatedStrideMeters = distance.estimatedStrideMeters
        } catch {
            distanceKilometers = nil
            stepCount = nil
            estimatedStrideMeters = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
