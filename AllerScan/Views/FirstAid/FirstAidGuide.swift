import Foundation

enum FirstAidGuide {
    static func plan(for allergen: Allergen) -> FirstAidPlan {
        FirstAidPlan(
            allergenID: allergen.id,
            allergenName: allergen.name,
            symptoms: universalSymptoms,
            actions: actions(for: allergen)
        )
    }

    static var emergencyNumber: String {
        let region = Locale.current.region?.identifier ?? "US"
        switch region {
        case "US", "CA": return "911"
        case "GB": return "999"
        case "AU": return "000"
        case "NZ": return "111"
        case "JP": return "119"
        default: return "112"
        }
    }

    private static let universalSymptoms: [FirstAidPlan.Symptom] = [
        .init(title: "Swelling",   description: "Face, lips, or tongue expanding",  icon: "wave.3.right"),
        .init(title: "Hives",      description: "Red, itchy skin rashes or welts",  icon: "allergens"),
        .init(title: "Difficulty", description: "Wheezing or trouble breathing",    icon: "lungs.fill"),
        .init(title: "Dizziness",  description: "Fainting or rapid pulse drop",     icon: "heart.fill")
    ]

    private static func actions(for allergen: Allergen) -> [FirstAidPlan.Action] {
        let allergenLowercased = allergen.name.lowercased()
        return [
            .init(
                stepNumber: 1,
                title: "Use Epinephrine",
                description: "Inject your auto-injector (EpiPen) immediately into the outer thigh."
            ),
            .init(
                stepNumber: 2,
                title: "Call \(emergencyNumber) Immediately",
                description: "Tell the operator: \"Anaphylaxis\" and mention the \(allergenLowercased) exposure."
            ),
            .init(
                stepNumber: 3,
                title: "Position Correctly",
                description: "Lie down flat with legs raised. If vomiting, turn on your side."
            ),
            .init(
                stepNumber: 4,
                title: "Stay with Patient",
                description: "Monitor breathing until paramedics arrive. Record the time of injection."
            )
        ]
    }
}
