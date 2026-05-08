import SwiftUI

struct MildFirstAidView: View {
    let allergen: Allergen
    let onEscalate: () -> Void

    private let amber = Color(red: 0.92, green: 0.62, blue: 0.10)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                heroCard
                actionsSection
                escalateButton
                disclaimer
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MILD REACTION")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(allergen.name)
                    .font(.largeTitle.bold())
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.caption)
                Text("MONITOR")
                    .font(.caption.bold())
                    .tracking(0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(amber.opacity(0.15))
            .foregroundStyle(amber)
            .clipShape(Capsule())
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [amber, amber.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
                Spacer()
                Text("Watch for Worsening")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("Most mild reactions resolve on their own — but they can progress. Stay near help.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(20)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Steps")
                .font(.title2.bold())
            VStack(spacing: 10) {
                stepRow(step: 1, title: "Take an antihistamine",
                        description: "Diphenhydramine (Benadryl) or cetirizine (Zyrtec) at the standard adult/child dose.")
                stepRow(step: 2, title: "Stop exposure",
                        description: "Stop eating, rinse the mouth if recently consumed, wash hands.")
                stepRow(step: 3, title: "Monitor for 30 minutes",
                        description: "Symptoms can escalate. Stay near someone who can help if it gets worse.")
                stepRow(step: 4, title: "Contact your doctor",
                        description: "Especially if hives spread, last more than 24 hours, or recur in waves.")
            }
        }
    }

    private func stepRow(step: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(format: "%02d", step))
                .font(.title2.bold())
                .foregroundStyle(amber.opacity(0.5))
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var escalateButton: some View {
        Button { onEscalate() } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Symptoms getting worse?")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Color.red)
            .clipShape(Capsule())
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text("Mild reactions can progress to anaphylaxis within minutes. If breathing changes, swelling appears, or dizziness develops, escalate immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
