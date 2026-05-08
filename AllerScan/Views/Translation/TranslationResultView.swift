import SwiftUI
import Translation

struct TranslationResultView: View {
    let sourceImage: UIImage
    let originalText: String
    let detectedLanguage: String
    let languageCode: String?
    let trackedAllergens: [Allergen]
    let onScanAgain: () -> Void
    let onAnalyze: (String) -> Void

    @State private var translatedText: String?
    @State private var isTranslating = true
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var allergenChips: [TranslationAllergenChip] = []

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                sourceImageSection
                detectedLanguageLabel
                originalTextCard
                translatedSection

                if !allergenChips.isEmpty {
                    allergenChipsSection
                }

                actionButtons
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Translation Result")
        .navigationBarTitleDisplayMode(.inline)
        .translationTask(translationConfig) { session in
            do {
                let response = try await session.translate(originalText)
                let service = TranslationService()
                let chips = service.findAllergenOccurrences(
                    in: response.targetText,
                    trackedAllergens: trackedAllergens
                )
                await MainActor.run {
                    translatedText = response.targetText
                    allergenChips = chips
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    isTranslating = false
                }
            }
        }
        .task {
            guard let code = languageCode, code != "en" else {
                translatedText = originalText
                isTranslating = false
                let service = TranslationService()
                allergenChips = service.findAllergenOccurrences(
                    in: originalText,
                    trackedAllergens: trackedAllergens
                )
                return
            }
            translationConfig = .init(
                source: Locale.Language(identifier: code),
                target: Locale.Language(identifier: "en")
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SCAN ANALYSIS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("Translation Result")
                    .font(.title2.bold())
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Live Detection")
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accentRed.opacity(0.08))
            .foregroundStyle(accentRed)
            .clipShape(Capsule())
        }
    }

    // MARK: - Source Image

    private var sourceImageSection: some View {
        Image(uiImage: sourceImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 160)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.caption2)
                    Text("Source Image")
                        .font(.caption2.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(10)
            }
    }

    // MARK: - Detected Language

    private var detectedLanguageLabel: some View {
        Text("DETECTED: \(detectedLanguage.uppercased())")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
    }

    // MARK: - Original Text Card

    private var originalTextCard: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentRed.opacity(0.6))
                .frame(width: 4)

            Text(originalText)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(accentRed.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Translated Section

    private var translatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("TRANSLATED: ENGLISH")
                    .font(.caption.bold())
                    .foregroundStyle(accentRed)
                Spacer()
                Circle().fill(accentRed).frame(width: 6, height: 6)
                Circle().fill(accentRed).frame(width: 6, height: 6)
            }

            if isTranslating {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Translating...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let translated = translatedText {
                highlightedText(translated)
                    .font(.body)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Allergen Chips

    private var allergenChipsSection: some View {
        ChipFlowLayout(spacing: 8) {
            ForEach(allergenChips) { chip in
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(chip.label)
                        .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(accentRed.opacity(0.08))
                .foregroundStyle(accentRed)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                if let text = translatedText {
                    onAnalyze(text)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Analyze Ingredients")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentRed)
            .disabled(translatedText == nil)

            Button {
                onScanAgain()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                    Text("Scan Again")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Highlighted Text

    private func highlightedText(_ text: String) -> Text {
        var attributed = AttributedString(text)

        // Apply bold red highlight to every allergen alias / hidden-alias occurrence.
        // Longer terms first so "milk powder" beats "milk" — applying the same
        // formatting twice on overlapping ranges is harmless.
        for allergen in trackedAllergens {
            let terms = [allergen.name] + allergen.aliases + allergen.hiddenAliases
            let sortedTerms = terms.sorted { $0.count > $1.count }

            for term in sortedTerms {
                var searchStart = attributed.startIndex
                while searchStart < attributed.endIndex,
                      let range = attributed[searchStart..<attributed.endIndex]
                        .range(of: term, options: .caseInsensitive) {
                    attributed[range].inlinePresentationIntent = .stronglyEmphasized
                    attributed[range].foregroundColor = accentRed
                    searchStart = range.upperBound
                }
            }
        }

        return Text(attributed)
    }
}
