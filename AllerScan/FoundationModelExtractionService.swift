import Foundation
import FoundationModels

@Generable
struct ExtractedSegment {
    @Guide(description: "The category: 'ingredients', 'contains', 'mayContain', or 'unknown'")
    var kind: String

    @Guide(description: "Individual ingredient phrases extracted from this segment, e.g. ['sugar', 'milk powder', 'cocoa butter']. Do NOT include nutrition facts, brand names, addresses, or contact info.")
    var phrases: [String]
}

@Generable
struct ExtractionResult {
    @Guide(description: "Ingredient segments extracted from the food label OCR text. Each segment groups ingredients by their label category.")
    var segments: [ExtractedSegment]

    @Guide(description: "True if this is a food or beverage product. False if it is a non-food product such as cosmetics, cleaning supplies, medicine, pesticides, or other chemicals not meant for eating.")
    var isFood: Bool
}

struct ExtractionOutput {
    let segments: [IngredientSegment]
    let isFood: Bool
}

struct FoundationModelExtractionService {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func extractSegments(from scan: RecognizedScan) async -> ExtractionOutput? {
        guard Self.isAvailable else { return nil }

        do {
            let session = LanguageModelSession(
                instructions: Self.systemInstructions
            )

            let userPrompt = scan.textBlocks.joined(separator: "\n")
            let response = try await session.respond(
                to: userPrompt,
                generating: ExtractionResult.self
            )

            let result = response.content
            let segments = result.segments.compactMap { extracted -> IngredientSegment? in
                let kind = SegmentKind(rawValue: extracted.kind) ?? .unknown
                let normalizedPhrases = extracted.phrases
                    .map { ScanService.normalize($0) }
                    .filter { !$0.isEmpty }

                guard !normalizedPhrases.isEmpty else { return nil }

                let rawText = extracted.phrases.joined(separator: ", ")
                return IngredientSegment(
                    rawText: rawText,
                    normalizedText: ScanService.normalize(rawText),
                    phrases: normalizedPhrases,
                    kind: kind
                )
            }

            guard !segments.isEmpty else { return nil }
            return ExtractionOutput(segments: segments, isFood: result.isFood)
        } catch {
            print("[FoundationModels] Extraction failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static let systemInstructions = """
    You extract ingredients from OCR text of product labels and determine if the product is food.

    Rules:
    - Return ONLY actual chemical or food ingredients (substances the product is made of)
    - IGNORE everything that is not an ingredient: safety warnings, hazard statements, usage instructions, marketing claims, directions for use, precautions, first aid instructions, recycling info, country of origin, manufacturer details, nutrition facts, percentages, weights, brand names, addresses, phone numbers, barcodes, storage instructions, batch numbers
    - Examples of things to IGNORE: "can kill", "flammable", "keep away from children", "do not ingest", "made in australia", "instantly", "misuse", "inhalant", "extremely"
    - Group by label: "ingredients" for main ingredient lists, "contains" for allergen declarations, "mayContain" for cross-contamination warnings, "unknown" if unclear
    - Split compound entries into individual phrases (e.g. "sugar, milk powder, cocoa" becomes three phrases)
    - Fix obvious OCR errors in ingredient names when the correction is unambiguous
    - If no ingredients are found, return empty segments
    - Set isFood to true for food and beverages, false for cosmetics, cleaning products, medicine, pesticides, aerosols, or any product not meant to be eaten
    """
}
