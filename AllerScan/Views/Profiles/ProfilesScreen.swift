import SwiftUI

struct ProfilesScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @State private var profileToDelete: UserProfile?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        List {
            Section {
                ForEach(store.profiles) { profile in
                    profileRow(profile)
                }
            } header: {
                Text("Profiles")
            } footer: {
                Text("Switch between profiles to scan ingredients against different allergen lists. Useful for families.")
                    .font(.caption)
            }

            Section {
                Button {
                    appModel.startCreatingNewProfile()
                } label: {
                    Label("Add new profile", systemImage: "plus.circle.fill")
                        .foregroundStyle(accentRed)
                }
            }
        }
        .navigationTitle("Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Delete profile?",
            isPresented: Binding(get: { profileToDelete != nil }, set: { if !$0 { profileToDelete = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    appModel.deleteProfile(id: profile.id)
                }
                profileToDelete = nil
            }
            Button("Cancel", role: .cancel) { profileToDelete = nil }
        } message: {
            Text("\"\(profileToDelete?.name ?? "")\" will be removed. This can't be undone.")
        }
    }

    private func profileRow(_ profile: UserProfile) -> some View {
        let isActive = profile.id == store.activeProfile?.id

        return Button {
            appModel.switchActiveProfile(to: profile.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? accentRed : Color(.tertiaryLabel))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(profile.trackedAllergenIDs.count) allergen\(profile.trackedAllergenIDs.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        appModel.startEditingProfile(profile)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if store.profiles.count > 1 {
                        Button(role: .destructive) {
                            profileToDelete = profile
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
