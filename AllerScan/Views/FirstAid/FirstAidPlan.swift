import Foundation

struct FirstAidPlan {
    let allergenID: String
    let allergenName: String
    let symptoms: [Symptom]
    let actions: [Action]

    struct Symptom: Identifiable, Hashable {
        let title: String
        let description: String
        let icon: String
        var id: String { title }
    }

    struct Action: Identifiable, Hashable {
        let stepNumber: Int
        let title: String
        let description: String
        var id: Int { stepNumber }
    }
}
