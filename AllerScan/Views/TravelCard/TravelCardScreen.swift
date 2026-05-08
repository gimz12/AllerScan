import SwiftUI
import Translation

struct TravelCardScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLanguage: TravelCardLanguage = .spanish
    @State private var showFullScreen = false

    /// Runtime ML translations for custom allergens (those without a curated entry).
    /// Keyed by allergen ID. Cleared and re-translated whenever the language changes.
    @State private var runtimeTranslations: [String: String] = [:]
    @State private var translationConfig: TranslationSession.Configuration?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    private var customAllergensNeedingTranslation: [Allergen] {
        appModel.trackedAllergens.filter {
            AllergenTravelTranslations.curatedTranslation($0, to: selectedLanguage) == nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    cardSection
                    actionButtonsSection
                    travelTipSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
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
            .fullScreenCover(isPresented: $showFullScreen) {
                TravelCardFullScreenView(
                    language: selectedLanguage,
                    allergens: appModel.trackedAllergens,
                    profileName: store.activeProfile?.name ?? "Verified User",
                    runtimeTranslations: runtimeTranslations
                )
            }
            .task(id: selectedLanguage) {
                // Clear stale runtime translations and request new ones for the new language.
                runtimeTranslations = [:]
                translationConfig = .init(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: selectedLanguage.rawValue)
                )
            }
            .translationTask(translationConfig) { session in
                // Translate custom allergen names that don't have a curated entry.
                let needsTranslation = customAllergensNeedingTranslation
                for allergen in needsTranslation {
                    if let response = try? await session.translate(allergen.name) {
                        await MainActor.run {
                            runtimeTranslations[allergen.id] = response.targetText
                        }
                    }
                }
            }
        }
    }

    /// Resolves an allergen's display name in the selected language:
    /// curated translation → runtime ML translation → English name.
    private func translatedDisplayName(for allergen: Allergen) -> String {
        if let curated = AllergenTravelTranslations.curatedTranslation(allergen, to: selectedLanguage) {
            return curated
        }
        if let runtime = runtimeTranslations[allergen.id] {
            return runtime
        }
        return allergen.name
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Allergy")
                    .font(.largeTitle.bold())
                Text("Information")
                    .font(.largeTitle.bold())
            }
            Spacer()
            Text("DIGITAL\nCARD")
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        }
    }

    private var cardSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(accentRed)
                .frame(height: 6)

            VStack(alignment: .leading, spacing: 20) {
                englishSection
                translationDivider
                translatedSection
                Divider()
                verifiedUserRow
            }
            .padding(20)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var englishSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ENGLISH")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text("I am allergic to:")
                .font(.title2.bold())

            VStack(spacing: 8) {
                ForEach(appModel.trackedAllergens) { allergen in
                    allergenChip(name: chipDisplayName(for: allergen), icon: AllergenTravelTranslations.icon(for: allergen.id))
                }
            }
        }
    }

    private var translationDivider: some View {
        HStack {
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
            Image(systemName: "character.bubble")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
        }
    }

    private var translatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            languagePicker

            Text(selectedLanguage.allergyPhrase)
                .font(.title2.bold())
                .multilineTextAlignment(selectedLanguage.isRTL ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: selectedLanguage.isRTL ? .trailing : .leading)

            VStack(alignment: selectedLanguage.isRTL ? .trailing : .leading, spacing: 10) {
                ForEach(appModel.trackedAllergens) { allergen in
                    translatedAllergenRow(allergen: allergen)
                }
            }
        }
    }

    private var languagePicker: some View {
        Menu {
            ForEach(TravelCardLanguage.allCases) { language in
                Button {
                    selectedLanguage = language
                } label: {
                    HStack {
                        Text("\(language.displayName) — \(language.nativeName)")
                        if language == selectedLanguage {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedLanguage.displayName.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
    }

    private func allergenChip(name: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(accentRed)
                .frame(width: 24, height: 24)
                .background(accentRed.opacity(0.1))
                .clipShape(Circle())

            Text(name)
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func translatedAllergenRow(allergen: Allergen) -> some View {
        let translated = translatedDisplayName(for: allergen)
        return HStack(spacing: 10) {
            Circle()
                .fill(accentRed)
                .frame(width: 6, height: 6)
            Text(translated)
                .font(.body.weight(.semibold))
            Spacer()
        }
    }

    private var verifiedUserRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.gray.opacity(0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text("VERIFIED USER")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(store.activeProfile?.name ?? "Verified User")
                    .font(.subheadline.bold())
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.blue)
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 10) {
            Button {
                showFullScreen = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("Show Full Screen")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentRed)

            ShareLink(item: shareText) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Card")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }

    private var travelTipSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Travel Tip")
                    .font(.subheadline.bold())
                Text("Show this card to servers and kitchen staff when ordering food abroad. It's pre-translated for clarity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func chipDisplayName(for allergen: Allergen) -> String {
        switch allergen.id {
        case "wheat": return "Gluten"
        case "milk": return "Dairy"
        case "tree_nut": return "Tree Nuts"
        default: return allergen.name
        }
    }

    private var shareText: String {
        let allergens = appModel.trackedAllergens
        guard !allergens.isEmpty else { return "Allergy Information" }
        let englishLines = allergens.map { "• \(chipDisplayName(for: $0))" }.joined(separator: "\n")
        let translatedLines = allergens
            .map { "• \(translatedDisplayName(for: $0))" }
            .joined(separator: "\n")
        return """
        ALLERGY INFORMATION

        I am allergic to:
        \(englishLines)

        \(selectedLanguage.allergyPhrase)
        \(translatedLines)
        """
    }
}
