import SwiftUI

struct SplashView: View {
    @State private var pulse = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(accentRed)
                        .frame(width: 96, height: 96)
                        .shadow(color: accentRed.opacity(0.35), radius: 20, y: 10)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .opacity(pulse ? 1 : 0.85)
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                Text("AllerScan")
                    .font(.title.bold())
                    .foregroundStyle(accentRed)
                Text("Smart Allergy Ingredient Checker")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { pulse = true }
    }
}
