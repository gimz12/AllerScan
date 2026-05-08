import SwiftUI
import UIKit

struct TravelCardFullScreenView: View {
    let language: TravelCardLanguage
    let allergens: [Allergen]
    let profileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var originalBrightness: CGFloat = UIScreen.main.brightness

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: .now)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    emergencyBanner
                    content
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            closeButton
        }
        .statusBarHidden()
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIScreen.main.brightness = originalBrightness
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var emergencyBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            Text("SEVERE FOOD ALLERGY")
                .font(.title3.weight(.heavy))
                .tracking(1)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(accentRed)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 28) {
            englishSection
            divider
            translatedSection
            divider
            safetyNote
            footer
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 28)
    }

    private var englishSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ENGLISH")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            Text("I am allergic to:")
                .font(.system(size: 32, weight: .bold))

            VStack(spacing: 12) {
                ForEach(allergens) { allergen in
                    fullScreenAllergenRow(name: allergen.name, allergenID: allergen.id)
                }
            }
        }
    }

    private var translatedSection: some View {
        VStack(alignment: language.isRTL ? .trailing : .leading, spacing: 16) {
            Text(language.displayName.uppercased())
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(accentRed)
                .tracking(1.5)

            Text(language.allergyPhrase)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(language.isRTL ? .trailing : .leading)

            VStack(spacing: 12) {
                ForEach(allergens) { allergen in
                    fullScreenAllergenRow(
                        name: AllergenTravelTranslations.translate(allergen, to: language),
                        allergenID: allergen.id
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: language.isRTL ? .trailing : .leading)
    }

    private func fullScreenAllergenRow(name: String, allergenID: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: AllergenTravelTranslations.icon(for: allergenID))
                .font(.title2)
                .foregroundStyle(accentRed)
                .frame(width: 36, height: 36)
                .background(accentRed.opacity(0.12))
                .clipShape(Circle())

            Text(name)
                .font(.system(size: 24, weight: .bold))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var safetyNote: some View {
        VStack(alignment: language.isRTL ? .trailing : .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(accentRed)
                Text("Cross-contamination warning")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            Text(language.safetyPhrase)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(language.isRTL ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: language.isRTL ? .trailing : .leading)
        }
        .padding(16)
        .background(accentRed.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(profileName)
                    .font(.headline)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("AllerScan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
        .padding(.top, 4)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.5))
                .clipShape(Circle())
        }
        .padding(.top, 12)
        .padding(.trailing, 16)
    }
}
