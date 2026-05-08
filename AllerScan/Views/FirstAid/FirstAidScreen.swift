import SwiftUI

enum FirstAidSeverity {
    case mild, severe
}

struct FirstAidScreen: View {
    let allergen: Allergen
    @Environment(\.dismiss) private var dismiss
    @State private var severity: FirstAidSeverity?

    var body: some View {
        NavigationStack {
            Group {
                switch severity {
                case .none:
                    FirstAidTriageView(allergen: allergen) { severity = $0 }
                case .mild:
                    MildFirstAidView(allergen: allergen) { severity = .severe }
                case .severe:
                    SevereFirstAidView(allergen: allergen)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if severity != nil {
                        Button { severity = nil } label: {
                            Image(systemName: "chevron.backward")
                                .font(.subheadline.bold())
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
