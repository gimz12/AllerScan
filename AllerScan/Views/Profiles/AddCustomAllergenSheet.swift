import SwiftUI

struct AddCustomAllergenSheet: View {
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
