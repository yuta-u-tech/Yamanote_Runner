import Foundation
import HealthKit

enum HealthKitAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case requesting
    case authorized
    case denied
}

@MainActor
final class HealthKitAuthorizationService: ObservableObject {
    @Published private(set) var authorizationState: HealthKitAuthorizationState

    private let healthStore = HKHealthStore()
    private let hasRequestedAuthorizationKey = "hasRequestedHealthKitAuthorization"

    init() {
        authorizationState = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable
        refreshAuthorizationState()
    }

    func refreshAuthorizationState() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }

        switch healthStore.authorizationStatus(for: Self.stepCountType) {
        case .notDetermined:
            authorizationState = .notDetermined
        case .sharingAuthorized:
            authorizationState = .authorized
        case .sharingDenied:
            authorizationState = UserDefaults.standard.bool(forKey: hasRequestedAuthorizationKey) ? .authorized : .notDetermined
        @unknown default:
            authorizationState = .denied
        }
    }

    func requestAuthorizationIfNeeded() async {
        guard authorizationState == .notDetermined else { return }
        await requestAuthorization()
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }

        authorizationState = .requesting

        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: [Self.stepCountType, Self.walkingRunningDistanceType]
            )
            UserDefaults.standard.set(true, forKey: hasRequestedAuthorizationKey)
            authorizationState = .authorized
        } catch {
            UserDefaults.standard.set(true, forKey: hasRequestedAuthorizationKey)
            authorizationState = .denied
        }
    }

    private static var stepCountType: HKQuantityType {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            preconditionFailure("Step count type is unavailable.")
        }
        return type
    }

    private static var walkingRunningDistanceType: HKQuantityType {
        guard let type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            preconditionFailure("Walking and running distance type is unavailable.")
        }
        return type
    }
}
