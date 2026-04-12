import SwiftUI
import UserNotifications

@main
struct AllerScanApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var persistenceStore: PersistenceStore
    @StateObject private var appModel: AppViewModel

    init() {
        let store = PersistenceStore()
        _persistenceStore = StateObject(wrappedValue: store)
        _appModel = StateObject(wrappedValue: AppViewModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(persistenceStore)
                .environmentObject(appModel)
                .task {
                    await appModel.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        Task {
                            await appModel.handleSceneDidBecomeActive()
                        }
                    case .background:
                        appModel.handleEnteredBackground()
                    default:
                        break
                    }
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
