import XCTest
@testable import AllerScan

@MainActor
final class AllerScanTests: XCTestCase {
    func testNormalizeIngredientsRemovesNoise() {
        let normalized = ScanService.normalize("Milk, WHEY-PROTEIN isolate; Groundnut Oil!")
        XCTAssertEqual(normalized, "milk whey protein isolate groundnut oil")
    }

    func testDirectMatchProducesHighRisk() throws {
        let tracked = AllergenCatalog.defaults.filter { ["milk", "peanut"].contains($0.id) }
        let scan = RecognizedScan(
            textBlocks: ["Ingredients: Sugar, Groundnut oil, Cocoa"],
            rawText: "Ingredients: Sugar, Groundnut oil, Cocoa",
            normalizedText: ScanService.normalize("Ingredients: Sugar, Groundnut oil, Cocoa")
        )

        let result = AllergenDetectionService().analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .highRisk)
        let peanut = try XCTUnwrap(result.matches.first(where: { $0.allergenID == "peanut" }))
        XCTAssertEqual(peanut.sourceContext, .ingredients)
        XCTAssertGreaterThanOrEqual(peanut.confidenceScore, 0.9)
        XCTAssertTrue(result.foundIngredientsText.contains("Ingredients:"))
        XCTAssertFalse(result.foundIngredientsText.contains("Telephone"))
    }

    func testCollapsedPhraseRecoveryProducesWarning() {
        let tracked = AllergenCatalog.defaults.filter { $0.id == "milk" }
        let scan = RecognizedScan(
            textBlocks: ["Ingredients: cocoa, wheyprotein, salt"],
            rawText: "Ingredients: cocoa, wheyprotein, salt",
            normalizedText: ScanService.normalize("Ingredients: cocoa, wheyprotein, salt")
        )

        let result = AllergenDetectionService().analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .warning)
        XCTAssertEqual(result.matches.first?.strength, .collapsedPhrase)
        XCTAssertEqual(result.matches.first?.matchedText, "wheyprotein")
        XCTAssertEqual(result.matches.first?.reason, .collapsedPhraseRecovery)
    }

    func testTrackedProfileFiltersAllergens() {
        let tracked = AllergenCatalog.defaults.filter { $0.id == "soy" }
        let scan = RecognizedScan(
            textBlocks: ["Ingredients: Milk solids, soy lecithin"],
            rawText: "Ingredients: Milk solids, soy lecithin",
            normalizedText: ScanService.normalize("Ingredients: Milk solids, soy lecithin")
        )

        let result = AllergenDetectionService().analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches.first?.allergenID, "soy")
    }

    func testNutritionPanelIsIgnored() {
        let tracked = AllergenCatalog.defaults.filter { ["egg", "peanut", "tree_nut", "milk"].contains($0.id) }
        let raw = """
        NUTRITION INFORMATION
        Serving Size 30g
        Energy 120 kcal
        Telephone +94 11 1234567
        """
        let scan = RecognizedScan(
            textBlocks: raw.components(separatedBy: "\n"),
            rawText: raw,
            normalizedText: ScanService.normalize(raw)
        )

        let result = AllergenDetectionService().analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .safe)
        XCTAssertTrue(result.matches.isEmpty)
        XCTAssertEqual(result.foundIngredientsText, "")
    }

    func testMayContainStaysWarning() {
        let tracked = AllergenCatalog.defaults.filter { $0.id == "peanut" }
        let raw = "May contain peanut traces."
        let scan = RecognizedScan(
            textBlocks: [raw],
            rawText: raw,
            normalizedText: ScanService.normalize(raw)
        )

        let result = AllergenDetectionService().analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .warning)
        XCTAssertEqual(result.matches.first?.sourceContext, .mayContain)
    }

    func testHiddenAliasInIngredientsResolvesCorrectAllergen() {
        let tracked = AllergenCatalog.defaults.filter { ["milk", "egg"].contains($0.id) }
        let raw = "Ingredients: sugar, skimmed milk powder, cocoa."
        let scan = RecognizedScan(
            textBlocks: [raw],
            rawText: raw,
            normalizedText: ScanService.normalize(raw)
        )

        let result = AllergenDetectionService().analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .highRisk)
        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches.first?.allergenID, "milk")
        XCTAssertEqual(result.matches.first?.matchedAlias, "skimmed milk powder")
    }

    func testShortNoiseDoesNotTriggerEggOrPeanutFalsePositives() {
        let tracked = AllergenCatalog.defaults.filter { ["egg", "peanut", "tree_nut"].contains($0.id) }
        let scan = RecognizedScan(
            textBlocks: ["2S MI Kotmale NUTRITION INFORMATION"],
            rawText: "2S MI Kotmale NUTRITION INFORMATION",
            normalizedText: ScanService.normalize("2S MI Kotmale NUTRITION INFORMATION")
        )

        let result = AllergenDetectionService().analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .safe)
        XCTAssertTrue(result.matches.isEmpty)
    }

    func testPersistenceStoreSavesProfileHistoryAndSettings() async throws {
        let store = PersistenceStore(inMemory: true)
        try await waitUntilLoaded(store)

        let profile = UserProfile(name: "Ava", trackedAllergenIDs: ["milk", "soy"])
        try store.saveProfile(profile)

        let record = ScanRecord(
            rawText: "Ingredients: soy lecithin",
            normalizedText: "ingredients soy lecithin",
            foundIngredientsText: "Ingredients: soy lecithin",
            matches: [
                DetectedAllergen(
                    id: "soy-hit",
                    allergenID: "soy",
                    allergenName: "Soy",
                    matchedAlias: "soy lecithin",
                    matchedText: "soy lecithin",
                    sourceContext: .ingredients,
                    confidenceScore: 0.95,
                    reason: .exactAlias,
                    strength: .exactAlias
                )
            ],
            riskLevel: .highRisk
        )
        try store.saveScanRecord(record)

        let settings = SecuritySettings(
            isBiometricLockEnabled: true,
            notificationsEnabled: true,
            reminderHour: 9,
            reminderMinute: 30
        )
        try store.updateSecuritySettings(settings)

        XCTAssertEqual(store.activeProfile?.name, "Ava")
        XCTAssertEqual(store.scanHistory.count, 1)
        XCTAssertEqual(store.scanHistory.first?.riskLevel, .highRisk)
        XCTAssertEqual(store.scanHistory.first?.foundIngredientsText, "Ingredients: soy lecithin")
        XCTAssertEqual(store.securitySettings, settings)
    }

    private func waitUntilLoaded(_ store: PersistenceStore) async throws {
        for _ in 0..<50 where !store.isLoaded {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(store.isLoaded)
    }
}
