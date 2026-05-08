import FirebaseCore
import SwiftUI
import UserNotifications

@main
struct AllerScanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var persistenceStore: PersistenceStore
    @StateObject private var appModel: AppViewModel
    @StateObject private var authService: AuthService

    init() {
        FirebaseApp.configure()
        let store = PersistenceStore()
        _persistenceStore = StateObject(wrappedValue: store)
        _appModel = StateObject(wrappedValue: AppViewModel(store: store))
        _authService = StateObject(wrappedValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(persistenceStore)
                .environmentObject(appModel)
                .environmentObject(authService)
                .environmentObject(EmergencyDeepLink.shared)
                .task {
                    await appModel.bootstrap()
                }
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
