import SwiftUI
import UIKit

struct SettingsScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService

    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var showMedicalIDInstructions = false
    @State private var contactJustSaved = false
    @FocusState private var focusedContactField: ContactField?

    private enum ContactField {
        case name, phone
    }

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    private var contactHasUnsavedChanges: Bool {
        let trimmedName = contactName.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = contactPhone.trimmingCharacters(in: .whitespaces)
        return trimmedName != store.securitySettings.emergencyContact.name
            || trimmedPhone != store.securitySettings.emergencyContact.phoneNumber
    }

    private var contactCanSave: Bool {
        let trimmedName = contactName.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = contactPhone.trimmingCharacters(in: .whitespaces)
        return !trimmedName.isEmpty && !trimmedPhone.isEmpty && contactHasUnsavedChanges
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfilesScreen()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(.blue)
                                Text(store.activeProfile?.name ?? "No profile")
                                    .font(.headline)
                            }
                            Text("\(store.profiles.count) profile\(store.profiles.count == 1 ? "" : "s") • \(store.activeProfile?.trackedAllergenIDs.count ?? 0) tracked allergens")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Edit current profile") {
                        if let profile = store.activeProfile {
                            appModel.startEditingProfile(profile)
                        }
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Tap above to switch between family members or add a new profile.")
                        .font(.caption)
                }

                Section {
                    TextField("Name", text: $contactName)
                        .textContentType(.name)
                        .focused($focusedContactField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedContactField = .phone }
                    TextField("Phone number", text: $contactPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($focusedContactField, equals: .phone)

                    Button {
                        saveEmergencyContact()
                    } label: {
                        emergencyContactSaveButtonLabel
                    }
                    .buttonStyle(.plain)
                    .disabled(!contactCanSave && !contactJustSaved)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Emergency Contact")
                } footer: {
                    if contactHasUnsavedChanges {
                        Text("You have unsaved changes — tap **Save Changes** to apply.")
                            .font(.caption)
                            .foregroundStyle(accentRed)
                    } else {
                        Text("During an allergic reaction, you can send an SMS with your location to this contact from the First Aid screen.")
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        copyAllergensAndOpenHealth()
                    } label: {
                        Label("Add allergens to Medical ID", systemImage: "heart.text.square.fill")
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Your tracked allergens will be copied to the clipboard. The Health app will open — tap Medical ID → Edit → Allergies & Reactions, then paste.")
                        .font(.caption)
                }

                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Siri in an Emergency")
                                .font(.subheadline.bold())
                            Text("Say \"Hey Siri, allergic reaction help in AllerScan\" to open the First Aid screen instantly.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Siri Shortcut")
                }

                Section {
                    Toggle("Lock Settings", isOn: Binding(
                        get: { store.securitySettings.isBiometricLockEnabled },
                        set: { newValue in
                            Task {
                                await appModel.updateBiometricLock(newValue)
                            }
                        }
                    ))
                } header: {
                    Text("Security")
                } footer: {
                    Text("Require Face ID or Touch ID to view or change profiles, allergens, emergency contact, and account info. Other parts of the app stay instantly accessible.")
                        .font(.caption)
                }

                Section("Notifications") {
                    Toggle("Daily safety reminder", isOn: Binding(
                        get: { store.securitySettings.notificationsEnabled },
                        set: { newValue in
                            Task {
                                await appModel.updateNotifications(enabled: newValue, reminderDate: appModel.reminderDate)
                            }
                        }
                    ))

                    DatePicker(
                        "Reminder time",
                        selection: Binding(
                            get: { appModel.reminderDate },
                            set: { newValue in
                                Task {
                                    await appModel.updateNotifications(
                                        enabled: store.securitySettings.notificationsEnabled,
                                        reminderDate: newValue
                                    )
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!store.securitySettings.notificationsEnabled)
                }

                Section {
                    SyncStatusRow()
                    Button {
                        Task { await syncService.syncNow() }
                    } label: {
                        Label(
                            syncService.status == .syncing ? "Syncing…" : "Sync Now",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .disabled(syncService.status == .syncing
                              || syncService.status == .notSignedIn
                              || syncService.status == .offline)
                } header: {
                    Text("Cloud Sync")
                } footer: {
                    Text("Profiles, scan history, and custom allergens are encrypted in transit and stored under your Apple ID-linked account in Firestore. Pushes happen automatically; tap Sync Now to pull the latest from cloud.")
                        .font(.caption)
                }

                Section {
                    Button(role: .destructive) {
                        try? authService.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } footer: {
                    if !authService.email.isEmpty {
                        Text("Signed in as \(authService.email)")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedContactField = nil
                    } label: {
                        Text("Done")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(accentRed)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(accentRed.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .onAppear {
                contactName = store.securitySettings.emergencyContact.name
                contactPhone = store.securitySettings.emergencyContact.phoneNumber
            }
            .alert("Allergens copied", isPresented: $showMedicalIDInstructions) {
                Button("Open Health app") { openHealthApp() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your tracked allergens are on the clipboard. In Health: tap your photo → Medical ID → Edit → Allergies & Reactions, then paste.")
            }
        }
    }

    @ViewBuilder
    private var emergencyContactSaveButtonLabel: some View {
        HStack(spacing: 10) {
            saveButtonIcon
                .font(.subheadline.bold())
            Text(saveButtonTitle)
                .font(.headline)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .foregroundStyle(saveButtonForeground)
        .background(saveButtonBackground)
        .clipShape(Capsule())
        .shadow(color: contactCanSave ? accentRed.opacity(0.25) : .clear, radius: 8, y: 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: contactJustSaved)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: contactHasUnsavedChanges)
    }

    private var saveButtonTitle: String {
        if contactJustSaved { return "Saved" }
        if contactHasUnsavedChanges { return "Save Contact" }
        return "Saved"
    }

    @ViewBuilder
    private var saveButtonIcon: some View {
        if contactJustSaved {
            Image(systemName: "checkmark.circle.fill")
        } else if contactHasUnsavedChanges {
            Image(systemName: "checkmark.shield.fill")
        } else {
            Image(systemName: "checkmark")
        }
    }

    private var saveButtonForeground: Color {
        if contactJustSaved { return .white }
        if contactHasUnsavedChanges { return .white }
        return .secondary
    }

    @ViewBuilder
    private var saveButtonBackground: some View {
        if contactJustSaved {
            LinearGradient(
                colors: [.green, Color.green.opacity(0.85)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else if contactHasUnsavedChanges {
            LinearGradient(
                colors: [accentRed, accentRed.opacity(0.85)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            Color(.tertiarySystemFill)
        }
    }

    private func saveEmergencyContact() {
        appModel.updateEmergencyContact(
            EmergencyContact(
                name: contactName.trimmingCharacters(in: .whitespaces),
                phoneNumber: contactPhone.trimmingCharacters(in: .whitespaces)
            )
        )
        withAnimation { contactJustSaved = true }
        // Briefly show the green confirmation, then revert.
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation { contactJustSaved = false }
            }
        }
    }

    private func copyAllergensAndOpenHealth() {
        let names = appModel.trackedAllergens.map(\.name)
        guard !names.isEmpty else { return }
        UIPasteboard.general.string = names.joined(separator: ", ")
        showMedicalIDInstructions = true
    }

    private func openHealthApp() {
        if let url = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
