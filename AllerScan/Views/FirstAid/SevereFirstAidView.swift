import SwiftUI
import UIKit

struct SevereFirstAidView: View {
    let allergen: Allergen
    @EnvironmentObject private var store: PersistenceStore
    @State private var completedSteps: Set<Int> = []
    @State private var stepTimestamps: [Int: Date] = [:]
    @State private var showCallScript = false
    @State private var alertContactInProgress = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)
    private let notificationService = NotificationService()
    private let locationService = LocationService()

    private var plan: FirstAidPlan { FirstAidGuide.plan(for: allergen) }
    private var emergencyContact: EmergencyContact { store.securitySettings.emergencyContact }
    private var epinephrineTime: Date? { stepTimestamps[1] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                heroSection
                callEmergencyButton
                if let time = epinephrineTime {
                    epinephrineTimerCard(injectedAt: time)
                }
                symptomsSection
                actionsSection
                disclaimer
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showCallScript) {
            EmergencyCallScriptView(
                allergen: allergen,
                injectionTime: epinephrineTime
            )
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DETECTED ALLERGEN")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(allergen.name)
                    .font(.largeTitle.bold())
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text("HIGH RISK")
                    .font(.caption.bold())
                    .tracking(0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accentRed.opacity(0.15))
            .foregroundStyle(accentRed)
            .clipShape(Capsule())
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.18, blue: 0.18), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: AllergenTravelTranslations.icon(for: allergen.id))
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.25))
                    Spacer()
                }
                Spacer()
                Text("Immediate Clinical Protocol")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var callEmergencyButton: some View {
        VStack(spacing: 10) {
            Button { callEmergency() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "phone.fill")
                    Text("Call Emergency (\(FirstAidGuide.emergencyNumber))")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(accentRed)
                .clipShape(Capsule())
            }

            if emergencyContact.isConfigured {
                Button { alertEmergencyContact() } label: {
                    HStack(spacing: 8) {
                        if alertContactInProgress {
                            ProgressView().tint(accentRed)
                        } else {
                            Image(systemName: "message.fill")
                        }
                        Text("Alert \(emergencyContact.name)")
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(accentRed)
                    .background(accentRed.opacity(0.10))
                    .clipShape(Capsule())
                }
                .disabled(alertContactInProgress)
            }

            Button { showCallScript = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                    Text("What to say to the operator")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(accentRed)
            }
        }
    }

    private func alertEmergencyContact() {
        alertContactInProgress = true
        Task {
            let coordinate = await locationService.currentCoordinate()
            await MainActor.run {
                if let url = EmergencyAlert.smsURL(
                    to: emergencyContact.phoneNumber,
                    allergenName: allergen.name,
                    coordinate: coordinate
                ), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                alertContactInProgress = false
            }
        }
    }

    private func epinephrineTimerCard(injectedAt time: Date) -> some View {
        TimelineView(.periodic(from: time, by: 1)) { context in
            let elapsed = Int(context.date.timeIntervalSince(time))
            let secondDoseDue = max(0, 600 - elapsed)
            let mins = secondDoseDue / 60
            let secs = secondDoseDue % 60
            let canRedose = elapsed >= 300

            return VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "clock.fill")
                    Text("EPINEPHRINE TIMER")
                        .font(.caption.bold())
                        .tracking(0.8)
                    Spacer()
                    Text(timeString(time))
                        .font(.caption.bold())
                }
                .foregroundStyle(accentRed)

                Text(canRedose
                     ? (secondDoseDue == 0 ? "Second dose may be needed if no improvement" : String(format: "Re-dose window: %02d:%02d", mins, secs))
                     : String(format: "Wait %02d:%02d before considering second dose", (300 - elapsed) / 60, (300 - elapsed) % 60))
                    .font(.headline)

                Text("Tell paramedics the injection time. If symptoms persist after 5 minutes, a second dose is appropriate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accentRed.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Symptoms to Watch")
                .font(.title2.bold())

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(plan.symptoms) { symptom in
                    symptomCard(symptom)
                }
            }
        }
    }

    private func symptomCard(_ symptom: FirstAidPlan.Symptom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symptom.icon)
                .font(.title3)
                .foregroundStyle(accentRed)
                .frame(width: 36, height: 36)
                .background(accentRed.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(symptom.title)
                    .font(.headline)
                Text(symptom.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Immediate Actions")
                    .font(.title2.bold())
                Spacer()
                Text("Tap to mark done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(plan.actions) { action in
                    actionRow(action)
                }
            }
        }
    }

    private func actionRow(_ action: FirstAidPlan.Action) -> some View {
        let isDone = completedSteps.contains(action.stepNumber)
        let timestamp = stepTimestamps[action.stepNumber]

        return Button { toggleStep(action) } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isDone ? accentRed : Color(.separator), lineWidth: 2)
                        .frame(width: 32, height: 32)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.subheadline.bold())
                            .foregroundStyle(accentRed)
                    } else {
                        Text(String(format: "%02d", action.stepNumber))
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .strikethrough(isDone, color: .secondary)
                    Text(action.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let timestamp {
                        Text("Done at \(timeString(timestamp))")
                            .font(.caption.bold())
                            .foregroundStyle(accentRed)
                            .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(isDone ? accentRed.opacity(0.06) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text("This guide is for general reference. In any emergency, always call your local emergency services first and follow your physician's individual care plan.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func toggleStep(_ action: FirstAidPlan.Action) {
        if completedSteps.contains(action.stepNumber) {
            completedSteps.remove(action.stepNumber)
            stepTimestamps[action.stepNumber] = nil
            if action.stepNumber == 1 {
                Task { await notificationService.cancelEmergencyReminders() }
            }
        } else {
            completedSteps.insert(action.stepNumber)
            stepTimestamps[action.stepNumber] = .now
            if action.stepNumber == 1 {
                Task {
                    await notificationService.scheduleSecondDoseReminder(allergenName: allergen.name)
                    await notificationService.scheduleBiphasicWatchReminder(allergenName: allergen.name)
                }
            }
        }
    }

    private func callEmergency() {
        guard let url = URL(string: "tel://\(FirstAidGuide.emergencyNumber)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }
}
