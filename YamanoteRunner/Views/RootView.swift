import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appStateStore: AppStateStore
    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dummy") {
            _appStateStore = StateObject(wrappedValue: AppStateStore.makeDummy())
            return
        }
        #endif
        _appStateStore = StateObject(wrappedValue: AppStateStore())
    }

    var body: some View {
        Group {
            if appStateStore.hasCompletedInitialSetup {
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
