import XCTest
@testable import AllerScan
import CoreLocation

@MainActor
final class AllerScanTests: XCTestCase {

    // MARK: - ScanService.normalize

    func testNormalizeIngredientsRemovesNoise() {
        let normalized = ScanService.normalize("Milk, WHEY-PROTEIN isolate; Groundnut Oil!")
        XCTAssertEqual(normalized, "milk whey protein isolate groundnut oil")
    }

    func testNormalizeIsCaseInsensitiveAndDiacriticInsensitive() {
        XCTAssertEqual(ScanService.normalize("Café Crème"), "cafe creme")
        XCTAssertEqual(ScanService.normalize("CAFE CREME"), "cafe creme")
    }

    func testNormalizeCollapsesWhitespace() {
        let result = ScanService.normalize("  hello\t\nworld   foo  ")
        XCTAssertEqual(result, "hello world foo")
    }

    // MARK: - AllergenDetectionService

    func testDirectMatchProducesHighRisk() async throws {
        let tracked = AllergenCatalog.defaults.filter { ["milk", "peanut"].contains($0.id) }
        let scan = RecognizedScan(
            textBlocks: ["Ingredients: Sugar, Groundnut oil, Cocoa"],
            rawText: "Ingredients: Sugar, Groundnut oil, Cocoa",
            normalizedText: ScanService.normalize("Ingredients: Sugar, Groundnut oil, Cocoa")
        )

        let result = await AllergenDetectionService(useFoundationModel: false).analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .highRisk)
        let peanut = try XCTUnwrap(result.matches.first(where: { $0.allergenID == "peanut" }))
        XCTAssertEqual(peanut.sourceContext, .ingredients)
        XCTAssertGreaterThanOrEqual(peanut.confidenceScore, 0.9)
    }

    func testTrackedProfileFiltersAllergens() async {
        let tracked = AllergenCatalog.defaults.filter { $0.id == "soy" }
        let scan = RecognizedScan(
            textBlocks: ["Ingredients: Milk solids, soy lecithin"],
            rawText: "Ingredients: Milk solids, soy lecithin",
            normalizedText: ScanService.normalize("Ingredients: Milk solids, soy lecithin")
        )

        let result = await AllergenDetectionService(useFoundationModel: false).analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches.first?.allergenID, "soy")
    }

    func testMayContainStaysWarning() async {
        let tracked = AllergenCatalog.defaults.filter { $0.id == "peanut" }
        let raw = "May contain peanut traces."
        let scan = RecognizedScan(
            textBlocks: [raw],
            rawText: raw,
            normalizedText: ScanService.normalize(raw)
        )

        let result = await AllergenDetectionService(useFoundationModel: false).analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .warning)
        XCTAssertEqual(result.matches.first?.sourceContext, .mayContain)
    }

    func testHiddenAliasInIngredientsResolvesCorrectAllergen() async {
        let tracked = AllergenCatalog.defaults.filter { ["milk", "egg"].contains($0.id) }
        let raw = "Ingredients: sugar, skimmed milk powder, cocoa."
        let scan = RecognizedScan(
            textBlocks: [raw],
            rawText: raw,
            normalizedText: ScanService.normalize(raw)
        )

        let result = await AllergenDetectionService(useFoundationModel: false).analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .highRisk)
        XCTAssertEqual(result.matches.first?.allergenID, "milk")
    }

    func testNutritionPanelIsIgnored() async {
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

        let result = await AllergenDetectionService(useFoundationModel: false).analyze(scan: scan, trackedAllergens: tracked)

        XCTAssertEqual(result.riskLevel, .safe)
        XCTAssertTrue(result.matches.isEmpty)
    }

    func testPluralIngredientsAreMatched() async {
        // Translated labels often use plural forms (peanuts, eggs, soybeans).
        // The detector must match the singular allergen alias against the plural.
        let tracked = AllergenCatalog.defaults.filter { ["peanut", "egg", "soy"].contains($0.id) }
        let raw = "Ingredients: wheat flour, sugar, peanuts, eggs, soybeans"
        let scan = RecognizedScan(
            textBlocks: [raw],
            rawText: raw,
            normalizedText: ScanService.normalize(raw)
        )

        let result = await AllergenDetectionService(useFoundationModel: false).analyze(scan: scan, trackedAllergens: tracked)

        let matchedIDs = Set(result.matches.map(\.allergenID))
        XCTAssertTrue(matchedIDs.contains("peanut"), "Should detect 'peanuts' as peanut allergen")
        XCTAssertTrue(matchedIDs.contains("egg"), "Should detect 'eggs' as egg allergen")
        XCTAssertTrue(matchedIDs.contains("soy"), "Should detect 'soybeans' as soy allergen")
        XCTAssertEqual(result.riskLevel, .highRisk)
    }

    func testEmptyTrackedAllergensProducesSafeOrUnchangedResult() async {
        let scan = RecognizedScan(
            textBlocks: ["Ingredients: peanut, milk, wheat"],
            rawText: "Ingredients: peanut, milk, wheat",
            normalizedText: ScanService.normalize("Ingredients: peanut, milk, wheat")
        )

        let result = await AllergenDetectionService(useFoundationModel: false).analyze(scan: scan, trackedAllergens: [])

        XCTAssertTrue(result.matches.isEmpty)
        XCTAssertEqual(result.riskLevel, .safe)
    }

    // MARK: - AllergenCatalog

    func testAllergenCatalogContainsExpectedAllergens() {
        let ids = Set(AllergenCatalog.defaults.map(\.id))
        let expected: Set<String> = [
            "milk", "egg", "peanut", "tree_nut", "soy", "wheat", "fish",
            "shellfish", "sesame", "mustard", "celery", "lupin", "mollusc",
            "sulfite", "corn", "coconut"
        ]
        XCTAssertEqual(ids, expected, "AllergenCatalog should contain the 14 EU-regulated allergens plus corn and coconut")
    }

    func testMilkAllergenHasHiddenAliases() {
        let milk = AllergenCatalog.defaults.first { $0.id == "milk" }
        XCTAssertNotNil(milk)
        XCTAssertTrue(milk?.hiddenAliases.contains("milk powder") ?? false)
        XCTAssertTrue(milk?.aliases.contains("casein") ?? false)
    }

    // MARK: - TranslationService.detectLanguage

    func testDetectLanguagePureJapaneseReturnsJa() {
        let service = TranslationService()
        let result = service.detectLanguage(for: "私はピーナッツアレルギーです")
        XCTAssertEqual(result?.code, "ja")
    }

    func testDetectLanguageHiraganaAloneReturnsJa() {
        // Hiragana is exclusive to Japanese — should always win
        let service = TranslationService()
        let result = service.detectLanguage(for: "あいうえお")
        XCTAssertEqual(result?.code, "ja")
    }

    func testDetectLanguagePureChineseHanReturnsChinese() {
        let service = TranslationService()
        let result = service.detectLanguage(for: "配料：花生、牛奶、小麦")
        XCTAssertTrue(result?.code.hasPrefix("zh") ?? false,
                      "Pure-Han text should be classified as Chinese, got \(result?.code ?? "nil")")
    }

    func testDetectLanguageHanWithSparseKatakanaIsChineseNotJapanese() {
        // OCR can misread a single Han as a kana — should still be Chinese if kana ratio is tiny
        let service = TranslationService()
        let manyHan = String(repeating: "食品配料糖", count: 5)
        let result = service.detectLanguage(for: manyHan + "ロ")  // one stray katakana
        XCTAssertTrue(result?.code.hasPrefix("zh") ?? false,
                      "Mostly-Han text with one stray katakana should be Chinese, got \(result?.code ?? "nil")")
    }

    func testDetectLanguageKoreanReturnsKo() {
        let service = TranslationService()
        let result = service.detectLanguage(for: "성분: 우유, 땅콩, 밀")
        XCTAssertEqual(result?.code, "ko")
    }

    func testDetectLanguageThaiReturnsTh() {
        let service = TranslationService()
        let result = service.detectLanguage(for: "ส่วนประกอบ นม ถั่วลิสง")
        XCTAssertEqual(result?.code, "th")
    }

    func testDetectLanguageGermanReturnsDe() {
        let service = TranslationService()
        // German with umlauts — must not be misidentified as Vietnamese
        let result = service.detectLanguage(for: "Zutaten: Vollkornweizen, Zucker, Milchpulver, Schokolade, Salz, natürliches Aroma")
        XCTAssertEqual(result?.code, "de")
    }

    func testDetectLanguageEmptyReturnsNil() {
        let service = TranslationService()
        XCTAssertNil(service.detectLanguage(for: ""))
        XCTAssertNil(service.detectLanguage(for: "   \n  "))
    }

    // MARK: - TranslationService.findAllergenOccurrences

    func testFindAllergenOccurrencesDetectsTrackedAllergen() {
        let service = TranslationService()
        let tracked = AllergenCatalog.defaults.filter { $0.id == "peanut" }
        let chips = service.findAllergenOccurrences(
            in: "Ingredients: sugar, peanut, cocoa",
            trackedAllergens: tracked
        )
        XCTAssertEqual(chips.count, 1)
        XCTAssertEqual(chips.first?.allergenID, "peanut")
        XCTAssertFalse(chips.first?.isTrace ?? true)
    }

    func testFindAllergenOccurrencesFlagsTraceContext() {
        let service = TranslationService()
        let tracked = AllergenCatalog.defaults.filter { $0.id == "peanut" }
        let chips = service.findAllergenOccurrences(
            in: "May contain traces of peanut",
            trackedAllergens: tracked
        )
        XCTAssertEqual(chips.count, 1)
        XCTAssertTrue(chips.first?.isTrace ?? false)
    }

    func testFindAllergenOccurrencesEmptyWhenNoMatch() {
        let service = TranslationService()
        let tracked = AllergenCatalog.defaults.filter { $0.id == "peanut" }
        let chips = service.findAllergenOccurrences(
            in: "Ingredients: sugar, salt, water",
            trackedAllergens: tracked
        )
        XCTAssertTrue(chips.isEmpty)
    }

    // MARK: - AllergenTravelTranslations

    func testTravelCardTranslatesMilkToSpanishLacteos() {
        let milk = AllergenCatalog.defaults.first { $0.id == "milk" }!
        XCTAssertEqual(AllergenTravelTranslations.translate(milk, to: .spanish), "Lácteos")
    }

    func testTravelCardTranslatesPeanutAcrossLanguages() {
        let peanut = AllergenCatalog.defaults.first { $0.id == "peanut" }!
        XCTAssertEqual(AllergenTravelTranslations.translate(peanut, to: .french), "Arachides")
        XCTAssertEqual(AllergenTravelTranslations.translate(peanut, to: .japanese), "ピーナッツ")
        XCTAssertEqual(AllergenTravelTranslations.translate(peanut, to: .arabic), "فول سوداني")
    }

    func testTravelCardFallsBackToEnglishForUnknownAllergen() {
        let custom = Allergen(id: "kiwi", name: "Kiwi", aliases: ["kiwi"], hiddenAliases: [], negativeContexts: [])
        // Kiwi isn't in the translation table — should fall back to the English name.
        XCTAssertEqual(AllergenTravelTranslations.translate(custom, to: .spanish), "Kiwi")
    }

    func testTravelCardLanguageHasNonEmptyAllergyPhraseAndSafetyPhrase() {
        // Every supported language must have a non-empty phrase and safety note
        for language in TravelCardLanguage.allCases {
            XCTAssertFalse(language.allergyPhrase.isEmpty, "\(language) missing allergyPhrase")
            XCTAssertFalse(language.safetyPhrase.isEmpty, "\(language) missing safetyPhrase")
            XCTAssertFalse(language.displayName.isEmpty, "\(language) missing displayName")
            XCTAssertFalse(language.nativeName.isEmpty, "\(language) missing nativeName")
        }
    }

    func testArabicIsRTL() {
        XCTAssertTrue(TravelCardLanguage.arabic.isRTL)
        XCTAssertFalse(TravelCardLanguage.spanish.isRTL)
        XCTAssertFalse(TravelCardLanguage.japanese.isRTL)
    }

    // MARK: - EmergencyAlert

    func testEmergencyAlertBodyContainsCoordinatesWhenProvided() {
        let coord = CLLocationCoordinate2D(latitude: 37.78123, longitude: -122.41765)
        let body = EmergencyAlert.bodyText(allergenName: "Peanut", coordinate: coord)
        XCTAssertTrue(body.contains("37.78123"))
        XCTAssertTrue(body.contains("-122.41765"))
        XCTAssertTrue(body.contains("maps.apple.com"))
    }

    func testEmergencyAlertBodyHandlesMissingCoordinatesGracefully() {
        let body = EmergencyAlert.bodyText(allergenName: "Peanut", coordinate: nil)
        XCTAssertFalse(body.contains("maps.apple.com"))
        XCTAssertTrue(body.contains("Location unavailable") || body.contains("unavailable"))
    }

    func testEmergencyAlertBodyMentionsAllergen() {
        let body = EmergencyAlert.bodyText(allergenName: "Milk", coordinate: nil)
        XCTAssertTrue(body.localizedCaseInsensitiveContains("milk"))
        XCTAssertTrue(body.contains("EMERGENCY"))
    }

    func testEmergencyAlertSMSURLUsesProperSeparator() {
        let url = EmergencyAlert.smsURL(to: "+1234567890", allergenName: "Peanut", coordinate: nil)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.hasPrefix("sms:+1234567890?body="),
                      "sms URL should use ?body= separator per RFC 5724, got \(url!.absoluteString)")
    }

    func testEmergencyAlertSMSURLStripsPhoneFormatting() {
        // Phone with dashes/spaces should be cleaned
        let url = EmergencyAlert.smsURL(to: "+1 (234) 567-8900", allergenName: "Peanut", coordinate: nil)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.hasPrefix("sms:+12345678900?body="),
                      "Phone formatting should be stripped, got \(url!.absoluteString)")
    }

    // MARK: - FirstAidGuide

    func testFirstAidGuideEmergencyNumberIsValid() {
        // We can't mock Locale.current, but we can verify the value is one of the known-correct numbers
        let number = FirstAidGuide.emergencyNumber
        let valid: Set<String> = ["911", "999", "000", "111", "119", "112"]
        XCTAssertTrue(valid.contains(number), "Emergency number \(number) is not in the expected set")
    }

    func testFirstAidPlanContainsFourSymptomsAndFourActions() {
        let allergen = AllergenCatalog.defaults.first { $0.id == "peanut" }!
        let plan = FirstAidGuide.plan(for: allergen)

        XCTAssertEqual(plan.symptoms.count, 4)
        XCTAssertEqual(plan.actions.count, 4)
        XCTAssertEqual(plan.allergenID, "peanut")
        XCTAssertEqual(plan.allergenName, "Peanut")
    }

    func testFirstAidActionsMentionAllergenInStep2() {
        let allergen = AllergenCatalog.defaults.first { $0.id == "milk" }!
        let plan = FirstAidGuide.plan(for: allergen)

        let step2 = plan.actions.first { $0.stepNumber == 2 }
        XCTAssertNotNil(step2)
        XCTAssertTrue(step2?.description.localizedCaseInsensitiveContains("milk") ?? false,
                      "Step 2 should mention the allergen by name for the operator")
    }

    func testFirstAidActionStepsAreOrdered() {
        let allergen = AllergenCatalog.defaults.first { $0.id == "peanut" }!
        let plan = FirstAidGuide.plan(for: allergen)
        let stepNumbers = plan.actions.map(\.stepNumber)
        XCTAssertEqual(stepNumbers, [1, 2, 3, 4])
    }

    // MARK: - PersistenceStore

    func testPersistenceStoreSavesProfileAndScanRecord() async throws {
        let store = PersistenceStore(inMemory: true)
        try await waitUntilLoaded(store)

        let profile = UserProfile(name: "Ava", trackedAllergenIDs: ["milk", "soy"])
        try store.saveProfile(profile)
        store.setActiveProfile(id: profile.id)

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

        XCTAssertEqual(store.activeProfile?.name, "Ava")
        XCTAssertEqual(store.scanHistory.count, 1)
        XCTAssertEqual(store.scanHistory.first?.riskLevel, .highRisk)
    }

    func testPersistenceStoreSupportsMultipleProfiles() async throws {
        let store = PersistenceStore(inMemory: true)
        try await waitUntilLoaded(store)

        let parent = UserProfile(name: "Parent", trackedAllergenIDs: ["milk"])
        let child = UserProfile(name: "Child", trackedAllergenIDs: ["peanut"])
        try store.saveProfile(parent)
        try store.saveProfile(child)

        XCTAssertEqual(store.profiles.count, 2)
        store.setActiveProfile(id: child.id)
        XCTAssertEqual(store.activeProfile?.id, child.id)
    }

    func testPersistenceStoreCascadeDeletesProfileScansAndAllergens() async throws {
        let store = PersistenceStore(inMemory: true)
        try await waitUntilLoaded(store)

        let p1 = UserProfile(name: "P1", trackedAllergenIDs: ["milk"])
        let p2 = UserProfile(name: "P2", trackedAllergenIDs: ["peanut"])
        try store.saveProfile(p1)
        try store.saveProfile(p2)
        store.setActiveProfile(id: p1.id)

        let record = ScanRecord(
            rawText: "test", normalizedText: "test",
            foundIngredientsText: "test", matches: [], riskLevel: .safe
        )
        try store.saveScanRecord(record)
        XCTAssertEqual(store.scanHistory.count, 1)

        // Delete p1 — its scans should be cascaded.
        try store.deleteProfile(id: p1.id)

        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.profiles.first?.id, p2.id)

        // After switching to p2, scan history should be empty (p1's scan was cascaded).
        store.setActiveProfile(id: p2.id)
        XCTAssertTrue(store.scanHistory.isEmpty)
    }

    // MARK: - Helpers

    private func waitUntilLoaded(_ store: PersistenceStore) async throws {
        for _ in 0..<50 where !store.isLoaded {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(store.isLoaded)
    }
}
