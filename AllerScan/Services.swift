import AVFoundation
import CoreHaptics
import CoreLocation
import Foundation
import LocalAuthentication
import NaturalLanguage
import UIKit
import UserNotifications
@preconcurrency import Vision

struct AllergenCatalog {
    static let defaults: [Allergen] = [
        Allergen(id: "milk", name: "Milk", aliases: ["milk", "casein", "whey", "lactose", "ghee", "curds", "buttermilk"], hiddenAliases: ["skimmed milk powder", "milk solids", "milk powder"], negativeContexts: []),
        Allergen(id: "egg", name: "Egg", aliases: ["egg", "albumin", "ovalbumin", "lysozyme", "egg white"], hiddenAliases: ["egg yolk", "dried egg"], negativeContexts: []),
        Allergen(id: "peanut", name: "Peanut", aliases: ["peanut", "groundnut", "arachis oil", "peanut flour"], hiddenAliases: ["monkey nut"], negativeContexts: []),
        Allergen(id: "tree_nut", name: "Tree Nut", aliases: ["tree nut", "almond", "cashew", "walnut", "pecan", "hazelnut", "pistachio"], hiddenAliases: ["macadamia", "brazil nut", "pine nut"], negativeContexts: ["nutrition", "information"]),
        Allergen(id: "soy", name: "Soy", aliases: ["soy", "soybean", "soy lecithin", "edamame", "miso", "tempeh"], hiddenAliases: ["textured soy protein", "soy sauce", "soy protein isolate"], negativeContexts: []),
        Allergen(id: "wheat", name: "Wheat", aliases: ["wheat", "gluten", "semolina", "farina", "durum", "spelt"], hiddenAliases: ["wheat flour", "wheat starch", "wheat bran"], negativeContexts: []),
        Allergen(id: "fish", name: "Fish", aliases: ["fish", "anchovy", "cod", "salmon", "tuna", "tilapia", "mackerel", "sardine", "herring"], hiddenAliases: ["fish sauce", "fish oil", "fish gelatin"], negativeContexts: []),
        Allergen(id: "shellfish", name: "Shellfish", aliases: ["shellfish", "shrimp", "crab", "lobster", "prawn", "clam", "mussel", "oyster", "scallop"], hiddenAliases: ["crustacean", "crustacean extract"], negativeContexts: []),
        Allergen(id: "sesame", name: "Sesame", aliases: ["sesame", "tahini", "sesamol", "gingelly"], hiddenAliases: ["sesame seed", "sesame oil", "sesame paste"], negativeContexts: []),
        Allergen(id: "mustard", name: "Mustard", aliases: ["mustard", "mustard seed", "mustard flour", "mustard oil"], hiddenAliases: [], negativeContexts: []),
        Allergen(id: "celery", name: "Celery", aliases: ["celery", "celeriac", "celery salt", "celery seed", "celery powder"], hiddenAliases: ["celery extract"], negativeContexts: []),
        Allergen(id: "lupin", name: "Lupin", aliases: ["lupin", "lupine", "lupin flour", "lupin seed", "lupin bean"], hiddenAliases: [], negativeContexts: []),
        Allergen(id: "mollusc", name: "Mollusc", aliases: ["mollusc", "mollusk", "squid", "octopus", "snail", "abalone", "clam"], hiddenAliases: ["cuttlefish"], negativeContexts: []),
        Allergen(id: "sulfite", name: "Sulfite", aliases: ["sulfite", "sulphite", "sulfur dioxide", "sulphur dioxide", "sodium bisulfite", "sodium metabisulfite"], hiddenAliases: ["potassium metabisulfite", "e220", "e221", "e222", "e223", "e224", "e225", "e226", "e227", "e228"], negativeContexts: []),
        Allergen(id: "corn", name: "Corn", aliases: ["corn", "maize", "cornstarch", "corn flour", "corn syrup", "corn oil", "polenta", "hominy"], hiddenAliases: ["high fructose corn syrup", "corn gluten", "dextrose"], negativeContexts: []),
        Allergen(id: "coconut", name: "Coconut", aliases: ["coconut", "coconut milk", "coconut oil", "coconut cream", "coconut flour", "copra"], hiddenAliases: ["desiccated coconut", "coconut water"], negativeContexts: [])
    ]
}

enum ScanError: LocalizedError {
    case noTextFound
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .noTextFound: "No readable ingredient text was found."
        case .imageEncodingFailed: "The captured image could not be processed."
        }
    }
}

struct ScanService {
    func recognizeIngredients(from image: UIImage) async throws -> RecognizedScan {
        var candidates: [RecognizedScan] = []
        let preparedImage = image.preparedForOCR(maxDimension: 2200)

        for rotation in preparedImage.ocrRotations {
            let cgImage = autoreleasepool {
                preparedImage.rotated(by: rotation)?.cgImage
            }

            guard let cgImage else { continue }
            do {
                let recognized = try await recognizeText(from: cgImage)
                if !recognized.normalizedText.isEmpty {
                    candidates.append(recognized)
                }
            } catch ScanError.noTextFound {
                continue
            }
        }

        guard let best = candidates.max(by: { score($0) < score($1) }) else {
            throw ScanError.noTextFound
        }

        return best
    }

    private func recognizeText(from cgImage: CGImage) async throws -> RecognizedScan {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let blocks = Self.mergeIntoLines(observations)
                let rawText = blocks.joined(separator: "\n")
                let normalized = Self.normalize(rawText)

                guard !normalized.isEmpty else {
                    continuation.resume(throwing: ScanError.noTextFound)
                    return
                }

                continuation.resume(returning: RecognizedScan(textBlocks: blocks, rawText: rawText, normalizedText: normalized))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            request.customWords = Self.ingredientVocabulary

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func score(_ scan: RecognizedScan) -> Int {
        let normalized = scan.normalizedText
        let positiveSignals = [
            "ingredients", "ingredient", "contains", "may contain", "sugar", "milk",
            "powder", "oil", "flour", "salt", "emulsifier", "stabilizer", "flavour"
        ]
        let negativeSignals = [
            "nutrition information", "serving size", "energy", "kcal", "telephone",
            "website", "colombo", "www", "street", "ltd"
        ]

        var score = 0
        score += scan.textBlocks.count
        score += positiveSignals.reduce(0) { $0 + (normalized.contains($1) ? 12 : 0) }
        score -= negativeSignals.reduce(0) { $0 + (normalized.contains($1) ? 10 : 0) }
        score += normalized.filter { $0 == "," }.count * 2
        score -= normalized.components(separatedBy: " ").filter { $0.allSatisfy(\.isNumber) }.count * 2
        return score
    }

    func recognizeMultiLanguage(from image: UIImage) async throws -> RecognizedScan {
        var candidates: [RecognizedScan] = []
        let preparedImage = image.preparedForOCR(maxDimension: 2200)

        for rotation in preparedImage.ocrRotations {
            let cgImage = autoreleasepool {
                preparedImage.rotated(by: rotation)?.cgImage
            }
            guard let cgImage else { continue }
            do {
                let recognized = try await recognizeTextAutoLanguage(from: cgImage)
                if !recognized.normalizedText.isEmpty {
                    candidates.append(recognized)
                }
            } catch ScanError.noTextFound {
                continue
            }
        }

        guard let best = candidates.max(by: { $0.rawText.count < $1.rawText.count }) else {
            throw ScanError.noTextFound
        }

        return best
    }

    private func recognizeTextAutoLanguage(from cgImage: CGImage) async throws -> RecognizedScan {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let blocks = Self.mergeIntoLines(observations)
                let rawText = blocks.joined(separator: "\n")
                let normalized = Self.normalize(rawText)

                guard !normalized.isEmpty else {
                    continuation.resume(throwing: ScanError.noTextFound)
                    return
                }

                continuation.resume(returning: RecognizedScan(textBlocks: blocks, rawText: rawText, normalizedText: normalized))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            request.recognitionLanguages = [
                "en-US",
                "fr-FR",
                "de-DE",
                "it-IT",
                "es-ES",
                "pt-BR",
                "vi-VT",
                "ru-RU",
                "uk-UA",
                "ja-JP",
                "ko-KR",
                "zh-Hans",
                "zh-Hant",
                "yue-Hans",
                "yue-Hant",
                "th-TH",
                "ar-SA"
            ]

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Common ingredient and label vocabulary fed to Vision to improve recognition accuracy.
    private static let ingredientVocabulary = [
        "ingredients", "contains", "may contain", "sugar", "milk", "flour", "salt",
        "water", "oil", "butter", "cream", "cocoa", "vanilla", "starch", "powder",
        "emulsifier", "stabilizer", "preservative", "flavour", "flavor", "colour",
        "color", "lecithin", "gelatin", "yeast", "sodium", "calcium",
        "potassium", "citric acid", "modified", "concentrate",
        "extract", "syrup", "glucose", "fructose", "sucrose", "maltodextrin",
        "palm", "sunflower", "soybean", "coconut", "rapeseed", "olive",
        "wheat", "corn", "rice", "oat", "barley", "rye",
        "egg", "peanut", "almond", "cashew", "walnut", "hazelnut", "pistachio",
        "sesame", "mustard", "celery", "lupin",
        "shrimp", "crab", "lobster", "prawn",
        "fish", "anchovy", "cod", "salmon", "tuna",
        "casein", "whey", "lactose", "gluten",
        "nutrition", "information", "serving", "energy", "protein",
        "carbohydrate", "fat", "fibre", "fiber", "saturated", "calories"
    ]

    /// Groups text observations by vertical position and merges them into lines.
    /// Prevents word fragments caused by Vision splitting text across separate observations.
    private static func mergeIntoLines(_ observations: [VNRecognizedTextObservation]) -> [String] {
        guard !observations.isEmpty else { return [] }

        struct TextBlock {
            let text: String
            let confidence: Float
            let minX: CGFloat
            let midY: CGFloat
            let height: CGFloat
        }

        let blocks: [TextBlock] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let box = obs.boundingBox
            return TextBlock(
                text: candidate.string,
                confidence: candidate.confidence,
                minX: box.minX,
                midY: box.midY,
                height: box.height
            )
        }

        guard !blocks.isEmpty else { return [] }

        // Sort by Y descending (top-to-bottom; Vision uses bottom-left origin)
        let sorted = blocks.sorted { $0.midY > $1.midY }

        // Group into lines: blocks whose midY is within half the average height
        var lines: [[TextBlock]] = []
        var currentLine: [TextBlock] = [sorted[0]]

        for i in 1..<sorted.count {
            let block = sorted[i]
            let refMidY = currentLine.map(\.midY).reduce(0, +) / CGFloat(currentLine.count)
            let refHeight = currentLine.map(\.height).reduce(0, +) / CGFloat(currentLine.count)
            let threshold = max(refHeight * 0.5, 0.005)

            if abs(block.midY - refMidY) <= threshold {
                currentLine.append(block)
            } else {
                lines.append(currentLine)
                currentLine = [block]
            }
        }
        lines.append(currentLine)

        // Sort each line left-to-right and join with space
        return lines.map { line in
            line.sorted { $0.minX < $1.minX }
                .map(\.text)
                .joined(separator: " ")
        }
    }
}

struct AllergenDetectionService {
    /// When non-nil, the on-device LLM is consulted before falling back to the
    /// regex-based extractor. Tests pass `nil` to make behaviour deterministic.
    private let foundationModelService: FoundationModelExtractionService?

    init(useFoundationModel: Bool = true) {
        self.foundationModelService = useFoundationModel ? FoundationModelExtractionService() : nil
    }

    func analyze(scan: RecognizedScan, trackedAllergens: [Allergen]) async -> ScanResult {
        let normalizedText = scan.normalizedText
        var isFood = true

        let segments: [IngredientSegment]
        if let service = foundationModelService,
           let llmResult = await service.extractSegments(from: scan) {
            segments = llmResult.segments
            isFood = llmResult.isFood
        } else {
            segments = extractIngredientSegments(from: scan)
        }

        let foundIngredientsText = buildFoundIngredientsText(from: segments)
        let evidence = trackedAllergens.flatMap { scoreEvidence(for: $0, in: segments) }
        let matches = collapseEvidence(evidence)
        let riskLevel = isFood ? classifyRisk(from: matches) : .notFood

        return ScanResult(
            rawText: scan.rawText,
            normalizedText: normalizedText,
            textBlocks: scan.textBlocks,
            foundIngredientsText: foundIngredientsText,
            matches: matches,
            riskLevel: riskLevel,
            scannedAt: .now
        )
    }

    private func extractIngredientSegments(from scan: RecognizedScan) -> [IngredientSegment] {
        let candidateLines = scan.textBlocks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var segments: [IngredientSegment] = []

        for line in candidateLines {
            let normalized = ScanService.normalize(line)
            guard !normalized.isEmpty else { continue }

            let kind = segmentKind(for: normalized)
            guard shouldKeepSegment(normalized, kind: kind) else { continue }

            let phrases = ingredientPhrases(from: line)
            guard !phrases.isEmpty || kind != .unknown else { continue }

            segments.append(
                IngredientSegment(
                    rawText: line,
                    normalizedText: normalized,
                    phrases: phrases.map(ScanService.normalize).filter { !$0.isEmpty },
                    kind: kind
                )
            )
        }

        if segments.isEmpty {
            let phrases = ingredientPhrases(from: scan.rawText)
            if !phrases.isEmpty {
                segments.append(
                    IngredientSegment(
                        rawText: scan.rawText,
                        normalizedText: scan.normalizedText,
                        phrases: phrases.map(ScanService.normalize),
                        kind: .unknown
                    )
                )
            }
        }

        return segments
    }

    private func scoreEvidence(for allergen: Allergen, in segments: [IngredientSegment]) -> [DetectionEvidence] {
        let candidates = ([allergen.name] + allergen.aliases + allergen.hiddenAliases)
            .map { ($0, ScanService.normalize($0)) }
            .filter { !$0.1.isEmpty }

        var evidence: [DetectionEvidence] = []

        for segment in segments {
            guard !allergen.negativeContexts.contains(where: { segment.normalizedText.contains(ScanService.normalize($0)) }) else {
                continue
            }

            let collapsedSegmentText = segment.normalizedText.replacingOccurrences(of: " ", with: "")
            let segmentTokens = tokenize(segment.normalizedText)

            for phrase in segment.phrases {
                for (displayCandidate, candidate) in candidates {
                    if containsWholePhrase(candidate, in: phrase) {
                        evidence.append(
                            DetectionEvidence(
                                id: "\(allergen.id)-\(candidate)-\(segment.kind.rawValue)-exact",
                                allergenID: allergen.id,
                                allergenName: allergen.name,
                                matchedAlias: displayCandidate,
                                matchedText: phrase,
                                sourceContext: segment.kind,
                                confidenceScore: confidence(for: .exactAlias, in: segment.kind),
                                reason: segment.kind == .ingredients ? .exactIngredientPhrase : .contextualContainStatement,
                                strength: candidate == ScanService.normalize(allergen.name) ? .exactIngredient : .exactAlias
                            )
                        )
                        continue
                    }

                    if let matched = collapsedPhraseMatch(candidate: candidate, phrases: segment.phrases, collapsedText: collapsedSegmentText) {
                        evidence.append(
                            DetectionEvidence(
                                id: "\(allergen.id)-\(candidate)-\(segment.kind.rawValue)-collapsed",
                                allergenID: allergen.id,
                                allergenName: allergen.name,
                                matchedAlias: displayCandidate,
                                matchedText: matched,
                                sourceContext: segment.kind,
                                confidenceScore: confidence(for: .collapsedPhrase, in: segment.kind),
                                reason: .collapsedPhraseRecovery,
                                strength: .collapsedPhrase
                            )
                        )
                    } else if let weak = weakContextMatch(candidate: candidate, tokens: segmentTokens, kind: segment.kind) {
                        evidence.append(
                            DetectionEvidence(
                                id: "\(allergen.id)-\(candidate)-\(segment.kind.rawValue)-weak",
                                allergenID: allergen.id,
                                allergenName: allergen.name,
                                matchedAlias: displayCandidate,
                                matchedText: weak,
                                sourceContext: segment.kind,
                                confidenceScore: confidence(for: .weakContextual, in: segment.kind),
                                reason: .weakContextualHit,
                                strength: .weakContextual
                            )
                        )
                    }
                }
            }
        }

        return evidence
    }

    private func collapseEvidence(_ evidence: [DetectionEvidence]) -> [DetectedAllergen] {
        let grouped = Dictionary(grouping: evidence) { $0.allergenID }
        let reduced = grouped.compactMap { _, items -> DetectionEvidence? in
            items.max { left, right in
                if left.confidenceScore == right.confidenceScore {
                    return left.matchedAlias.count < right.matchedAlias.count
                }
                return left.confidenceScore < right.confidenceScore
            }
        }

        return reduced
            .map {
                DetectedAllergen(
                    id: $0.id,
                    allergenID: $0.allergenID,
                    allergenName: $0.allergenName,
                    matchedAlias: $0.matchedAlias,
                    matchedText: $0.matchedText,
                    sourceContext: $0.sourceContext,
                    confidenceScore: $0.confidenceScore,
                    reason: $0.reason,
                    strength: $0.strength
                )
            }
            .sorted { left, right in
                if left.confidenceScore == right.confidenceScore {
                    return left.allergenName < right.allergenName
                }
                return left.confidenceScore > right.confidenceScore
            }
    }

    private func classifyRisk(from matches: [DetectedAllergen]) -> RiskLevel {
        guard !matches.isEmpty else { return .safe }

        if matches.contains(where: {
            ($0.sourceContext == .ingredients || $0.sourceContext == .contains) &&
            $0.confidenceScore >= 0.8
        }) {
            return .highRisk
        }

        return .warning
    }

    private func buildFoundIngredientsText(from segments: [IngredientSegment]) -> String {
        let preferred = segments.filter { $0.kind == .ingredients || $0.kind == .contains || $0.kind == .mayContain }
        let source = preferred.isEmpty ? segments : preferred

        let lines = source.compactMap { segment -> String? in
            let label: String
            switch segment.kind {
            case .ingredients:
                label = "Ingredients"
            case .contains:
                label = "Contains"
            case .mayContain:
                label = "May contain"
            case .unknown:
                label = "Possible Ingredients"
            }

            let items = displayItems(for: segment)
            guard !items.isEmpty else { return nil }
            let content = items.joined(separator: ", ")
            return "\(label): \(content)"
        }

        return lines.joined(separator: "\n")
    }

    private func displayItems(for segment: IngredientSegment) -> [String] {
        let phrases = (segment.phrases.isEmpty ? splitPhrases(segment.normalizedText) : segment.phrases)
            .map { ScanService.normalize($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let filtered = phrases.filter { phrase in
            guard phrase.count >= 3 else { return false }
            // Filter contact/header/label info
            guard phrase.range(of: "^(tel|www|http|serving|energy|information|telephone|address|colombo|batch|net)\\b", options: .regularExpression) == nil else {
                return false
            }
            // Filter pure numbers
            guard phrase.range(of: "^\\d+[\\d\\s]*$", options: .regularExpression) == nil else { return false }
            // Filter units, domains, geographic
            guard phrase.range(of: "\\b(kcal|kj|cal|kg|ml|g|ltd|com|sri lanka|street)\\b", options: .regularExpression) == nil else {
                return false
            }
            // Filter nutrition-related terms
            guard phrase.range(of: "\\b(nutrition|per serving|saturated fat|total fat|carbohydrate|cholesterol|calories|daily value|serving size|protein)\\b", options: .regularExpression) == nil else {
                return false
            }
            // Filter number+unit patterns (e.g., "139 91 kal", "25g", "100ml")
            guard phrase.range(of: "\\d+\\s*(g|mg|ml|kcal|kj|kal|cal)\\b", options: .regularExpression) == nil else {
                return false
            }
            guard phrase.components(separatedBy: " ").count <= 6 else { return false }
            return true
        }

        if segment.kind == .unknown {
            return Array(filtered.prefix(10))
        }

        return filtered
    }

    private func ingredientPhrases(from text: String) -> [String] {
        let normalizedSeparators = text
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: ";", with: ", ")

        var phrases: [String] = []
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = normalizedSeparators
        sentenceTokenizer.enumerateTokens(in: normalizedSeparators.startIndex..<normalizedSeparators.endIndex) { range, _ in
            let sentence = String(normalizedSeparators[range])
            phrases.append(contentsOf: splitPhrases(sentence))
            return true
        }

        if phrases.isEmpty {
            phrases = splitPhrases(normalizedSeparators)
        }

        return phrases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func splitPhrases(_ text: String) -> [String] {
        text.split(whereSeparator: { ",;•".contains($0) }).map(String.init)
    }

    private func segmentKind(for normalized: String) -> SegmentKind {
        if normalized.contains("may contain") || normalized.contains("manufactured in a facility with") {
            return .mayContain
        }
        if normalized.contains("contains") {
            return .contains
        }
        if normalized.contains("ingredients") || normalized.contains("ingredient") {
            return .ingredients
        }
        return .unknown
    }

    private func shouldKeepSegment(_ normalized: String, kind: SegmentKind) -> Bool {
        if kind != .unknown { return true }

        let blockedKeywords = [
            "nutrition information", "nutrition facts", "serving size", "energy",
            "kcal", "kj", "telephone", "website", "www", "hotline",
            "manufactured by", "distributed by", "address", "storage",
            "country", "email", "per serving", "daily value",
            "net weight", "best before", "expiry", "batch",
            "saturated fat", "total fat", "carbohydrate", "cholesterol",
            "calories", "protein",
            // Serving suggestions and recipe directions — describe how to consume,
            // not what's in the product.
            "serve with", "best with", "pairs with", "recommended with",
            "corresponds to", "preparation", "mix with", "add water", "add milk",
            "enjoy with", "add hot water", "add boiling water"
        ]

        if blockedKeywords.contains(where: normalized.contains) { return false }

        // Lines starting with footnote markers (* or **) are not ingredient lists.
        let trimmed = normalized.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("*") { return false }

        if normalized.range(of: "\\b\\d{2,}\\b", options: .regularExpression) != nil && !normalized.contains("ingredient") {
            return false
        }
        // Filter lines that look like nutrition values (e.g., "fat 12g", "25 kcal")
        if normalized.range(of: "\\d+\\s*(g|mg|ml|kcal|kj|cal)\\b", options: .regularExpression) != nil {
            return false
        }

        return normalized.contains(",")
            || normalized.contains(" powder")
            || normalized.contains(" oil")
            || normalized.contains(" flour")
            || normalized.contains(" sugar")
            || normalized.contains(" milk")
    }

    private func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            tokens.append(String(text[range]))
            return true
        }
        return tokens
    }

    private func containsWholePhrase(_ phrase: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        // Word-boundary match with optional English plural suffix so that
        // "peanut" matches "peanuts", "egg" matches "eggs", "soybean" matches "soybeans".
        let pattern = "\\b\(escaped)s?\\b"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private func collapsedPhraseMatch(candidate: String, phrases: [String], collapsedText: String) -> String? {
        let parts = candidate.split(separator: " ").map(String.init)
        guard parts.count > 1 else { return nil }

        let collapsedCandidate = parts.joined()
        guard collapsedCandidate.count >= 6 else { return nil }

        if let matchedPhrase = phrases.first(where: { $0.replacingOccurrences(of: " ", with: "").contains(collapsedCandidate) }) {
            return matchedPhrase
        }

        if collapsedText.contains(collapsedCandidate) {
            return collapsedCandidate
        }

        return nil
    }

    private func weakContextMatch(candidate: String, tokens: [String], kind: SegmentKind) -> String? {
        guard kind == .contains || kind == .mayContain else { return nil }
        guard candidate.count >= 5 else { return nil }
        let candidateTokens = tokenize(candidate)
        guard candidateTokens.count >= 2 else { return nil }
        let present = candidateTokens.filter { token in tokens.contains(token) }
        return present.count >= 2 ? present.joined(separator: " ") : nil
    }

    private func confidence(for strength: MatchStrength, in context: SegmentKind) -> Double {
        switch (strength, context) {
        case (.exactIngredient, .ingredients): return 1.0
        case (.exactAlias, .ingredients): return 0.95
        case (.exactIngredient, .contains), (.exactAlias, .contains): return 0.9
        case (.collapsedPhrase, .ingredients): return 0.84
        case (.collapsedPhrase, .contains): return 0.8
        case (.weakContextual, .contains): return 0.72
        case (.weakContextual, .mayContain): return 0.64
        case (_, .mayContain): return 0.68
        default: return 0.58
        }
    }
}

private extension UIImage {
    var ocrRotations: [CGFloat] {
        [0, .pi / 2, -.pi / 2, .pi]
    }

    func preparedForOCR(maxDimension: CGFloat) -> UIImage {
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxDimension, longestEdge > 0 else { return self }

        let scaleRatio = maxDimension / longestEdge
        let targetSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func rotated(by radians: CGFloat) -> UIImage? {
        if radians == 0 { return self }

        let outputSize = boundsAfterRotation(by: radians)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            cgContext.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    private func boundsAfterRotation(by radians: CGFloat) -> CGSize {
        let transform = CGAffineTransform(rotationAngle: radians)
        let rect = CGRect(origin: .zero, size: size).applying(transform)
        return CGSize(width: abs(rect.width.rounded(.up)), height: abs(rect.height.rounded(.up)))
    }
}

struct BiometricAuthService {
    func canEvaluate() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Use Later"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }
}

struct NotificationService {
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func scheduleReminder(hour: Int, minute: Int, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-safety-reminder"])

        guard enabled else { return }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "AllerScan Reminder"
        content.body = "Review your allergy profile and scan ingredients before you eat."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "daily-safety-reminder",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        try? await center.add(request)
    }

    static let secondDoseIdentifier = "first-aid-second-dose"
    static let biphasicWatchIdentifier = "first-aid-biphasic-watch"

    func scheduleSecondDoseReminder(after seconds: TimeInterval = 600, allergenName: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.secondDoseIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Second Epinephrine Dose"
        content.body = "If symptoms have not improved after the first dose, administer a second EpiPen now and confirm 911 has been called."
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["allergenName": allergenName, "kind": "secondDose"]

        let request = UNNotificationRequest(
            identifier: Self.secondDoseIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        try? await center.add(request)
    }

    func scheduleBiphasicWatchReminder(after seconds: TimeInterval = 6 * 3600, allergenName: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.biphasicWatchIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Biphasic Reaction Check-In"
        content.body = "Anaphylaxis can return hours later. Stay near help and watch for any symptom return."
        content.sound = .default
        content.userInfo = ["allergenName": allergenName, "kind": "biphasic"]

        let request = UNNotificationRequest(
            identifier: Self.biphasicWatchIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        try? await center.add(request)
    }

    func cancelEmergencyReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.secondDoseIdentifier, Self.biphasicWatchIdentifier]
        )
    }
}

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var authContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentCoordinate() async -> CLLocationCoordinate2D? {
        if manager.authorizationStatus == .notDetermined {
            await waitForAuthorization()
        }

        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return nil
        }

        return await requestOneShotLocation()
    }

    private func waitForAuthorization() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                self.authContinuation = continuation
                self.manager.requestWhenInUseAuthorization()
            }
        }
    }

    private func requestOneShotLocation() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>) in
            DispatchQueue.main.async {
                self.locationContinuation = continuation
                self.manager.requestLocation()

                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard let self, let cont = self.locationContinuation else { return }
                    self.locationContinuation = nil
                    cont.resume(returning: nil)
                }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined,
              let cont = authContinuation else { return }
        authContinuation = nil
        cont.resume()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil
        cont.resume(returning: locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil
        cont.resume(returning: nil)
    }
}

enum EmergencyAlert {
    static func smsURL(to phoneNumber: String, allergenName: String, coordinate: CLLocationCoordinate2D?) -> URL? {
        let cleanedPhone = phoneNumber.filter { $0.isNumber || $0 == "+" }
        let body = bodyText(allergenName: allergenName, coordinate: coordinate)
        guard let encoded = body.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            return nil
        }
        return URL(string: "sms:\(cleanedPhone)?body=\(encoded)")
    }

    static func bodyText(allergenName: String, coordinate: CLLocationCoordinate2D?) -> String {
        var lines: [String] = []
        lines.append("EMERGENCY: I'm having a severe allergic reaction to \(allergenName.lowercased()).")
        lines.append("Please come help or send help.")
        if let coordinate {
            let lat = String(format: "%.5f", coordinate.latitude)
            let lon = String(format: "%.5f", coordinate.longitude)
            lines.append("My coordinates: \(lat), \(lon)")
            lines.append("Map: https://maps.apple.com/?ll=\(lat),\(lon)&q=Me")
        } else {
            lines.append("(Location unavailable — please call me back.)")
        }
        lines.append("Sent from AllerScan.")
        return lines.joined(separator: "\n")
    }
}

@MainActor
final class HapticsService {
    private var engine: CHHapticEngine?

    init() {
        prepareEngine()
    }

    func playCaptureFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func playResultFeedback(for riskLevel: RiskLevel) {
        let generator = UINotificationFeedbackGenerator()
        switch riskLevel {
        case .safe:
            generator.notificationOccurred(.success)
        case .warning:
            generator.notificationOccurred(.warning)
        case .highRisk, .notFood:
            generator.notificationOccurred(.error)
            playCriticalPulse()
        }
    }

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()
    }

    private func playCriticalPulse() {
        guard let engine else { return }
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.15)
        ]
        guard let pattern = try? CHHapticPattern(events: events, parameters: []) else { return }
        let player = try? engine.makePlayer(with: pattern)
        try? player?.start(atTime: 0)
    }
}

struct TranslationService {
    private static let supportedLanguages: [NLLanguage] = [
        .english, .french, .german, .italian, .spanish, .portuguese,
        .vietnamese, .russian, .ukrainian, .japanese, .korean,
        .simplifiedChinese, .traditionalChinese, .thai, .arabic
    ]

    func detectLanguage(for text: String) -> (code: String, name: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let counts = scriptCounts(in: trimmed)

        // Dominant script wins. Stray glyphs from OCR misreads can't hijack a different script.
        let buckets: [(script: Script, count: Int)] = [
            (.cjk, counts.han + counts.hiragana + counts.katakana + counts.hangul),
            (.latin, counts.latin),
            (.cyrillic, counts.cyrillic),
            (.thai, counts.thai),
            (.arabic, counts.arabic)
        ]
        guard let dominant = buckets.max(by: { $0.count < $1.count }), dominant.count > 0 else {
            return nil
        }

        switch dominant.script {
        case .cjk:    return detectCJK(counts: counts, text: trimmed)
        case .thai:   return makeResult(code: "th")
        case .arabic: return makeResult(code: "ar")
        case .latin, .cyrillic:
            return detectLatinOrCyrillic(text: trimmed)
        }
    }

    private enum Script { case cjk, latin, cyrillic, thai, arabic }

    private func detectCJK(counts: ScriptCounts, text: String) -> (code: String, name: String) {
        // Hiragana is exclusive to Japanese.
        if counts.hiragana > 0 { return makeResult(code: "ja") }

        let cjk = counts.han + counts.katakana + counts.hangul

        // Hangul-dominant CJK text → Korean.
        if cjk > 0, Double(counts.hangul) / Double(cjk) >= 0.5 {
            return makeResult(code: "ko")
        }

        // Han + meaningful katakana → Japanese; sparse katakana on Han is OCR noise.
        if counts.han > 0, counts.katakana > 0 {
            let kanaRatio = Double(counts.katakana) / Double(counts.han + counts.katakana)
            return kanaRatio >= 0.15 ? makeResult(code: "ja") : classifyChinese(text: text)
        }

        if counts.han > 0      { return classifyChinese(text: text) }
        if counts.katakana > 0 { return makeResult(code: "ja") }
        return makeResult(code: "ko")
    }

    private func detectLatinOrCyrillic(text: String) -> (code: String, name: String)? {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = Self.supportedLanguages
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        return makeResult(language: language)
    }

    private func classifyChinese(text: String) -> (code: String, name: String) {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.simplifiedChinese, .traditionalChinese]
        recognizer.processString(text)
        if recognizer.dominantLanguage == .traditionalChinese {
            return ("zh-Hant", "Chinese (Traditional)")
        }
        return ("zh-Hans", "Chinese (Simplified)")
    }

    private func makeResult(code: String) -> (code: String, name: String) {
        let displayCode = code.components(separatedBy: "-").first ?? code
        let name = Locale.current.localizedString(forLanguageCode: displayCode)?.capitalized ?? code.uppercased()
        return (code, name)
    }

    private func makeResult(language: NLLanguage) -> (code: String, name: String) {
        switch language {
        case .simplifiedChinese:  return ("zh-Hans", "Chinese (Simplified)")
        case .traditionalChinese: return ("zh-Hant", "Chinese (Traditional)")
        default:                  return makeResult(code: language.rawValue)
        }
    }

    func findAllergenOccurrences(in text: String, trackedAllergens: [Allergen]) -> [TranslationAllergenChip] {
        let lowered = text.lowercased()
        var chips: [TranslationAllergenChip] = []
        var seen: Set<String> = []

        for allergen in trackedAllergens {
            guard !seen.contains(allergen.id) else { continue }
            let terms = [allergen.name.lowercased()] + allergen.aliases.map { $0.lowercased() } + allergen.hiddenAliases.map { $0.lowercased() }

            for term in terms {
                if lowered.contains(term) {
                    let isTrace = isInTracesContext(term: term, in: lowered)
                    chips.append(TranslationAllergenChip(
                        allergenID: allergen.id,
                        displayName: allergenChipLabel(for: allergen.id, name: allergen.name),
                        isTrace: isTrace
                    ))
                    seen.insert(allergen.id)
                    break
                }
            }
        }

        return chips
    }

    private func isInTracesContext(term: String, in text: String) -> Bool {
        guard let range = text.range(of: term) else { return false }
        let lookbackStart = text.index(range.lowerBound, offsetBy: -80, limitedBy: text.startIndex) ?? text.startIndex
        let prefix = String(text[lookbackStart..<range.lowerBound])
        return prefix.contains("trace") || prefix.contains("may contain")
    }

    private func allergenChipLabel(for id: String, name: String) -> String {
        switch id {
        case "wheat": return "GLUTEN"
        case "milk": return "DAIRY"
        case "egg": return "EGGS"
        case "tree_nut": return "NUTS"
        default: return name.uppercased()
        }
    }

    private func scriptCounts(in text: String) -> ScriptCounts {
        var c = ScriptCounts()
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (0x3040...0x309F).contains(value) {
                c.hiragana += 1
            } else if (0x30A0...0x30FF).contains(value) || (0x31F0...0x31FF).contains(value) {
                c.katakana += 1
            } else if (0xAC00...0xD7AF).contains(value)
                || (0x1100...0x11FF).contains(value)
                || (0x3130...0x318F).contains(value)
                || (0xA960...0xA97F).contains(value)
                || (0xD7B0...0xD7FF).contains(value) {
                c.hangul += 1
            } else if (0x0E00...0x0E7F).contains(value) {
                c.thai += 1
            } else if (0x4E00...0x9FFF).contains(value)
                || (0x3400...0x4DBF).contains(value)
                || (0x20000...0x2A6DF).contains(value)
                || (0xF900...0xFAFF).contains(value) {
                c.han += 1
            } else if (0x0041...0x005A).contains(value)
                || (0x0061...0x007A).contains(value)
                || (0x00C0...0x024F).contains(value)
                || (0x1E00...0x1EFF).contains(value) {
                c.latin += 1
            } else if (0x0400...0x04FF).contains(value)
                || (0x0500...0x052F).contains(value) {
                c.cyrillic += 1
            } else if (0x0600...0x06FF).contains(value)
                || (0x0750...0x077F).contains(value)
                || (0xFB50...0xFDFF).contains(value)
                || (0xFE70...0xFEFF).contains(value) {
                c.arabic += 1
            }
        }
        return c
    }
}

private struct ScriptCounts {
    var han = 0
    var hiragana = 0
    var katakana = 0
    var hangul = 0
    var thai = 0
    var latin = 0
    var cyrillic = 0
    var arabic = 0
}
