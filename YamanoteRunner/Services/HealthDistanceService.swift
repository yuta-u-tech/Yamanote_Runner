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
        try await walkingRunningDistance(
            from: calendar.startOfDay(for: now),
            to: now,
            heightCentimeters: heightCentimeters
        )
    }

    func recentDailyWalkingRunningDistances(
        days: Int = 7,
        endingAt now: Date = Date(),
        heightCentimeters: Double? = nil
    ) async throws -> [DailyWalkingRunningDistance] {
        let boundedDays = max(1, days)
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(boundedDays - 1), to: today) ?? today

        return try await dailyWalkingRunningDistances(
            from: start,
            to: now,
            heightCentimeters: heightCentimeters
        )
    }

    private func walkingRunningDistance(
        from startDate: Date,
        to endDate: Date,
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

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
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
            date: calendar.startOfDay(for: startDate),
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

    private func dailyWalkingRunningDistances(
        from startDate: Date,
        to endDate: Date,
        heightCentimeters: Double? = nil
    ) async throws -> [DailyWalkingRunningDistance] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthDistanceError.unavailable
        }

        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthDistanceError.stepCountTypeUnavailable
        }

        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw HealthDistanceError.distanceTypeUnavailable
        }

        let dayStart = calendar.startOfDay(for: startDate)
        let endDayStart = calendar.startOfDay(for: endDate)
        let dayAfterEnd = calendar.date(byAdding: .day, value: 1, to: endDayStart) ?? endDate
        let rangeEnd = min(endDate, dayAfterEnd)
        let stepCounts = try await dailyCumulativeQuantities(
            for: stepCountType,
            unit: .count(),
            from: dayStart,
            to: rangeEnd
        )
        let distances = try await dailyCumulativeQuantities(
            for: distanceType,
            unit: .meterUnit(with: .kilo),
            from: dayStart,
            to: rangeEnd
        )
        let estimator = StepDistanceEstimator(heightCentimeters: heightCentimeters)

        var records: [DailyWalkingRunningDistance] = []
        var currentDay = dayStart
        while currentDay <= endDayStart {
            let stepCount = Int(stepCounts[currentDay] ?? 0)
            let kilometers = distances[currentDay] ?? 0
            let stride = estimator.strideMeters(
                distanceKilometers: kilometers,
                stepCount: stepCount
            )

            records.append(
                DailyWalkingRunningDistance(
                    date: currentDay,
                    stepCount: stepCount,
                    kilometers: kilometers,
                    strideMeters: stride.meters,
                    isStrideEstimated: stride.isEstimated
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else {
                break
            }
            currentDay = nextDay
        }

        return records
    }

    private func dailyCumulativeQuantities(
        for quantityType: HKQuantityType,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: quantityType, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: healthStore)
        var quantitiesByDate: [Date: Double] = [:]

        collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            let dayStart = self.calendar.startOfDay(for: statistics.startDate)
            quantitiesByDate[dayStart] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
        }

        return quantitiesByDate
    }
}

@MainActor
final class TodayDistanceViewModel: ObservableObject {
    @Published private(set) var distanceKilometers: Double?
    @Published private(set) var stepCount: Int?
    @Published private(set) var strideMeters: Double?
    @Published private(set) var isStrideEstimated = true
    @Published private(set) var recentDailyDistances: [DailyWalkingRunningDistance] = []
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
            recentDailyDistances = (try? await distanceService.recentDailyWalkingRunningDistances(
                heightCentimeters: heightCentimeters
            )) ?? []
        } catch {
            distanceKilometers = nil
            stepCount = nil
            strideMeters = nil
            isStrideEstimated = true
            recentDailyDistances = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    #if DEBUG
    func loadDummyData(distanceKilometers: Double, stepCount: Int) {
        self.distanceKilometers = distanceKilometers
        self.stepCount = stepCount
        self.strideMeters = nil
        self.isStrideEstimated = true
        self.recentDailyDistances = []
        self.isLoading = false
        self.errorMessage = nil
    }
    #endif
}
