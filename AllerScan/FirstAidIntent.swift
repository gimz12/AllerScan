import AppIntents
import Combine
import SwiftUI

struct OpenFirstAidIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Allergic Reaction Help"
    static var description: IntentDescription? = "Open AllerScan's emergency first-aid protocol immediately."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            EmergencyDeepLink.shared.shouldOpenFirstAid = true
        }
        return .result()
    }
}

struct AllerScanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenFirstAidIntent(),
            phrases: [
                "I'm having an allergic reaction in \(.applicationName)",
                "Allergic reaction help in \(.applicationName)",
                "Open emergency first aid in \(.applicationName)"
            ],
            shortTitle: "Allergic Reaction Help",
            systemImageName: "cross.case.fill"
        )
    }
}

@MainActor
final class EmergencyDeepLink: ObservableObject {
    static let shared = EmergencyDeepLink()
    @Published var shouldOpenFirstAid = false
    private init() {}
}
