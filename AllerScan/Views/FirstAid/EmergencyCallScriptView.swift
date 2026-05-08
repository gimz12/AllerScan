import SwiftUI

struct EmergencyCallScriptView: View {
    let allergen: Allergen
    let injectionTime: Date?
    @Environment(\.dismiss) private var dismiss

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("READ THIS TO THE OPERATOR")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(0.8)

                    scriptCard

                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.blue)
                        Text("Speak slowly. Repeat the address. Stay on the line until paramedics arrive.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("911 Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

    private var scriptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            scriptLine(label: "1", text: "I am having anaphylaxis from \(allergen.name.lowercased()) exposure.")
            Divider()
            scriptLine(label: "2", text: "I need an ambulance now.")
            Divider()
            scriptLine(label: "3", text: addressLine)
            Divider()
            scriptLine(label: "4", text: epinephrineLine)
            Divider()
            scriptLine(label: "5", text: "Please stay on the line. I may have trouble breathing.")
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func scriptLine(label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(.title2.bold())
                .foregroundStyle(accentRed)
                .frame(width: 26, alignment: .leading)
            Text(text)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var addressLine: String {
        "I am at [say your current address out loud]."
    }

    private var epinephrineLine: String {
        if let time = injectionTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "I used my EpiPen at \(formatter.string(from: time))."
        }
        return "I have not used an EpiPen yet."
    }
}
