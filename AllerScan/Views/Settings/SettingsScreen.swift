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
                    TextField("Phone number", text: $contactPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    Button("Save emergency contact") {
                        appModel.updateEmergencyContact(
                            EmergencyContact(
                                name: contactName.trimmingCharacters(in: .whitespaces),
                                phoneNumber: contactPhone.trimmingCharacters(in: .whitespaces)
                            )
                        )
                    }
                    .disabled(contactName.trimmingCharacters(in: .whitespaces).isEmpty
                              || contactPhone.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Emergency Contact")
                } footer: {
                    Text("During an allergic reaction, you can send an SMS with your location to this contact from the First Aid screen.")
                        .font(.caption)
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
