import SwiftUI
import Translation

struct ContentView: View {
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        Group {
            if !store.isLoaded {
                ProgressView("Loading AllerScan...")
            } else if appModel.isLocked && store.activeProfile != nil {
                LockedView()
            } else if store.activeProfile == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .alert("AllerScan", isPresented: Binding(
            get: { appModel.lastErrorMessage != nil },
            set: { if !$0 { appModel.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.lastErrorMessage ?? "")
        }
    }
}

private struct OnboardingView: View {
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

private struct AddCustomAllergenSheet: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var aliasesText = ""

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Allergen name", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("E.g. Oat, Kiwi, Cinnamon")
                }

                Section {
                    TextField("milk, dairy, cream", text: $aliasesText)
                } header: {
                    Text("Aliases (comma separated)")
                } footer: {
                    Text("Add words that might appear on ingredient labels. The scanner will look for these terms. If left empty, the allergen name itself is used.")
                }

                Section {
                    if !previewAliases.isEmpty {
                        ChipFlowLayout(spacing: 6) {
                            ForEach(previewAliases, id: \.self) { alias in
                                Text(alias)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(accentRed.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    } else {
                        Text("Enter aliases above to preview")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Add Custom Allergen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        appModel.addCustomAllergen(name: name, aliasesText: aliasesText)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var previewAliases: [String] {
        let text = aliasesText.isEmpty ? name : aliasesText
        return text
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}

private struct MainTabView: View {
    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        TabView {
            DashboardScreen()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            HistoryScreen()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }

            SettingsScreen()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(accentRed)
    }
}

// MARK: - Dashboard

private struct DashboardScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @State private var showScanner = false
    @State private var showTranslation = false
    @State private var showTravelCard = false

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
                Text("Hello, \(store.activeProfile?.name ?? "there")")
                    .font(.title3.bold())
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

            toolkitRow(icon: "cross.case.fill", color: .red, title: "First Aid Guide", subtitle: "Emergency protocol for reactions")

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

            VStack(alignment: .leading, spacing: 12) {
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

                Text("Monitoring \(appModel.trackedAllergens.count) allergen\(appModel.trackedAllergens.count == 1 ? "" : "s")")
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

// MARK: - Scanner

private struct ScannerScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @StateObject private var cameraModel = CameraCaptureModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black)
                    .overlay {
                        if appModel.cameraPermissionGranted && cameraModel.isConfigured {
                            CameraPreview(session: cameraModel.session)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.metering.unknown")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white)
                                Text(cameraModel.statusMessage)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .frame(height: 360)
                    .overlay(alignment: .topLeading) {
                        Text("Tracking: \(store.activeProfile?.name ?? "Profile")")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding()
                    }

                if appModel.isProcessingScan {
                    ProgressView("Analyzing ingredients...")
                } else {
                    Text(cameraModel.statusMessage)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        do {
                            let image = try await cameraModel.capturePhoto()
                            await appModel.processCapturedImage(image)
                        } catch {
                            appModel.lastErrorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Scan Ingredient Label", systemImage: "viewfinder.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!appModel.cameraPermissionGranted || appModel.isProcessingScan || !cameraModel.isConfigured)

                List(appModel.trackedAllergens) { allergen in
                    Label(allergen.name, systemImage: "checkmark.shield")
                }
                .frame(maxHeight: 220)
                .scrollContentBackground(.hidden)
            }
            .padding()
            .navigationTitle("Scanner")
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
            .task {
                await cameraModel.configureIfNeeded()
            }
            .sheet(item: $appModel.selectedRecord) { record in
                ResultDetailView(record: record)
            }
        }
    }
}

private struct ResultDetailView: View {
    let record: ScanRecord
    @Environment(\.dismiss) private var dismiss
    @State private var showIngredients = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

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
                        Button {} label: {
                            Label("View First Aid", systemImage: "cross.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentRed)
                    }

                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Translation

private struct TranslationScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var cameraModel = CameraCaptureModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showResult = false
    @State private var capturedImage: UIImage?
    @State private var originalText: String?
    @State private var detectedLanguage: String?
    @State private var languageCode: String?
    @State private var isProcessing = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            Group {
                if showResult, let image = capturedImage, let text = originalText {
                    TranslationResultView(
                        sourceImage: image,
                        originalText: text,
                        detectedLanguage: detectedLanguage ?? "Unknown",
                        languageCode: languageCode,
                        trackedAllergens: appModel.trackedAllergens,
                        onScanAgain: {
                            showResult = false
                            capturedImage = nil
                            originalText = nil
                            detectedLanguage = nil
                            languageCode = nil
                        },
                        onAnalyze: { translatedText in
                            Task {
                                await appModel.analyzeTranslatedText(translatedText)
                            }
                        }
                    )
                } else {
                    cameraScanView
                }
            }
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
        }
        .sheet(item: $appModel.selectedRecord) { record in
            ResultDetailView(record: record)
        }
    }

    private var cameraScanView: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)
                .overlay {
                    if appModel.cameraPermissionGranted && cameraModel.isConfigured {
                        CameraPreview(session: cameraModel.session)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.metering.unknown")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                            Text(cameraModel.statusMessage)
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(height: 360)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "character.book.closed.fill")
                            .font(.caption)
                        Text("Translation Mode")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding()
                }

            if isProcessing {
                ProgressView("Recognizing text...")
            } else {
                Text("Point camera at a foreign language ingredient label")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    do {
                        let image = try await cameraModel.capturePhoto()
                        await processCapture(image)
                    } catch {
                        appModel.lastErrorMessage = error.localizedDescription
                    }
                }
            } label: {
                Label("Capture Label", systemImage: "camera.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(accentRed)
            .disabled(!appModel.cameraPermissionGranted || isProcessing || !cameraModel.isConfigured)

            Spacer()
        }
        .padding()
        .navigationTitle("Translation Mode")
        .task {
            await cameraModel.configureIfNeeded()
        }
    }

    private func processCapture(_ image: UIImage) async {
        isProcessing = true
        capturedImage = image

        do {
            let scanService = ScanService()
            let scan = try await scanService.recognizeMultiLanguage(from: image)
            originalText = scan.rawText

            let translationService = TranslationService()
            if let detected = translationService.detectLanguage(for: scan.rawText) {
                detectedLanguage = detected.name
                languageCode = detected.code
            } else {
                detectedLanguage = "Unknown"
                languageCode = nil
            }

            showResult = true
        } catch {
            appModel.lastErrorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}

private struct TranslationResultView: View {
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
        struct MatchInfo: Comparable {
            let range: Range<String.Index>
            let text: String
            static func < (lhs: MatchInfo, rhs: MatchInfo) -> Bool {
                lhs.range.lowerBound < rhs.range.lowerBound
            }
        }

        var matches: [MatchInfo] = []

        for allergen in trackedAllergens {
            let terms = [allergen.name] + allergen.aliases + allergen.hiddenAliases
            let sortedTerms = terms.sorted { $0.count > $1.count }

            for term in sortedTerms {
                var searchStart = text.startIndex
                while searchStart < text.endIndex {
                    guard let foundRange = text.range(of: term, options: .caseInsensitive, range: searchStart..<text.endIndex) else { break }
                    let overlaps = matches.contains { $0.range.overlaps(foundRange) }
                    if !overlaps {
                        matches.append(MatchInfo(range: foundRange, text: String(text[foundRange])))
                    }
                    searchStart = foundRange.upperBound
                }
            }
        }

        matches.sort()

        if matches.isEmpty { return Text(text) }

        var result = Text("")
        var currentIndex = text.startIndex

        for match in matches {
            if currentIndex < match.range.lowerBound {
                result = result + Text(text[currentIndex..<match.range.lowerBound])
            }
            result = result + Text(match.text).bold().foregroundColor(accentRed)
            currentIndex = match.range.upperBound
        }

        if currentIndex < text.endIndex {
            result = result + Text(text[currentIndex..<text.endIndex])
        }

        return result
    }
}

// MARK: - Travel Card

private enum TravelCardLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case vietnamese = "vi"
    case russian = "ru"
    case ukrainian = "uk"
    case japanese = "ja"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case thai = "th"
    case arabic = "ar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .vietnamese: "Vietnamese"
        case .russian: "Russian"
        case .ukrainian: "Ukrainian"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .chineseSimplified: "Chinese (Simplified)"
        case .chineseTraditional: "Chinese (Traditional)"
        case .thai: "Thai"
        case .arabic: "Arabic"
        }
    }

    var nativeName: String {
        switch self {
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .portuguese: "Português"
        case .vietnamese: "Tiếng Việt"
        case .russian: "Русский"
        case .ukrainian: "Українська"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .chineseSimplified: "简体中文"
        case .chineseTraditional: "繁體中文"
        case .thai: "ไทย"
        case .arabic: "العربية"
        }
    }

    var allergyPhrase: String {
        switch self {
        case .spanish: "Soy alérgico/a a:"
        case .french: "Je suis allergique à :"
        case .german: "Ich bin allergisch gegen:"
        case .italian: "Sono allergico/a a:"
        case .portuguese: "Sou alérgico/a a:"
        case .vietnamese: "Tôi bị dị ứng với:"
        case .russian: "У меня аллергия на:"
        case .ukrainian: "У мене алергія на:"
        case .japanese: "私は次のものにアレルギーがあります："
        case .korean: "저는 다음에 알레르기가 있습니다:"
        case .chineseSimplified: "我对以下食物过敏："
        case .chineseTraditional: "我對以下食物過敏："
        case .thai: "ฉันแพ้:"
        case .arabic: "أنا أعاني من حساسية تجاه:"
        }
    }

    var safetyPhrase: String {
        switch self {
        case .spanish: "Incluso pequeñas cantidades pueden causar una reacción grave. Por favor, evite cualquier traza o contaminación cruzada. Gracias."
        case .french: "Même de petites quantités peuvent provoquer une réaction grave. Veuillez éviter toute trace ou contamination croisée. Merci."
        case .german: "Schon kleine Mengen können eine schwere Reaktion auslösen. Bitte vermeiden Sie jegliche Spuren oder Kreuzkontamination. Danke."
        case .italian: "Anche piccole quantità possono causare una reazione grave. Si prega di evitare qualsiasi traccia o contaminazione incrociata. Grazie."
        case .portuguese: "Mesmo pequenas quantidades podem causar uma reação grave. Por favor, evite qualquer vestígio ou contaminação cruzada. Obrigado."
        case .vietnamese: "Ngay cả một lượng nhỏ cũng có thể gây phản ứng nghiêm trọng. Vui lòng tránh bất kỳ dấu vết hoặc lây nhiễm chéo nào. Cảm ơn."
        case .russian: "Даже малые количества могут вызвать серьёзную реакцию. Пожалуйста, избегайте любых следов или перекрёстного загрязнения. Спасибо."
        case .ukrainian: "Навіть малі кількості можуть викликати серйозну реакцію. Будь ласка, уникайте будь-яких слідів чи перехресного забруднення. Дякую."
        case .japanese: "少量でも重い反応を引き起こすことがあります。微量混入や交差汚染にもご注意ください。ありがとうございます。"
        case .korean: "소량이라도 심각한 반응을 일으킬 수 있습니다. 어떠한 흔적이나 교차 오염도 피해 주십시오. 감사합니다."
        case .chineseSimplified: "即使少量也可能引起严重反应。请避免任何残留或交叉污染。谢谢。"
        case .chineseTraditional: "即使少量也可能引起嚴重反應。請避免任何殘留或交叉污染。謝謝。"
        case .thai: "แม้ปริมาณเล็กน้อยก็อาจทำให้เกิดอาการรุนแรงได้ กรุณาหลีกเลี่ยงร่องรอยหรือการปนเปื้อนข้าม ขอบคุณค่ะ/ครับ"
        case .arabic: "حتى الكميات الصغيرة قد تسبب تفاعلاً خطيراً. يرجى تجنب أي آثار أو تلوث متبادل. شكراً."
        }
    }

    var isRTL: Bool { self == .arabic }
}

private enum AllergenTravelTranslations {
    static func translate(_ allergen: Allergen, to language: TravelCardLanguage) -> String {
        table[allergen.id]?[language] ?? allergen.name
    }

    private static let table: [String: [TravelCardLanguage: String]] = [
        "milk": [
            .spanish: "Lácteos", .french: "Produits laitiers", .german: "Milch",
            .italian: "Latticini", .portuguese: "Lacticínios", .vietnamese: "Sữa",
            .russian: "Молоко", .ukrainian: "Молоко", .japanese: "乳製品",
            .korean: "유제품", .chineseSimplified: "乳制品", .chineseTraditional: "乳製品",
            .thai: "นม", .arabic: "منتجات الألبان"
        ],
        "egg": [
            .spanish: "Huevo", .french: "Œuf", .german: "Ei",
            .italian: "Uovo", .portuguese: "Ovo", .vietnamese: "Trứng",
            .russian: "Яйца", .ukrainian: "Яйця", .japanese: "卵",
            .korean: "달걀", .chineseSimplified: "鸡蛋", .chineseTraditional: "雞蛋",
            .thai: "ไข่", .arabic: "بيض"
        ],
        "peanut": [
            .spanish: "Cacahuetes", .french: "Arachides", .german: "Erdnüsse",
            .italian: "Arachidi", .portuguese: "Amendoins", .vietnamese: "Đậu phộng",
            .russian: "Арахис", .ukrainian: "Арахіс", .japanese: "ピーナッツ",
            .korean: "땅콩", .chineseSimplified: "花生", .chineseTraditional: "花生",
            .thai: "ถั่วลิสง", .arabic: "فول سوداني"
        ],
        "tree_nut": [
            .spanish: "Frutos secos", .french: "Fruits à coque", .german: "Nüsse",
            .italian: "Frutta a guscio", .portuguese: "Frutos secos", .vietnamese: "Các loại hạt",
            .russian: "Орехи", .ukrainian: "Горіхи", .japanese: "ナッツ類",
            .korean: "견과류", .chineseSimplified: "坚果", .chineseTraditional: "堅果",
            .thai: "ถั่วเปลือกแข็ง", .arabic: "المكسرات"
        ],
        "soy": [
            .spanish: "Soja", .french: "Soja", .german: "Soja",
            .italian: "Soia", .portuguese: "Soja", .vietnamese: "Đậu nành",
            .russian: "Соя", .ukrainian: "Соя", .japanese: "大豆",
            .korean: "콩", .chineseSimplified: "大豆", .chineseTraditional: "大豆",
            .thai: "ถั่วเหลือง", .arabic: "فول الصويا"
        ],
        "wheat": [
            .spanish: "Trigo / Gluten", .french: "Blé / Gluten", .german: "Weizen / Gluten",
            .italian: "Grano / Glutine", .portuguese: "Trigo / Glúten", .vietnamese: "Lúa mì / Gluten",
            .russian: "Пшеница / Глютен", .ukrainian: "Пшениця / Глютен", .japanese: "小麦 / グルテン",
            .korean: "밀 / 글루텐", .chineseSimplified: "小麦 / 麸质", .chineseTraditional: "小麥 / 麩質",
            .thai: "ข้าวสาลี / กลูเตน", .arabic: "القمح / الغلوتين"
        ],
        "fish": [
            .spanish: "Pescado", .french: "Poisson", .german: "Fisch",
            .italian: "Pesce", .portuguese: "Peixe", .vietnamese: "Cá",
            .russian: "Рыба", .ukrainian: "Риба", .japanese: "魚",
            .korean: "생선", .chineseSimplified: "鱼", .chineseTraditional: "魚",
            .thai: "ปลา", .arabic: "السمك"
        ],
        "shellfish": [
            .spanish: "Mariscos", .french: "Crustacés", .german: "Schalentiere",
            .italian: "Crostacei", .portuguese: "Mariscos", .vietnamese: "Hải sản có vỏ",
            .russian: "Ракообразные", .ukrainian: "Ракоподібні", .japanese: "甲殻類",
            .korean: "갑각류", .chineseSimplified: "贝类", .chineseTraditional: "貝類",
            .thai: "หอย / กุ้ง / ปู", .arabic: "المحار والقشريات"
        ],
        "sesame": [
            .spanish: "Sésamo", .french: "Sésame", .german: "Sesam",
            .italian: "Sesamo", .portuguese: "Gergelim", .vietnamese: "Vừng",
            .russian: "Кунжут", .ukrainian: "Кунжут", .japanese: "ごま",
            .korean: "참깨", .chineseSimplified: "芝麻", .chineseTraditional: "芝麻",
            .thai: "งา", .arabic: "السمسم"
        ],
        "mustard": [
            .spanish: "Mostaza", .french: "Moutarde", .german: "Senf",
            .italian: "Senape", .portuguese: "Mostarda", .vietnamese: "Mù tạt",
            .russian: "Горчица", .ukrainian: "Гірчиця", .japanese: "マスタード",
            .korean: "겨자", .chineseSimplified: "芥末", .chineseTraditional: "芥末",
            .thai: "มัสตาร์ด", .arabic: "الخردل"
        ],
        "celery": [
            .spanish: "Apio", .french: "Céleri", .german: "Sellerie",
            .italian: "Sedano", .portuguese: "Aipo", .vietnamese: "Cần tây",
            .russian: "Сельдерей", .ukrainian: "Селера", .japanese: "セロリ",
            .korean: "셀러리", .chineseSimplified: "芹菜", .chineseTraditional: "芹菜",
            .thai: "ขึ้นฉ่าย", .arabic: "الكرفس"
        ],
        "lupin": [
            .spanish: "Altramuz", .french: "Lupin", .german: "Lupinen",
            .italian: "Lupini", .portuguese: "Tremoço", .vietnamese: "Đậu lupin",
            .russian: "Люпин", .ukrainian: "Люпин", .japanese: "ルピナス",
            .korean: "루핀", .chineseSimplified: "羽扇豆", .chineseTraditional: "羽扇豆",
            .thai: "ลูพิน", .arabic: "الترمس"
        ],
        "mollusc": [
            .spanish: "Moluscos", .french: "Mollusques", .german: "Weichtiere",
            .italian: "Molluschi", .portuguese: "Moluscos", .vietnamese: "Động vật thân mềm",
            .russian: "Моллюски", .ukrainian: "Молюски", .japanese: "軟体動物",
            .korean: "연체동물", .chineseSimplified: "软体动物", .chineseTraditional: "軟體動物",
            .thai: "หอย", .arabic: "الرخويات"
        ],
        "sulfite": [
            .spanish: "Sulfitos", .french: "Sulfites", .german: "Sulfite",
            .italian: "Solfiti", .portuguese: "Sulfitos", .vietnamese: "Sulfit",
            .russian: "Сульфиты", .ukrainian: "Сульфіти", .japanese: "亜硫酸塩",
            .korean: "아황산염", .chineseSimplified: "亚硫酸盐", .chineseTraditional: "亞硫酸鹽",
            .thai: "ซัลไฟต์", .arabic: "الكبريتات"
        ],
        "corn": [
            .spanish: "Maíz", .french: "Maïs", .german: "Mais",
            .italian: "Mais", .portuguese: "Milho", .vietnamese: "Ngô",
            .russian: "Кукуруза", .ukrainian: "Кукурудза", .japanese: "とうもろこし",
            .korean: "옥수수", .chineseSimplified: "玉米", .chineseTraditional: "玉米",
            .thai: "ข้าวโพด", .arabic: "الذرة"
        ],
        "coconut": [
            .spanish: "Coco", .french: "Noix de coco", .german: "Kokosnuss",
            .italian: "Cocco", .portuguese: "Coco", .vietnamese: "Dừa",
            .russian: "Кокос", .ukrainian: "Кокос", .japanese: "ココナッツ",
            .korean: "코코넛", .chineseSimplified: "椰子", .chineseTraditional: "椰子",
            .thai: "มะพร้าว", .arabic: "جوز الهند"
        ]
    ]

    static func icon(for allergenID: String) -> String {
        switch allergenID {
        case "milk": return "drop.fill"
        case "egg": return "circle.fill"
        case "fish", "shellfish", "mollusc": return "fish.fill"
        case "sesame": return "circle.grid.2x2.fill"
        case "mustard": return "drop.fill"
        case "sulfite": return "drop.triangle.fill"
        case "peanut", "tree_nut", "soy", "wheat", "lupin", "celery", "corn", "coconut": return "leaf.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
}

private struct TravelCardScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLanguage: TravelCardLanguage = .spanish
    @State private var showFullScreen = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

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
                    profileName: store.activeProfile?.name ?? "Verified User"
                )
            }
        }
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
        let translated = AllergenTravelTranslations.translate(allergen, to: selectedLanguage)
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
            .map { "• \(AllergenTravelTranslations.translate($0, to: selectedLanguage))" }
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

private struct TravelCardFullScreenView: View {
    let language: TravelCardLanguage
    let allergens: [Allergen]
    let profileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var originalBrightness: CGFloat = UIScreen.main.brightness

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: .now)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    emergencyBanner
                    content
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            closeButton
        }
        .statusBarHidden()
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIScreen.main.brightness = originalBrightness
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var emergencyBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            Text("SEVERE FOOD ALLERGY")
                .font(.title3.weight(.heavy))
                .tracking(1)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(accentRed)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 28) {
            englishSection
            divider
            translatedSection
            divider
            safetyNote
            footer
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 28)
    }

    private var englishSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ENGLISH")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            Text("I am allergic to:")
                .font(.system(size: 32, weight: .bold))

            VStack(spacing: 12) {
                ForEach(allergens) { allergen in
                    fullScreenAllergenRow(name: allergen.name, allergenID: allergen.id)
                }
            }
        }
    }

    private var translatedSection: some View {
        VStack(alignment: language.isRTL ? .trailing : .leading, spacing: 16) {
            Text(language.displayName.uppercased())
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(accentRed)
                .tracking(1.5)

            Text(language.allergyPhrase)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(language.isRTL ? .trailing : .leading)

            VStack(spacing: 12) {
                ForEach(allergens) { allergen in
                    fullScreenAllergenRow(
                        name: AllergenTravelTranslations.translate(allergen, to: language),
                        allergenID: allergen.id
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: language.isRTL ? .trailing : .leading)
    }

    private func fullScreenAllergenRow(name: String, allergenID: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: AllergenTravelTranslations.icon(for: allergenID))
                .font(.title2)
                .foregroundStyle(accentRed)
                .frame(width: 36, height: 36)
                .background(accentRed.opacity(0.12))
                .clipShape(Circle())

            Text(name)
                .font(.system(size: 24, weight: .bold))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var safetyNote: some View {
        VStack(alignment: language.isRTL ? .trailing : .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(accentRed)
                Text("Cross-contamination warning")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            Text(language.safetyPhrase)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(language.isRTL ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: language.isRTL ? .trailing : .leading)
        }
        .padding(16)
        .background(accentRed.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(profileName)
                    .font(.headline)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("AllerScan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
        .padding(.top, 4)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.5))
                .clipShape(Circle())
        }
        .padding(.top, 12)
        .padding(.trailing, 16)
    }
}

// MARK: - Flow Layout for Allergen Chips

private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += lineHeight + spacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct HistoryScreen: View {
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                if store.scanHistory.isEmpty {
                    ContentUnavailableView("No scans yet", systemImage: "doc.text.viewfinder", description: Text("Capture an ingredient label to create your first scan history item."))
                } else {
                    ForEach(store.scanHistory) { record in
                        Button {
                            appModel.selectedRecord = record
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(record.riskLevel.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundStyle(.secondary)
                                }
                                Text(record.matches.map(\.allergenName).joined(separator: ", ").ifEmpty("No tracked allergens detected"))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: appModel.deleteHistory)
                }
            }
            .navigationTitle("History")
            .sheet(item: $appModel.selectedRecord) { record in
                ResultDetailView(record: record)
            }
        }
    }
}

private struct SettingsScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.activeProfile?.name ?? "No profile")
                            .font(.headline)
                        Text("\(store.activeProfile?.trackedAllergenIDs.count ?? 0) tracked allergens")
                            .foregroundStyle(.secondary)
                    }
                    Button("Edit profile") {
                        if let profile = store.activeProfile {
                            appModel.profileName = profile.name
                            appModel.selectedAllergenIDs = Set(profile.trackedAllergenIDs)
                            appModel.isEditingProfile = true
                        }
                    }
                }

                Section("Security") {
                    Toggle("Biometric app lock", isOn: Binding(
                        get: { store.securitySettings.isBiometricLockEnabled },
                        set: { newValue in
                            Task {
                                await appModel.updateBiometricLock(newValue)
                            }
                        }
                    ))
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
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $appModel.isEditingProfile) {
                NavigationStack {
                    OnboardingView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    appModel.isEditingProfile = false
                                }
                            }
                        }
                }
            }
        }
    }
}

private struct LockedView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("AllerScan Locked")
                .font(.title2.bold())
            Text("Use Face ID or Touch ID to unlock the app.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Unlock") {
                Task {
                    await appModel.unlockApp()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }
}

private struct PermissionRow: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension String {
    func ifEmpty(_ replacement: String) -> String {
        isEmpty ? replacement : self
    }
}
