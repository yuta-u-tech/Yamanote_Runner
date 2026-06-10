import Foundation
import HealthKit

enum HealthDistanceError: LocalizedError, Equatable {
    case unavailable
    case distanceTypeUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "ヘルスケアデータを利用できません。"
        case .distanceTypeUnavailable:
            "歩行・ランニング距離を取得できません。"
        }
    }
}

struct DailyWalkingRunningDistance: Equatable {
    let date: Date
    let kilometers: Double
}

final class HealthDistanceService {
    private let healthStore: HKHealthStore
    private let calendar: Calendar

    init(healthStore: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.healthStore = healthStore
        self.calendar = calendar
    }

    func todayWalkingRunningDistance(now: Date = Date()) async throws -> DailyWalkingRunningDistance {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthDistanceError.unavailable
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
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: distanceType, predicate: predicate),
            options: .cumulativeSum
        )

        let statistics = try await descriptor.result(for: healthStore)
        let kilometers = statistics?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0

        return DailyWalkingRunningDistance(date: now, kilometers: kilometers)
    }
}

@MainActor
final class TodayDistanceViewModel: ObservableObject {
    @Published private(set) var distanceKilometers: Double?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let distanceService: HealthDistanceService

    init(distanceService: HealthDistanceService = HealthDistanceService()) {
        self.distanceService = distanceService
    }

    func loadTodayDistance() async {
        isLoading = true
        errorMessage = nil

        do {
            let distance = try await distanceService.todayWalkingRunningDistance()
            distanceKilometers = distance.kilometers
        } catch {
            distanceKilometers = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
