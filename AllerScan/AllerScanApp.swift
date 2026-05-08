import FirebaseCore
import SwiftUI
import UserNotifications

@main
struct AllerScanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var persistenceStore: PersistenceStore
    @StateObject private var appModel: AppViewModel
    @StateObject private var authService: AuthService
    @StateObject private var syncService: SyncService

    init() {
        FirebaseApp.configure()
        let store = PersistenceStore()
        let sync = SyncService()
        store.syncService = sync
        sync.applyRemoteSnapshot = { [weak store] snapshot in
            try store?.applyRemoteSnapshot(snapshot)
        }
        _persistenceStore = StateObject(wrappedValue: store)
        _appModel = StateObject(wrappedValue: AppViewModel(store: store))
        _authService = StateObject(wrappedValue: AuthService())
        _syncService = StateObject(wrappedValue: sync)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(persistenceStore)
                .environmentObject(appModel)
                .environmentObject(authService)
                .environmentObject(syncService)
                .environmentObject(EmergencyDeepLink.shared)
                .task {
                    await appModel.bootstrap()
                }
                .task(id: authStateID) {
                    await handleAuthChange()
                }
        }
    }

    private var authStateID: String {
        "\(authService.uid ?? "anon")_\(authService.isEmailVerified)_\(authService.isInitializing)"
    }

    private func handleAuthChange() async {
        // Skip while Firebase is still resolving the cached session — otherwise
        // the brief "uid is nil" period is misread as sign-out and wipes local data,
        // causing the OnboardingView to flash on every app launch.
        guard !authService.isInitializing else { return }

        let lastSyncedKey = "AllerScan.lastSyncedUID"
        syncService.updateAuthState(isAuthenticated: authService.uid != nil)

        if let uid = authService.uid, authService.isEmailVerified {
            let previous = UserDefaults.standard.string(forKey: lastSyncedKey)
            if previous != uid {
                // First sign-in (or different account) → pull from Firestore.
                // Flag the store so ContentView shows SplashView (not OnboardingView) while we're pulling.
                persistenceStore.isInitialSyncInProgress = true
                do {
                    let snapshot = try await syncService.pullAll()
                    try persistenceStore.applyRemoteSnapshot(snapshot)
                    syncService.markSyncedNow()
                } catch {
                    print("[Sync] initial pull failed: \(error.localizedDescription)")
                }
                persistenceStore.isInitialSyncInProgress = false
                UserDefaults.standard.set(uid, forKey: lastSyncedKey)
            } else {
                syncService.markSyncedNow()
            }
        } else if authService.uid == nil {
            // Genuinely signed out (initialization is complete and uid is nil) →
            // clear local data so next user doesn't see previous data.
            persistenceStore.clearSyncableLocalData()
            UserDefaults.standard.removeObject(forKey: lastSyncedKey)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
