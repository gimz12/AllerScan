import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appModel: AppViewModel
    // Use @State, not @SceneStorage — we want each fresh sign-in to land on Home,
    // not on whichever tab the previous session ended on.
    @State private var selectedTab = 0
    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardScreen()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            HistoryScreen()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
                .tag(1)

            SettingsGate()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(accentRed)
        .sheet(isPresented: $appModel.isEditingProfile) {
            NavigationStack {
                OnboardingView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                appModel.isEditingProfile = false
                            }
                        }
                    }
            }
        }
    }
}
