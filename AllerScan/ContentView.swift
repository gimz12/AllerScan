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
                toolkitCard(icon: "globe", color: .blue, title: "Travel Allergy Card", subtitle: "Digital cards for international travel")
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
