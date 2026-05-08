import SwiftUI

struct SignUpView: View {
    var onGoToLogin: () -> Void

    @EnvironmentObject private var authService: AuthService
    @State private var fullName = ""
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
                    Text("Create Your Account")
                        .font(.largeTitle.bold())
                    Text("Join AllerScan to start scanning safely")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    AuthField(label: "Full Name", placeholder: "Enter your full name", text: $fullName,
                              keyboard: .default, contentType: .name)
                    AuthField(label: "Email Address", placeholder: "example@clinical.com", text: $email,
                              keyboard: .emailAddress, contentType: .emailAddress)
                    AuthPasswordField(label: "Password", text: $password, showPassword: $showPassword)
                    Text("Use at least 6 characters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                primaryButton

                Button("Already have an account? Log In") {
                    onGoToLogin()
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
        .navigationTitle("Create Account")
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
                    Text("Create Account")
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
        .disabled(isSubmitting || fullName.isEmpty || email.isEmpty || password.count < 6)
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await authService.signUp(name: fullName, email: email, password: password)
        } catch {
            errorMessage = AuthService.describe(error)
        }
    }
}
