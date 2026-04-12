import Foundation

enum RiskLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case safe
    case warning
    case highRisk
    case notFood

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safe: "Safe"
        case .warning: "Warning"
        case .highRisk: "High Risk"
        case .notFood: "Danger"
        }
    }

    var summary: String {
        switch self {
        case .safe: "No tracked allergens were detected."
        case .warning: "Potential allergen terms were found and should be reviewed carefully."
        case .highRisk: "Tracked allergens were directly detected in the ingredient list."
        case .notFood: "This does not appear to be a food product. These ingredients are not safe for consumption."
        }
    }
}

enum MatchStrength: String, Codable, Sendable {
    case exactIngredient
    case exactAlias
    case collapsedPhrase
    case weakContextual
}

enum SegmentKind: String, Codable, Sendable {
    case ingredients
    case contains
    case mayContain
    case unknown
}

enum EvidenceReason: String, Codable, Sendable {
    case exactIngredientPhrase
    case exactAlias
    case collapsedPhraseRecovery
    case contextualContainStatement
    case weakContextualHit
}

struct Allergen: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let aliases: [String]
    let hiddenAliases: [String]
    let negativeContexts: [String]
}

struct DetectedAllergen: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let allergenID: String
    let allergenName: String
    let matchedAlias: String
    let matchedText: String
    let sourceContext: SegmentKind
    let confidenceScore: Double
    let reason: EvidenceReason
    let strength: MatchStrength
}

struct IngredientSegment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let rawText: String
    let normalizedText: String
    let phrases: [String]
    let kind: SegmentKind

    init(
        id: UUID = UUID(),
        rawText: String,
        normalizedText: String,
        phrases: [String],
        kind: SegmentKind
    ) {
        self.id = id
        self.rawText = rawText
        self.normalizedText = normalizedText
        self.phrases = phrases
        self.kind = kind
    }
}

struct DetectionEvidence: Identifiable, Hashable, Sendable {
    let id: String
    let allergenID: String
    let allergenName: String
    let matchedAlias: String
    let matchedText: String
    let sourceContext: SegmentKind
    let confidenceScore: Double
    let reason: EvidenceReason
    let strength: MatchStrength
}

struct UserProfile: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var trackedAllergenIDs: [String]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, trackedAllergenIDs: [String], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.trackedAllergenIDs = trackedAllergenIDs
        self.createdAt = createdAt
    }
}

struct ScanResult: Codable, Sendable {
    let rawText: String
    let normalizedText: String
    let textBlocks: [String]
    let foundIngredientsText: String
    let matches: [DetectedAllergen]
    let riskLevel: RiskLevel
    let scannedAt: Date
}

struct ScanRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let rawText: String
    let normalizedText: String
    let foundIngredientsText: String
    let matches: [DetectedAllergen]
    let riskLevel: RiskLevel
    let createdAt: Date

    init(
        id: UUID = UUID(),
        rawText: String,
        normalizedText: String,
        foundIngredientsText: String,
        matches: [DetectedAllergen],
        riskLevel: RiskLevel,
        createdAt: Date = .now
    ) {
        self.id = id
        self.rawText = rawText
        self.normalizedText = normalizedText
        self.foundIngredientsText = foundIngredientsText
        self.matches = matches
        self.riskLevel = riskLevel
        self.createdAt = createdAt
    }

    init(result: ScanResult) {
        self.init(
            rawText: result.rawText,
            normalizedText: result.normalizedText,
            foundIngredientsText: result.foundIngredientsText,
            matches: result.matches,
            riskLevel: result.riskLevel,
            createdAt: result.scannedAt
        )
    }
}

struct SecuritySettings: Codable, Equatable, Sendable {
    var isBiometricLockEnabled: Bool
    var notificationsEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    static let `default` = SecuritySettings(
        isBiometricLockEnabled: false,
        notificationsEnabled: false,
        reminderHour: 20,
        reminderMinute: 0
    )
}

struct RecognizedScan: Sendable {
    let textBlocks: [String]
    let rawText: String
    let normalizedText: String
}
