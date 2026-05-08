import SwiftUI

struct ResultDetailView: View {
    let record: ScanRecord
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showIngredients = false
    @State private var firstAidAllergen: Allergen?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    private var firstAidTarget: Allergen? {
        guard let firstMatch = record.matches.first else { return nil }
        return appModel.availableAllergens.first { $0.id == firstMatch.allergenID }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    riskHeader
                    ingredientsCard

                    if !record.matches.isEmpty {
                        detectedAllergensCard
                        whyRiskyCard
                    }

                    if record.riskLevel != .safe {
                        medicalGuidanceCard
                    }

                    if record.riskLevel == .highRisk || record.riskLevel == .notFood {
                        Button {
                            firstAidAllergen = firstAidTarget
                        } label: {
                            Label("View First Aid", systemImage: "cross.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentRed)
                        .disabled(firstAidTarget == nil)
                    }

                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $firstAidAllergen) { allergen in
                FirstAidScreen(allergen: allergen)
            }
        }
    }

    // MARK: - Risk Header

    private var riskHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(riskColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: riskIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(riskColor)
            }

            Text(record.riskLevel.title)
                .font(.title.bold())
                .foregroundStyle(riskColor)

            Text(riskSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Ingredients Card

    private var ingredientsCard: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.25)) { showIngredients.toggle() } } label: {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(riskColor.opacity(0.08))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .font(.title2)
                                .foregroundStyle(riskColor)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.headline)
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            Text(ingredientsSummary)
                                .font(.caption)
                            Image(systemName: showIngredients ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("SCANNED \(timeLabel)")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(16)

            if showIngredients {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ingredientList, id: \.self) { ingredient in
                        HStack(spacing: 10) {
                            let isAllergen = isMatchedAllergen(ingredient)
                            Circle()
                                .fill(isAllergen ? accentRed : .green)
                                .frame(width: 6, height: 6)
                            Text(ingredient.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(isAllergen ? accentRed : .primary)
                            if isAllergen {
                                Spacer()
                                Text("ALLERGEN")
                                    .font(.caption2.bold())
                                    .foregroundStyle(accentRed)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(accentRed.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Detected Allergens

    private var detectedAllergensCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(accentRed)
                Text("Detected Allergens")
                    .font(.subheadline.bold())
            }

            ChipFlowLayout(spacing: 8) {
                ForEach(record.matches) { match in
                    Text(match.matchedAlias)
                        .font(.subheadline.bold())
                        .foregroundStyle(accentRed)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(accentRed.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentRed.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Why Risky

    private var whyRiskyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Why this is risky")
                    .font(.subheadline.bold())
            }

            whyRiskyText
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var whyRiskyText: Text {
        guard let first = record.matches.first else {
            return Text("Potential allergens were detected.")
        }

        let remaining = record.matches.dropFirst()
        var result = Text("This product contains ")
            + Text(first.matchedAlias).bold()
            + Text(", which is a known ")
            + Text(first.allergenName).bold()
            + Text(" allergen in your safety profile.")

        if !remaining.isEmpty {
            let others = remaining.map(\.matchedAlias).joined(separator: ", ")
            result = result + Text(" Also detected: ") + Text(others).bold() + Text(".")
        }

        return result
    }

    // MARK: - Medical Guidance

    private var medicalGuidanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(accentRed)
                Text("Medical Guidance")
                    .font(.subheadline.bold())
                Spacer()
                Text("VERIFIED")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
            }

            ForEach(guidanceItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(accentRed)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentRed.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Label("Scan Again", systemImage: "camera.viewfinder")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Computed Properties

    private var riskColor: Color {
        switch record.riskLevel {
        case .safe: .green
        case .warning: .yellow
        case .highRisk, .notFood: .red
        }
    }

    private var riskIcon: String {
        switch record.riskLevel {
        case .safe: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .highRisk: "exclamationmark.triangle.fill"
        case .notFood: "exclamationmark.octagon.fill"
        }
    }

    private var riskSubtitle: String {
        switch record.riskLevel {
        case .safe: "No tracked allergens were detected."
        case .warning: "Potential allergen terms found in this product."
        case .highRisk: "Unsafe ingredients detected for your profile."
        case .notFood: "This does not appear to be a food product.\nThese ingredients are not safe for consumption."
        }
    }

    private var displayName: String {
        let text = record.foundIngredientsText.isEmpty ? record.rawText : record.foundIngredientsText
        let cleaned = text
            .replacingOccurrences(of: "Ingredients:", with: "")
            .replacingOccurrences(of: "Contains:", with: "")
            .replacingOccurrences(of: "May contain:", with: "")
            .replacingOccurrences(of: "Possible Ingredients:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let items = cleaned.components(separatedBy: ",").prefix(3)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
        let name = items.joined(separator: ", ")
        return name.isEmpty ? "Scanned Product" : String(name.prefix(50))
    }

    private var ingredientsSummary: String {
        return "\(ingredientList.count) ingredient\(ingredientList.count == 1 ? "" : "s") detected"
    }

    private var ingredientList: [String] {
        let text = record.foundIngredientsText.isEmpty ? record.rawText : record.foundIngredientsText
        let cleaned = text
            .replacingOccurrences(of: "Ingredients:", with: "")
            .replacingOccurrences(of: "Contains:", with: "")
            .replacingOccurrences(of: "May contain:", with: "")
            .replacingOccurrences(of: "Possible Ingredients:", with: "")
        return cleaned
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func isMatchedAllergen(_ ingredient: String) -> Bool {
        record.matches.contains { match in
            let alias = match.matchedAlias.lowercased()
            let text = match.matchedText.lowercased()
            return ingredient.contains(alias) || ingredient.contains(text) || alias.contains(ingredient)
        }
    }

    private var timeLabel: String {
        if Calendar.current.isDateInToday(record.createdAt) {
            return "TODAY"
        }
        if Calendar.current.isDateInYesterday(record.createdAt) {
            return "YESTERDAY"
        }
        return record.createdAt.formatted(date: .abbreviated, time: .omitted).uppercased()
    }

    private var guidanceItems: [String] {
        switch record.riskLevel {
        case .highRisk:
            return [
                "Do not consume this product. Even trace amounts may cause a reaction.",
                "Cross-contamination risk is high if the product shares equipment with known allergens."
            ]
        case .warning:
            return [
                "Review the ingredient list carefully before consuming.",
                "When in doubt, avoid the product and consult your healthcare provider."
            ]
        case .notFood:
            return [
                "This is not a food product and must not be consumed.",
                "If accidentally ingested, contact poison control or emergency services immediately."
            ]
        case .safe:
            return []
        }
    }
}
