import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void
    @State private var page = 0
    @State private var goToLogin = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        if goToLogin {
            AuthFlowView(initialScreen: .login)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage(
                    illustration: scanIllustration,
                    title: "Your Clinical ",
                    titleAccent: "Guardian",
                    titleSuffix: " for Food Safety",
                    body: "Scan any product barcode or ingredient list to instantly identify allergens tailored to your health profile."
                )
                .tag(0)

                welcomePage(
                    illustration: travelIllustration,
                    title: "Travel-Ready ",
                    titleAccent: "Allergy Card",
                    titleSuffix: " in 14 Languages",
                    body: "Show your allergens to staff abroad in their language. Pre-translated phrases for emergencies and dining out."
                )
                .tag(1)

                welcomePage(
                    illustration: firstAidIllustration,
                    title: "Step-by-Step ",
                    titleAccent: "First Aid",
                    titleSuffix: " Protocol",
                    body: "Know exactly what to do during an allergic reaction. Time-stamped checklist, second-dose reminder, one-tap 911."
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? accentRed : Color(.systemGray4))
                        .frame(width: index == page ? 22 : 8, height: 8)
                        .animation(.spring(duration: 0.25), value: page)
                }
            }
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        onGetStarted()
                    }
                } label: {
                    Text(page < 2 ? "Next" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(colors: [accentRed, accentRed.opacity(0.8)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Capsule())
                }

                Button {
                    onGetStarted()
                    goToLogin = true
                } label: {
                    Text("I already have an account")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func welcomePage(illustration: AnyView, title: String, titleAccent: String, titleSuffix: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            illustration
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text("\(title)\(Text(titleAccent).foregroundStyle(accentRed))\(titleSuffix)")
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(3)

                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var scanIllustration: AnyView {
        AnyView(
            ZStack {
                LinearGradient(colors: [Color(.systemGray6), Color(.tertiarySystemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 16) {
                    badgeCard(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: accentRed,
                        title: "Peanut Detected",
                        subtitle: "Unsafe for your profile"
                    )
                    .offset(x: -30)

                    badgeCard(
                        icon: "checkmark.circle.fill",
                        iconColor: .blue,
                        title: "Verified Safe",
                        subtitle: "Lactose-free certified"
                    )
                    .offset(x: 30)
                }
                .padding(20)
            }
        )
    }

    private var travelIllustration: AnyView {
        AnyView(
            ZStack {
                LinearGradient(colors: [Color(.systemGray6), Color(.tertiarySystemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 12) {
                    Text("ENGLISH").font(.caption.bold()).foregroundStyle(.secondary)
                    Text("I am allergic to:").font(.headline.bold())
                    Text("• Peanut  • Milk  • Wheat").font(.subheadline)

                    Image(systemName: "character.bubble")
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)

                    Text("FRANÇAIS").font(.caption.bold()).foregroundStyle(accentRed)
                    Text("Je suis allergique à :").font(.headline.bold())
                    Text("• Arachides  • Lait  • Blé").font(.subheadline)
                }
                .padding(20)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(24)
            }
        )
    }

    private var firstAidIllustration: AnyView {
        AnyView(
            ZStack {
                LinearGradient(colors: [Color(.systemGray6), Color(.tertiarySystemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text("SEVERE FOOD ALLERGY")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(accentRed)
                    .clipShape(Capsule())

                    stepRow(num: "01", title: "Use Epinephrine")
                    stepRow(num: "02", title: "Call 911")
                    stepRow(num: "03", title: "Position Correctly")
                }
                .padding(20)
            }
        )
    }

    private func stepRow(num: String, title: String) -> some View {
        HStack(spacing: 12) {
            Text(num).font(.subheadline.bold()).foregroundStyle(accentRed)
            Text(title).font(.subheadline.bold())
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func badgeCard(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}
