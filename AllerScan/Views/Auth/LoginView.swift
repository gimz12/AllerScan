import SwiftUI

struct LoginView: View {
    var onSignUp: () -> Void
    var onForgotPassword: () -> Void

    @EnvironmentObject private var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                logo
                VStack(spacing: 6) {
                    Text("Welcome Back")
                        .font(.largeTitle.bold())
                    Text("Continue your journey with AllerScan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    AuthField(label: "Email Address", placeholder: "example@clinical.com", text: $email,
                              keyboard: .emailAddress, contentType: .emailAddress)
                    AuthPasswordField(label: "Password", text: $password, showPassword: $showPassword)

                    HStack {
                        Spacer()
                        Button("Forgot Password?", action: onForgotPassword)
                            .font(.subheadline.bold())
                            .foregroundStyle(accentRed)
                    }
                }

                primaryButton

                Button("Don't have an account? Sign Up") {
                    onSignUp()
                }
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.top, 8)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(accentRed)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Log In")
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
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Log In")
                        .font(.headline)
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
        .disabled(isSubmitting || email.isEmpty || password.isEmpty)
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = AuthService.describe(error)
        }
    }
}
