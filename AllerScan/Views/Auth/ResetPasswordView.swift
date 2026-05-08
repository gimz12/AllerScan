import SwiftUI

struct ResetPasswordView: View {
    var onBack: () -> Void

    @EnvironmentObject private var authService: AuthService
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var didSend = false
    @State private var errorMessage: String?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                logo

                VStack(spacing: 6) {
                    Text("Reset Password")
                        .font(.largeTitle.bold())
                    Text(didSend
                         ? "Check your inbox for the reset link."
                         : "Enter your email address and we'll send you instructions to reset your password.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !didSend {
                    AuthField(label: "Email Address", placeholder: "example@clinical.com", text: $email,
                              keyboard: .emailAddress, contentType: .emailAddress)

                    primaryButton
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(accentRed)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 80)

                Button("Remember your password? Log In") { onBack() }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accentRed)
                .frame(width: 72, height: 72)
            Image(systemName: "shield.checkered")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var primaryButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if isSubmitting { ProgressView().tint(.white) }
                else {
                    Text("Send Reset Link").font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [accentRed, accentRed.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
        }
        .disabled(isSubmitting || email.isEmpty)
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await authService.sendPasswordReset(email: email)
            didSend = true
        } catch {
            errorMessage = AuthService.describe(error)
        }
    }
}
