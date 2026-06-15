import SwiftUI

struct RootView: View {
    @StateObject private var appStateStore = AppStateStore()
    @StateObject private var healthKitAuthorizationService = HealthKitAuthorizationService()

    var body: some View {
        if appStateStore.hasCompletedInitialSetup {
            if healthKitAuthorizationService.authorizationState == .authorized {
                HomeView(
                    appStateStore: appStateStore
                )
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
}

#Preview {
    RootView()
}
