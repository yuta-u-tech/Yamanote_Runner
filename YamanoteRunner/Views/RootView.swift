import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appStateStore: AppStateStore
    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()
    @StateObject private var subscriptionService: SubscriptionService
    private let isDummyPreview: Bool

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dummy") {
            isDummyPreview = true
            _appStateStore = StateObject(wrappedValue: AppStateStore.makeDummy())
            _subscriptionService = StateObject(wrappedValue: SubscriptionService(
                initialStatus: .subscribed,
                currentEntitledProductIDs: { SubscriptionService.productIDs }
            ))
            return
        }
        #endif
        isDummyPreview = false
        _appStateStore = StateObject(wrappedValue: AppStateStore())
        _subscriptionService = StateObject(wrappedValue: SubscriptionService())
    }

    var body: some View {
        Group {
            if isDummyPreview {
                MainTabView(appStateStore: appStateStore)
            } else if appStateStore.hasCompletedInitialSetup {
                if healthKitAuthorizationService.authorizationState == .authorized {
                    MainTabView(appStateStore: appStateStore)
                } else {
                    HealthPermissionView(
                        authorizationState: healthKitAuthorizationService.authorizationState,
                        requestAuthorization: healthKitAuthorizationService.requestAuthorization
                    )
                }
            } else {
                InitialSetupFlowView(
                    appStateStore: appStateStore,
                    onComplete: appStateStore.completeInitialSetup
                )
            }
        }
        .environmentObject(subscriptionService)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            healthKitAuthorizationService.refreshAuthorizationState()
        }
    }
}

#Preview {
    RootView()
}
