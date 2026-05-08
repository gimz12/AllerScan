import SwiftUI

struct FirstAidTriageView: View {
    let allergen: Allergen
    let onResult: (FirstAidSeverity) -> Void

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                Text("Tap any symptom that's currently present:")
                    .font(.headline)
                severeOptions
                mildOption
                disclaimer
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EXPOSURE TO")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(allergen.name)
                .font(.largeTitle.bold())
            Text("Symptom Check")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var severeOptions: some View {
        VStack(spacing: 10) {
            severeButton(icon: "lungs.fill", title: "Difficulty breathing",
                         description: "Wheezing, throat tightness, voice change")
            severeButton(icon: "wave.3.right", title: "Face / lips / tongue swelling",
                         description: "Visible swelling on the face")
            severeButton(icon: "heart.fill", title: "Dizziness or confusion",
                         description: "Light-headed, fainting, disoriented")
            severeButton(icon: "syringe.fill", title: "Already used EpiPen",
                         description: "Show severe protocol with timer")
        }
    }

    private func severeButton(icon: String, title: String, description: String) -> some View {
        Button { onResult(.severe) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.18))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .opacity(0.92)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(accentRed)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var mildOption: some View {
        Button { onResult(.mild) } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle.dotted")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("None of these — mild rash or itch only")
                        .font(.subheadline.bold())
                    Text("Show monitoring protocol")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(accentRed)
            Text("When in doubt, choose a severe symptom. Anaphylaxis can escalate within minutes — using epinephrine when not strictly needed is far safer than waiting too long.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(accentRed.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
