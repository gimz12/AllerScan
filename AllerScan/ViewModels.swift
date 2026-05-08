import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selectedRecord: ScanRecord?
    @Published var isProcessingScan = false
    @Published var lastErrorMessage: String?
    @Published var isEditingProfile = false
    @Published var profileName = ""
    @Published var selectedAllergenIDs = Set(AllergenCatalog.defaults.prefix(4).map(\.id))
    @Published var notificationPermissionGranted = false
    @Published var cameraPermissionGranted = false
    @Published var isLocked = false

    let store: PersistenceStore

    private let scanService = ScanService()
    private let detectionService = AllergenDetectionService()
    private let biometricAuthService = BiometricAuthService()
    private let notificationService = NotificationService()
    private let hapticsService = HapticsService()
    private var isAuthenticating = false
    private var hasCompletedInitialUnlockCheck = false

    init(store: PersistenceStore) {
        self.store = store
    }

    var availableAllergens: [Allergen] {
        AllergenCatalog.defaults + store.customAllergens
    }

    var trackedAllergens: [Allergen] {
        let selected = Set(store.activeProfile?.trackedAllergenIDs ?? [])
        return availableAllergens.filter { selected.contains($0.id) }
    }

    var reminderDate: Date {
        var components = DateComponents()
        components.hour = store.securitySettings.reminderHour
        components.minute = store.securitySettings.reminderMinute
        return Calendar.current.date(from: components) ?? .now
    }

    func bootstrap() async {
        await refreshPermissions()

        if let profile = store.activeProfile {
            profileName = profile.name
            selectedAllergenIDs = Set(profile.trackedAllergenIDs)
        }

        if store.securitySettings.isBiometricLockEnabled && store.activeProfile != nil {
            isLocked = true
        }
    }

    func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermissionGranted = granted
    }

    func requestNotificationPermission() async {
        notificationPermissionGranted = await notificationService.requestAuthorization()
        var updated = store.securitySettings
        updated.notificationsEnabled = notificationPermissionGranted
        try? store.updateSecuritySettings(updated)
    }

    func updateEmergencyContact(_ contact: EmergencyContact) {
        var updated = store.securitySettings
        updated.emergencyContact = contact
        try? store.updateSecuritySettings(updated)
    }

    @Published var editingProfileID: UUID?

    func saveProfile() {
        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedAllergenIDs.isEmpty else {
            lastErrorMessage = "Enter a profile name and choose at least one allergen."
            return
        }

        let targetID = editingProfileID ?? store.activeProfile?.id ?? UUID()
        let existing = store.profiles.first { $0.id == targetID }

        let profile = UserProfile(
            id: targetID,
            name: trimmedName,
            trackedAllergenIDs: selectedAllergenIDs.sorted(),
            createdAt: existing?.createdAt ?? .now
        )

        do {
            try store.saveProfile(profile)
            if existing == nil {
                store.setActiveProfile(id: profile.id)
            }
            isEditingProfile = false
            editingProfileID = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func startCreatingNewProfile() {
        editingProfileID = nil
        profileName = ""
        selectedAllergenIDs = Set(AllergenCatalog.defaults.prefix(4).map(\.id))
        isEditingProfile = true
    }

    func startEditingProfile(_ profile: UserProfile) {
        editingProfileID = profile.id
        profileName = profile.name
        selectedAllergenIDs = Set(profile.trackedAllergenIDs)
        isEditingProfile = true
    }

    func switchActiveProfile(to id: UUID) {
        store.setActiveProfile(id: id)
        if let profile = store.profiles.first(where: { $0.id == id }) {
            profileName = profile.name
            selectedAllergenIDs = Set(profile.trackedAllergenIDs)
        }
    }

    func deleteProfile(id: UUID) {
        guard store.profiles.count > 1 else {
            lastErrorMessage = "You need at least one profile."
            return
        }
        do {
            try store.deleteProfile(id: id)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func processCapturedImage(_ image: UIImage) async {
        isProcessingScan = true
        lastErrorMessage = nil
        hapticsService.playCaptureFeedback()

        defer {
            isProcessingScan = false
        }

        do {
            let recognizedScan = try await scanService.recognizeIngredients(from: image)
            let result = await detectionService.analyze(scan: recognizedScan, trackedAllergens: trackedAllergens)
            let record = ScanRecord(result: result)
            try store.saveScanRecord(record)
            selectedRecord = record
            hapticsService.playResultFeedback(for: result.riskLevel)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func analyzeTranslatedText(_ text: String) async {
        isProcessingScan = true
        lastErrorMessage = nil

        defer { isProcessingScan = false }

        let scan = RecognizedScan(textBlocks: [text], rawText: text, normalizedText: ScanService.normalize(text))
        let result = await detectionService.analyze(scan: scan, trackedAllergens: trackedAllergens)
        let record = ScanRecord(result: result)

        do {
            try store.saveScanRecord(record)
            selectedRecord = record
            hapticsService.playResultFeedback(for: result.riskLevel)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func updateBiometricLock(_ enabled: Bool) async {
        var settings = store.securitySettings
        if enabled {
            guard biometricAuthService.canEvaluate() else {
                lastErrorMessage = "Face ID or Touch ID is not available on this device."
                return
            }

            let success = await biometricAuthService.authenticate(reason: "Enable secure access to AllerScan")
            guard success else {
                lastErrorMessage = "Biometric verification failed."
                return
            }
        }

        settings.isBiometricLockEnabled = enabled
        try? store.updateSecuritySettings(settings)
        if !enabled {
            isLocked = false
            hasCompletedInitialUnlockCheck = false
        }
    }

    func handleSceneDidBecomeActive() async {
        guard store.securitySettings.isBiometricLockEnabled, store.activeProfile != nil else { return }
        guard isLocked || !hasCompletedInitialUnlockCheck else { return }
        guard !isAuthenticating else { return }
        guard biometricAuthService.canEvaluate() else {
            lastErrorMessage = "Face ID or Touch ID is not available on this device."
            return
        }

        isAuthenticating = true
        defer {
            isAuthenticating = false
            hasCompletedInitialUnlockCheck = true
        }

        let success = await biometricAuthService.authenticate(reason: "Unlock AllerScan")
        if success {
            isLocked = false
        } else {
            isLocked = true
        }
    }

    func handleEnteredBackground() {
        guard store.securitySettings.isBiometricLockEnabled, store.activeProfile != nil else { return }
        guard hasCompletedInitialUnlockCheck else { return }
        isLocked = true
    }

    func unlockApp() async {
        await handleSceneDidBecomeActive()
    }

    func updateNotifications(enabled: Bool, reminderDate: Date) async {
        var settings = store.securitySettings
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
        settings.notificationsEnabled = enabled
        settings.reminderHour = components.hour ?? settings.reminderHour
        settings.reminderMinute = components.minute ?? settings.reminderMinute

        if enabled && !notificationPermissionGranted {
            notificationPermissionGranted = await notificationService.requestAuthorization()
            settings.notificationsEnabled = notificationPermissionGranted
        }

        try? store.updateSecuritySettings(settings)
        await notificationService.scheduleReminder(
            hour: settings.reminderHour,
            minute: settings.reminderMinute,
            enabled: settings.notificationsEnabled
        )
    }

    func addCustomAllergen(name: String, aliasesText: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            lastErrorMessage = "Enter an allergen name."
            return
        }

        let id = "custom_\(trimmedName.lowercased().replacingOccurrences(of: " ", with: "_"))_\(UUID().uuidString.prefix(6))"
        let aliases = aliasesText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let allAliases = aliases.isEmpty ? [trimmedName.lowercased()] : aliases

        let allergen = Allergen(id: id, name: trimmedName, aliases: allAliases, hiddenAliases: [], negativeContexts: [])
        do {
            try store.saveCustomAllergen(allergen)
            selectedAllergenIDs.insert(id)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func deleteCustomAllergen(id: String) {
        do {
            try store.deleteCustomAllergen(id: id)
            selectedAllergenIDs.remove(id)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func deleteHistory(at offsets: IndexSet) {
        do {
            try store.deleteScanRecords(at: offsets)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshPermissions() async {
        cameraPermissionGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        notificationPermissionGranted = await notificationService.currentAuthorizationStatus() == .authorized
    }
}
