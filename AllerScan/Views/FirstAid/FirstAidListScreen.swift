import SwiftUI

struct FirstAidListScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAllergen: Allergen?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCallout

                    if appModel.trackedAllergens.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appModel.trackedAllergens) { allergen in
                                Button {
                                    selectedAllergen = allergen
                                } label: {
                                    allergenRow(allergen)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    disclaimer
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("First Aid Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $selectedAllergen) { allergen in
                FirstAidScreen(allergen: allergen)
            }
        }
    }

    private var headerCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.title2)
                .foregroundStyle(accentRed)

            VStack(alignment: .leading, spacing: 4) {
                Text("Emergency Protocols")
                    .font(.headline)
                Text("Tap an allergen for the immediate response steps. The protocol applies the same to all food-allergic reactions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(accentRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func allergenRow(_ allergen: Allergen) -> some View {
        HStack(spacing: 14) {
            Image(systemName: AllergenTravelTranslations.icon(for: allergen.id))
                .font(.title3)
                .foregroundStyle(accentRed)
                .frame(width: 38, height: 38)
                .background(accentRed.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(allergen.name)
                    .font(.headline)
                Text("View emergency protocol")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No tracked allergens")
                .font(.headline)
            Text("Add allergens to your profile to see emergency protocols.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text("This guide is for general reference. In any emergency, call your local emergency number first and follow your physician's individual care plan.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
