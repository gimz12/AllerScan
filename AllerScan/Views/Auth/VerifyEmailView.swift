import SwiftUI

struct VerifyEmailView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var isResending = false
    @State private var isChecking = false
    @State private var resendCooldown = 0
    @State private var errorMessage: String?
    @State private var resendBanner: String?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 24)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accentRed)
                    .frame(width: 72, height: 72)
                Image(systemName: "shield.checkered")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("Verify Email").font(.largeTitle.bold())
                Text("We sent a verification link to **\(authService.email)**. Open the email and tap the link, then return here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    Task { await checkVerified() }
                } label: {
                    ZStack {
                        if isChecking { ProgressView().tint(.white) }
                        else { Text("I've Verified My Email").font(.headline) }
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
                .disabled(isChecking)

                Button {
                    Task { await resend() }
                } label: {
                    HStack(spacing: 6) {
                        if isResending { ProgressView() }
                        Text(resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend Email")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(resendCooldown > 0 ? .secondary : accentRed)
                }
                .disabled(isResending || resendCooldown > 0)

                Button("Sign Out") {
                    try? authService.signOut()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.horizontal)

            if let resendBanner {
                Label(resendBanner, systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(accentRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(accentRed)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secure Verification").font(.subheadline.bold())
                    Text("Verifying your email keeps your allergy profile private and secure across devices.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            // Auto-poll every 4 seconds in case the user verifies in the email app and returns.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if let verified = try? await authService.refreshVerificationStatus(), verified {
                    break
                }
            }
        }
    }

    private func checkVerified() async {
        errorMessage = nil
        isChecking = true
        defer { isChecking = false }
        do {
            let verified = try await authService.refreshVerificationStatus()
            if !verified {
                errorMessage = "Email not verified yet. Tap the link in your email then try again."
            }
        } catch {
            errorMessage = AuthService.describe(error)
        }
    }

    private func resend() async {
        errorMessage = nil
        resendBanner = nil
        isResending = true
        defer { isResending = false }
        do {
            try await authService.resendVerificationEmail()
            resendBanner = "Verification email resent."
            startCooldown()
        } catch {
            errorMessage = AuthService.describe(error)
        }
    }

    private func startCooldown() {
        resendCooldown = 30
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                resendCooldown -= 1
            }
        }
    }
}
