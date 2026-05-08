import SwiftUI

/// Top-level routing for the app. Decides which screen to show based on
/// auth state, profile presence, and onboarding status. Each individual
/// screen lives in its own file under `Views/<feature>/`.
struct ContentView: View {
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var authService: AuthService
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        Group {
            if authService.isInitializing {
                SplashView()
            } else if authService.currentUser == nil {
                if hasSeenWelcome {
                    AuthFlowView()
                } else {
                    WelcomeView(onGetStarted: { hasSeenWelcome = true })
                }
            } else if !authService.isEmailVerified {
                VerifyEmailView()
            } else if !store.isLoaded || store.isInitialSyncInProgress {
                SplashView()
            } else if store.activeProfile == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .alert("AllerScan", isPresented: Binding(
            get: { appModel.lastErrorMessage != nil },
            set: { if !$0 { appModel.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.lastErrorMessage ?? "")
        }
    }
}
