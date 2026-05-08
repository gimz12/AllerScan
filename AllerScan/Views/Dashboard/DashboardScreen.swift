import SwiftUI

struct DashboardScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var emergencyDeepLink: EmergencyDeepLink
    @State private var showScanner = false
    @State private var showTranslation = false
    @State private var showTravelCard = false
    @State private var showFirstAid = false
    @State private var showProfiles = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    private var scansThisWeek: [ScanRecord] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return store.scanHistory.filter { $0.createdAt >= weekAgo }
    }

    private var alertsThisWeek: Int {
        scansThisWeek.filter { $0.riskLevel == .highRisk || $0.riskLevel == .warning || $0.riskLevel == .notFood }.count
    }

    private var recentScans: [ScanRecord] {
        Array(store.scanHistory.prefix(3))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                quickScanCard
                safetyToolkitSection
                safetyInsightsSection
                if !store.scanHistory.isEmpty {
                    recentActivitySection
                }
                riskProfileSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showScanner) {
            ScannerScreen()
        }
        .fullScreenCover(isPresented: $showTranslation) {
            TranslationScreen()
        }
        .fullScreenCover(isPresented: $showTravelCard) {
            TravelCardScreen()
        }
        .fullScreenCover(isPresented: $showFirstAid) {
            FirstAidListScreen()
        }
        .sheet(isPresented: $showProfiles) {
            NavigationStack {
                ProfilesScreen()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showProfiles = false }
                        }
                    }
            }
        }
        .onChange(of: emergencyDeepLink.shouldOpenFirstAid) { _, shouldOpen in
            if shouldOpen {
                showFirstAid = true
                emergencyDeepLink.shouldOpenFirstAid = false
            }
        }
        .task {
            if emergencyDeepLink.shouldOpenFirstAid {
                showFirstAid = true
                emergencyDeepLink.shouldOpenFirstAid = false
            }
        }
        .sheet(item: $appModel.selectedRecord) { record in
            ResultDetailView(record: record)
        }
    }

    // MARK: Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(accentRed)
                    Text("AllerScan")
                        .font(.title2.bold())
                        .foregroundStyle(accentRed)
                }
                Menu {
                    ForEach(store.profiles) { profile in
                        Button {
                            appModel.switchActiveProfile(to: profile.id)
                        } label: {
                            HStack {
                                Text(profile.name)
                                if profile.id == store.activeProfile?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if store.profiles.count > 0 {
                        Divider()
                    }
                    Button {
                        appModel.startCreatingNewProfile()
                    } label: {
                        Label("Add profile", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Hello, \(store.activeProfile?.name ?? "there")")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        if store.profiles.count > 1 {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Ready to stay safe today?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: Quick Scan

    private var quickScanCard: some View {
        Button { showScanner = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUICK SCAN")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.25))
                        .clipShape(Capsule())
                    Text("Scan Label Now")
                        .font(.title.bold())
                    Text("Just point your camera at labels")
                        .font(.subheadline)
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(
                LinearGradient(colors: [accentRed, accentRed.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Safety Toolkit

    private var safetyToolkitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Safety Toolkit")
                    .font(.headline)
                Spacer()
                Text("3 TOOLS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Button { showFirstAid = true } label: {
                toolkitRow(icon: "cross.case.fill", color: .red, title: "First Aid Guide", subtitle: "Emergency protocol for reactions")
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button { showTravelCard = true } label: {
                    toolkitCard(icon: "globe", color: .blue, title: "Travel Allergy Card", subtitle: "Digital cards for international travel")
                }
                .buttonStyle(.plain)
                Button { showTranslation = true } label: {
                    toolkitCard(icon: "character.book.closed.fill", color: .purple, title: "Translation Mode", subtitle: "Translate labels in 17 languages")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toolkitRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func toolkitCard(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(title).font(.caption.bold())
            Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Safety Insights

    private var safetyInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SAFETY INSIGHTS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Protection Active")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.green.opacity(0.12))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Household Scan Summary")
                    .font(.subheadline.bold())
                Text("\(scansThisWeek.count) items scanned this week, \(alertsThisWeek) alert\(alertsThisWeek == 1 ? "" : "s") flagged")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    statBox(value: String(format: "%02d", scansThisWeek.count), label: "SCANS")
                    statBox(value: String(format: "%02d", alertsThisWeek), label: "ALERTS")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pro Tip").font(.caption.bold())
                    Text("Scan labels before buying to avoid accidental allergen exposure.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title.bold())
            Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Text("VIEW ALL")
                    .font(.caption.bold())
                    .foregroundStyle(accentRed)
            }

            ForEach(recentScans) { record in
                Button { appModel.selectedRecord = record } label: {
                    recentActivityRow(record: record)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recentActivityRow(record: ScanRecord) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(riskColor(for: record.riskLevel).opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: riskIcon(for: record.riskLevel))
                        .foregroundStyle(riskColor(for: record.riskLevel))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(scanDisplayName(for: record))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(riskDescription(for: record))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(record.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(record.riskLevel.title.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(riskColor(for: record.riskLevel))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(riskColor(for: record.riskLevel).opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Risk Profile

    private var riskProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Risk Profile")
                .font(.headline)

            Button { showProfiles = true } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: -8) {
                            ForEach(appModel.trackedAllergens.prefix(5)) { allergen in
                                Circle()
                                    .fill(allergenColor(for: allergen.id))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Text(String(allergen.name.prefix(1)))
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                            }
                            if appModel.trackedAllergens.count > 5 {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Text("+\(appModel.trackedAllergens.count - 5)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                    }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(.tertiary)
                    }

                    Text("Monitoring \(appModel.trackedAllergens.count) allergen\(appModel.trackedAllergens.count == 1 ? "" : "s") — tap to manage profiles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "shield.checkered")
                                .font(.caption2)
                            Text("SAFETY COVERAGE")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(accentRed)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("HIGH PRECISION")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(.green)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Helpers

    private func riskColor(for risk: RiskLevel) -> Color {
        switch risk {
        case .safe: .green
        case .warning: .yellow
        case .highRisk, .notFood: .red
        }
    }

    private func riskIcon(for risk: RiskLevel) -> String {
        switch risk {
        case .safe: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .highRisk: "xmark.octagon.fill"
        case .notFood: "exclamationmark.octagon.fill"
        }
    }

    private func allergenColor(for id: String) -> Color {
        switch id {
        case "milk": .blue
        case "egg": .yellow
        case "peanut": .orange
        case "tree_nut": .brown
        case "soy": .green
        case "wheat": .orange
        case "fish": .cyan
        case "shellfish": .pink
        case "sesame": .mint
        case "mustard": .yellow
        case "celery": .green
        case "lupin": .purple
        case "mollusc": .indigo
        case "sulfite": .red
        case "corn": .yellow
        case "coconut": .brown
        default: .gray
        }
    }

    private func scanDisplayName(for record: ScanRecord) -> String {
        let text = record.foundIngredientsText.isEmpty ? record.rawText : record.foundIngredientsText
        let cleaned = text
            .replacingOccurrences(of: "Ingredients:", with: "")
            .replacingOccurrences(of: "Contains:", with: "")
            .replacingOccurrences(of: "May contain:", with: "")
            .replacingOccurrences(of: "Possible Ingredients:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstItem = cleaned.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Ingredient Scan"
        return String(firstItem.prefix(30))
    }

    private func riskDescription(for record: ScanRecord) -> String {
        if record.riskLevel == .notFood {
            return "Non-food product detected"
        }
        if let match = record.matches.first {
            return "\(match.allergenName) detected"
        }
        return "No allergens detected"
    }
}
