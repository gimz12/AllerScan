import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @State private var showAddCustom = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)
    private let grid = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AllerScan")
                            .font(.largeTitle.bold())
                        Text("Build a safety profile, scan ingredient labels, and flag risky allergens directly on-device.")
                            .foregroundStyle(.secondary)
                    }

                    PermissionRow(
                        title: "Camera access",
                        subtitle: appModel.cameraPermissionGranted ? "Ready for ingredient scanning." : "Needed for label capture and OCR.",
                        actionTitle: appModel.cameraPermissionGranted ? "Granted" : "Allow"
                    ) {
                        Task {
                            await appModel.requestCameraPermission()
                        }
                    }
                    .disabled(appModel.cameraPermissionGranted)

                    PermissionRow(
                        title: "Notifications",
                        subtitle: appModel.notificationPermissionGranted ? "Daily reminder can be scheduled." : "Optional reminders and safety nudges.",
                        actionTitle: appModel.notificationPermissionGranted ? "Granted" : "Allow"
                    ) {
                        Task {
                            await appModel.requestNotificationPermission()
                        }
                    }
                    .disabled(appModel.notificationPermissionGranted)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profile setup")
                            .font(.title3.bold())

                        TextField("Profile name", text: $appModel.profileName)
                            .textFieldStyle(.roundedBorder)

                        Text("Common Allergens")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        LazyVGrid(columns: grid, spacing: 12) {
                            ForEach(AllergenCatalog.defaults) { allergen in
                                allergenToggleButton(allergen)
                            }
                        }

                        if !store.customAllergens.isEmpty {
                            Text("Custom Allergens")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)

                            LazyVGrid(columns: grid, spacing: 12) {
                                ForEach(store.customAllergens) { allergen in
                                    allergenToggleButton(allergen, isCustom: true)
                                }
                            }
                        }

                        Button { showAddCustom = true } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Custom Allergen")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(accentRed.opacity(0.08))
                            .foregroundStyle(accentRed)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save Profile") {
                        appModel.saveProfile()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(20)
            }
            .navigationTitle("Welcome")
            .sheet(isPresented: $showAddCustom) {
                AddCustomAllergenSheet()
            }
        }
    }

    private func allergenToggleButton(_ allergen: Allergen, isCustom: Bool = false) -> some View {
        Button {
            if appModel.selectedAllergenIDs.contains(allergen.id) {
                appModel.selectedAllergenIDs.remove(allergen.id)
            } else {
                appModel.selectedAllergenIDs.insert(allergen.id)
            }
        } label: {
            HStack {
                Image(systemName: appModel.selectedAllergenIDs.contains(allergen.id) ? "checkmark.circle.fill" : "circle")
                Text(allergen.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if isCustom {
                    Button {
                        appModel.deleteCustomAllergen(id: allergen.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(appModel.selectedAllergenIDs.contains(allergen.id) ? accentRed.opacity(0.12) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
