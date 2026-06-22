import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appStateStore: AppStateStore
    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()
    private let isDummyPreview: Bool

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dummy") {
            isDummyPreview = true
            _appStateStore = StateObject(wrappedValue: AppStateStore.makeDummy())
            return
        }
        #endif
        isDummyPreview = false
        _appStateStore = StateObject(wrappedValue: AppStateStore())
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            healthKitAuthorizationService.refreshAuthorizationState()
        }
    }
}

#Preview {
    RootView()
}
