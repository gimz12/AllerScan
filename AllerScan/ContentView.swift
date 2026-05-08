import SwiftUI
import Translation

struct ContentView: View {
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var authService: AuthService
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        Group {
            if authService.isInitializing {
                SplashView()
            } else if authService.currentUser == nil {
                if hasSeenWelcome {
                    AuthFlowView()
                } else {
                    WelcomeView(onGetStarted: { hasSeenWelcome = true })
                }
            } else if !authService.isEmailVerified {
                VerifyEmailView()
            } else if !store.isLoaded {
                SplashView()
            } else if store.activeProfile == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .alert("AllerScan", isPresented: Binding(
            get: { appModel.lastErrorMessage != nil },
            set: { if !$0 { appModel.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.lastErrorMessage ?? "")
        }
    }
}

// MARK: - Splash

private struct SplashView: View {
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

// MARK: - Welcome

private struct WelcomeView: View {
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
                (Text(title) + Text(titleAccent).foregroundColor(accentRed) + Text(titleSuffix))
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

// MARK: - Auth Flow

private enum AuthScreen: Hashable {
    case login, signUp, resetPassword
}

private struct AuthFlowView: View {
    var initialScreen: AuthScreen = .login
    @State private var path: [AuthScreen] = []

    var body: some View {
        NavigationStack(path: $path) {
            content(for: initialScreen)
                .navigationDestination(for: AuthScreen.self) { screen in
                    content(for: screen)
                }
        }
    }

    @ViewBuilder
    private func content(for screen: AuthScreen) -> some View {
        switch screen {
        case .login:
            LoginView(
                onSignUp: { path.append(.signUp) },
                onForgotPassword: { path.append(.resetPassword) }
            )
        case .signUp:
            SignUpView(onGoToLogin: { path = [] })
        case .resetPassword:
            ResetPasswordView(onBack: { path.removeLast() })
        }
    }
}

// MARK: - Login

private struct LoginView: View {
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

// MARK: - Sign Up

private struct SignUpView: View {
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

// MARK: - Reset Password

private struct ResetPasswordView: View {
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

// MARK: - Verify Email

private struct VerifyEmailView: View {
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
                Text("We sent a verification link to ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                +
                Text(authService.email)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                +
                Text(". Open the email and tap the link, then return here.")
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

// MARK: - Auth Field Helpers

private struct AuthField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.bold())
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct AuthPasswordField: View {
    let label: String
    @Binding var text: String
    @Binding var showPassword: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.bold())
            HStack {
                Group {
                    if showPassword {
                        TextField("••••••••", text: $text)
                    } else {
                        SecureField("••••••••", text: $text)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @State private var showAddCustom = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)
    private let grid = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AllerScan")
                            .font(.largeTitle.bold())
                        Text("Build a safety profile, scan ingredient labels, and flag risky allergens directly on-device.")
                            .foregroundStyle(.secondary)
                    }

                    PermissionRow(
                        title: "Camera access",
                        subtitle: appModel.cameraPermissionGranted ? "Ready for ingredient scanning." : "Needed for label capture and OCR.",
                        actionTitle: appModel.cameraPermissionGranted ? "Granted" : "Allow"
                    ) {
                        Task {
                            await appModel.requestCameraPermission()
                        }
                    }
                    .disabled(appModel.cameraPermissionGranted)

                    PermissionRow(
                        title: "Notifications",
                        subtitle: appModel.notificationPermissionGranted ? "Daily reminder can be scheduled." : "Optional reminders and safety nudges.",
                        actionTitle: appModel.notificationPermissionGranted ? "Granted" : "Allow"
                    ) {
                        Task {
                            await appModel.requestNotificationPermission()
                        }
                    }
                    .disabled(appModel.notificationPermissionGranted)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profile setup")
                            .font(.title3.bold())

                        TextField("Profile name", text: $appModel.profileName)
                            .textFieldStyle(.roundedBorder)

                        Text("Common Allergens")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        LazyVGrid(columns: grid, spacing: 12) {
                            ForEach(AllergenCatalog.defaults) { allergen in
                                allergenToggleButton(allergen)
                            }
                        }

                        if !store.customAllergens.isEmpty {
                            Text("Custom Allergens")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)

                            LazyVGrid(columns: grid, spacing: 12) {
                                ForEach(store.customAllergens) { allergen in
                                    allergenToggleButton(allergen, isCustom: true)
                                }
                            }
                        }

                        Button { showAddCustom = true } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Custom Allergen")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(accentRed.opacity(0.08))
                            .foregroundStyle(accentRed)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save Profile") {
                        appModel.saveProfile()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(20)
            }
            .navigationTitle("Welcome")
            .sheet(isPresented: $showAddCustom) {
                AddCustomAllergenSheet()
            }
        }
    }

    private func allergenToggleButton(_ allergen: Allergen, isCustom: Bool = false) -> some View {
        Button {
            if appModel.selectedAllergenIDs.contains(allergen.id) {
                appModel.selectedAllergenIDs.remove(allergen.id)
            } else {
                appModel.selectedAllergenIDs.insert(allergen.id)
            }
        } label: {
            HStack {
                Image(systemName: appModel.selectedAllergenIDs.contains(allergen.id) ? "checkmark.circle.fill" : "circle")
                Text(allergen.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if isCustom {
                    Button {
                        appModel.deleteCustomAllergen(id: allergen.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(appModel.selectedAllergenIDs.contains(allergen.id) ? accentRed.opacity(0.12) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AddCustomAllergenSheet: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var aliasesText = ""

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Allergen name", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("E.g. Oat, Kiwi, Cinnamon")
                }

                Section {
                    TextField("milk, dairy, cream", text: $aliasesText)
                } header: {
                    Text("Aliases (comma separated)")
                } footer: {
                    Text("Add words that might appear on ingredient labels. The scanner will look for these terms. If left empty, the allergen name itself is used.")
                }

                Section {
                    if !previewAliases.isEmpty {
                        ChipFlowLayout(spacing: 6) {
                            ForEach(previewAliases, id: \.self) { alias in
                                Text(alias)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(accentRed.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    } else {
                        Text("Enter aliases above to preview")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Add Custom Allergen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        appModel.addCustomAllergen(name: name, aliasesText: aliasesText)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var previewAliases: [String] {
        let text = aliasesText.isEmpty ? name : aliasesText
        return text
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @SceneStorage("AllerScan.selectedTab") private var selectedTab = 0
    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardScreen()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            HistoryScreen()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
                .tag(1)

            SettingsGate()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(accentRed)
        .sheet(isPresented: $appModel.isEditingProfile) {
            NavigationStack {
                OnboardingView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                appModel.isEditingProfile = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Dashboard

private struct DashboardScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var emergencyDeepLink: EmergencyDeepLink
    @State private var showScanner = false
    @State private var showTranslation = false
    @State private var showTravelCard = false
    @State private var showFirstAid = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    private var scansThisWeek: [ScanRecord] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return store.scanHistory.filter { $0.createdAt >= weekAgo }
    }

    private var alertsThisWeek: Int {
        scansThisWeek.filter { $0.riskLevel == .highRisk || $0.riskLevel == .warning || $0.riskLevel == .notFood }.count
    }

    private var recentScans: [ScanRecord] {
        Array(store.scanHistory.prefix(3))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                quickScanCard
                safetyToolkitSection
                safetyInsightsSection
                if !store.scanHistory.isEmpty {
                    recentActivitySection
                }
                riskProfileSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showScanner) {
            ScannerScreen()
        }
        .fullScreenCover(isPresented: $showTranslation) {
            TranslationScreen()
        }
        .fullScreenCover(isPresented: $showTravelCard) {
            TravelCardScreen()
        }
        .fullScreenCover(isPresented: $showFirstAid) {
            FirstAidListScreen()
        }
        .onChange(of: emergencyDeepLink.shouldOpenFirstAid) { _, shouldOpen in
            if shouldOpen {
                showFirstAid = true
                emergencyDeepLink.shouldOpenFirstAid = false
            }
        }
        .task {
            if emergencyDeepLink.shouldOpenFirstAid {
                showFirstAid = true
                emergencyDeepLink.shouldOpenFirstAid = false
            }
        }
        .sheet(item: $appModel.selectedRecord) { record in
            ResultDetailView(record: record)
        }
    }

    // MARK: Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(accentRed)
                    Text("AllerScan")
                        .font(.title2.bold())
                        .foregroundStyle(accentRed)
                }
                Menu {
                    ForEach(store.profiles) { profile in
                        Button {
                            appModel.switchActiveProfile(to: profile.id)
                        } label: {
                            HStack {
                                Text(profile.name)
                                if profile.id == store.activeProfile?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if store.profiles.count > 0 {
                        Divider()
                    }
                    Button {
                        appModel.startCreatingNewProfile()
                    } label: {
                        Label("Add profile", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Hello, \(store.activeProfile?.name ?? "there")")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        if store.profiles.count > 1 {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Ready to stay safe today?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: Quick Scan

    private var quickScanCard: some View {
        Button { showScanner = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUICK SCAN")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.25))
                        .clipShape(Capsule())
                    Text("Scan Label Now")
                        .font(.title.bold())
                    Text("Just point your camera at labels")
                        .font(.subheadline)
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(
                LinearGradient(colors: [accentRed, accentRed.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Safety Toolkit

    private var safetyToolkitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Safety Toolkit")
                    .font(.headline)
                Spacer()
                Text("3 TOOLS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Button { showFirstAid = true } label: {
                toolkitRow(icon: "cross.case.fill", color: .red, title: "First Aid Guide", subtitle: "Emergency protocol for reactions")
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button { showTravelCard = true } label: {
                    toolkitCard(icon: "globe", color: .blue, title: "Travel Allergy Card", subtitle: "Digital cards for international travel")
                }
                .buttonStyle(.plain)
                Button { showTranslation = true } label: {
                    toolkitCard(icon: "character.book.closed.fill", color: .purple, title: "Translation Mode", subtitle: "Translate labels in 17 languages")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toolkitRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func toolkitCard(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(title).font(.caption.bold())
            Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Safety Insights

    private var safetyInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SAFETY INSIGHTS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Protection Active")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.green.opacity(0.12))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Household Scan Summary")
                    .font(.subheadline.bold())
                Text("\(scansThisWeek.count) items scanned this week, \(alertsThisWeek) alert\(alertsThisWeek == 1 ? "" : "s") flagged")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    statBox(value: String(format: "%02d", scansThisWeek.count), label: "SCANS")
                    statBox(value: String(format: "%02d", alertsThisWeek), label: "ALERTS")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pro Tip").font(.caption.bold())
                    Text("Scan labels before buying to avoid accidental allergen exposure.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title.bold())
            Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Text("VIEW ALL")
                    .font(.caption.bold())
                    .foregroundStyle(accentRed)
            }

            ForEach(recentScans) { record in
                Button { appModel.selectedRecord = record } label: {
                    recentActivityRow(record: record)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recentActivityRow(record: ScanRecord) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(riskColor(for: record.riskLevel).opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: riskIcon(for: record.riskLevel))
                        .foregroundStyle(riskColor(for: record.riskLevel))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(scanDisplayName(for: record))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(riskDescription(for: record))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(record.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(record.riskLevel.title.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(riskColor(for: record.riskLevel))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(riskColor(for: record.riskLevel).opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Risk Profile

    private var riskProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Risk Profile")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(appModel.trackedAllergens.prefix(5)) { allergen in
                        Circle()
                            .fill(allergenColor(for: allergen.id))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text(String(allergen.name.prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                    }
                    if appModel.trackedAllergens.count > 5 {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text("+\(appModel.trackedAllergens.count - 5)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            }
                    }
                }

                Text("Monitoring \(appModel.trackedAllergens.count) allergen\(appModel.trackedAllergens.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                            .font(.caption2)
                        Text("SAFETY COVERAGE")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(accentRed)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text("HIGH PRECISION")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.green)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Helpers

    private func riskColor(for risk: RiskLevel) -> Color {
        switch risk {
        case .safe: .green
        case .warning: .yellow
        case .highRisk, .notFood: .red
        }
    }

    private func riskIcon(for risk: RiskLevel) -> String {
        switch risk {
        case .safe: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .highRisk: "xmark.octagon.fill"
        case .notFood: "exclamationmark.octagon.fill"
        }
    }

    private func allergenColor(for id: String) -> Color {
        switch id {
        case "milk": .blue
        case "egg": .yellow
        case "peanut": .orange
        case "tree_nut": .brown
        case "soy": .green
        case "wheat": .orange
        case "fish": .cyan
        case "shellfish": .pink
        case "sesame": .mint
        case "mustard": .yellow
        case "celery": .green
        case "lupin": .purple
        case "mollusc": .indigo
        case "sulfite": .red
        case "corn": .yellow
        case "coconut": .brown
        default: .gray
        }
    }

    private func scanDisplayName(for record: ScanRecord) -> String {
        let text = record.foundIngredientsText.isEmpty ? record.rawText : record.foundIngredientsText
        let cleaned = text
            .replacingOccurrences(of: "Ingredients:", with: "")
            .replacingOccurrences(of: "Contains:", with: "")
            .replacingOccurrences(of: "May contain:", with: "")
            .replacingOccurrences(of: "Possible Ingredients:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstItem = cleaned.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Ingredient Scan"
        return String(firstItem.prefix(30))
    }

    private func riskDescription(for record: ScanRecord) -> String {
        if record.riskLevel == .notFood {
            return "Non-food product detected"
        }
        if let match = record.matches.first {
            return "\(match.allergenName) detected"
        }
        return "No allergens detected"
    }
}

// MARK: - Scanner

private struct ScannerScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @StateObject private var cameraModel = CameraCaptureModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black)
                    .overlay {
                        if appModel.cameraPermissionGranted && cameraModel.isConfigured {
                            CameraPreview(session: cameraModel.session)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.metering.unknown")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white)
                                Text(cameraModel.statusMessage)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .frame(height: 360)
                    .overlay(alignment: .topLeading) {
                        Text("Tracking: \(store.activeProfile?.name ?? "Profile")")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding()
                    }

                if appModel.isProcessingScan {
                    ProgressView("Analyzing ingredients...")
                } else {
                    Text(cameraModel.statusMessage)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        do {
                            let image = try await cameraModel.capturePhoto()
                            await appModel.processCapturedImage(image)
                        } catch {
                            appModel.lastErrorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Scan Ingredient Label", systemImage: "viewfinder.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!appModel.cameraPermissionGranted || appModel.isProcessingScan || !cameraModel.isConfigured)

                List(appModel.trackedAllergens) { allergen in
                    Label(allergen.name, systemImage: "checkmark.shield")
                }
                .frame(maxHeight: 220)
                .scrollContentBackground(.hidden)
            }
            .padding()
            .navigationTitle("Scanner")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await cameraModel.configureIfNeeded()
            }
            .sheet(item: $appModel.selectedRecord) { record in
                ResultDetailView(record: record)
            }
        }
    }
}

private struct ResultDetailView: View {
    let record: ScanRecord
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showIngredients = false
    @State private var firstAidAllergen: Allergen?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    private var firstAidTarget: Allergen? {
        guard let firstMatch = record.matches.first else { return nil }
        return appModel.availableAllergens.first { $0.id == firstMatch.allergenID }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    riskHeader
                    ingredientsCard

                    if !record.matches.isEmpty {
                        detectedAllergensCard
                        whyRiskyCard
                    }

                    if record.riskLevel != .safe {
                        medicalGuidanceCard
                    }

                    if record.riskLevel == .highRisk || record.riskLevel == .notFood {
                        Button {
                            firstAidAllergen = firstAidTarget
                        } label: {
                            Label("View First Aid", systemImage: "cross.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentRed)
                        .disabled(firstAidTarget == nil)
                    }

                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $firstAidAllergen) { allergen in
                FirstAidScreen(allergen: allergen)
            }
        }
    }

    // MARK: - Risk Header

    private var riskHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(riskColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: riskIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(riskColor)
            }

            Text(record.riskLevel.title)
                .font(.title.bold())
                .foregroundStyle(riskColor)

            Text(riskSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Ingredients Card

    private var ingredientsCard: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.25)) { showIngredients.toggle() } } label: {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(riskColor.opacity(0.08))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .font(.title2)
                                .foregroundStyle(riskColor)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.headline)
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            Text(ingredientsSummary)
                                .font(.caption)
                            Image(systemName: showIngredients ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("SCANNED \(timeLabel)")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(16)

            if showIngredients {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ingredientList, id: \.self) { ingredient in
                        HStack(spacing: 10) {
                            let isAllergen = isMatchedAllergen(ingredient)
                            Circle()
                                .fill(isAllergen ? accentRed : .green)
                                .frame(width: 6, height: 6)
                            Text(ingredient.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(isAllergen ? accentRed : .primary)
                            if isAllergen {
                                Spacer()
                                Text("ALLERGEN")
                                    .font(.caption2.bold())
                                    .foregroundStyle(accentRed)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(accentRed.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Detected Allergens

    private var detectedAllergensCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(accentRed)
                Text("Detected Allergens")
                    .font(.subheadline.bold())
            }

            ChipFlowLayout(spacing: 8) {
                ForEach(record.matches) { match in
                    Text(match.matchedAlias)
                        .font(.subheadline.bold())
                        .foregroundStyle(accentRed)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(accentRed.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentRed.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Why Risky

    private var whyRiskyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Why this is risky")
                    .font(.subheadline.bold())
            }

            whyRiskyText
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var whyRiskyText: Text {
        guard let first = record.matches.first else {
            return Text("Potential allergens were detected.")
        }

        let remaining = record.matches.dropFirst()
        var result = Text("This product contains ")
            + Text(first.matchedAlias).bold()
            + Text(", which is a known ")
            + Text(first.allergenName).bold()
            + Text(" allergen in your safety profile.")

        if !remaining.isEmpty {
            let others = remaining.map(\.matchedAlias).joined(separator: ", ")
            result = result + Text(" Also detected: ") + Text(others).bold() + Text(".")
        }

        return result
    }

    // MARK: - Medical Guidance

    private var medicalGuidanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(accentRed)
                Text("Medical Guidance")
                    .font(.subheadline.bold())
                Spacer()
                Text("VERIFIED")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
            }

            ForEach(guidanceItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(accentRed)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentRed.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Label("Scan Again", systemImage: "camera.viewfinder")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Computed Properties

    private var riskColor: Color {
        switch record.riskLevel {
        case .safe: .green
        case .warning: .yellow
        case .highRisk, .notFood: .red
        }
    }

    private var riskIcon: String {
        switch record.riskLevel {
        case .safe: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .highRisk: "exclamationmark.triangle.fill"
        case .notFood: "exclamationmark.octagon.fill"
        }
    }

    private var riskSubtitle: String {
        switch record.riskLevel {
        case .safe: "No tracked allergens were detected."
        case .warning: "Potential allergen terms found in this product."
        case .highRisk: "Unsafe ingredients detected for your profile."
        case .notFood: "This does not appear to be a food product.\nThese ingredients are not safe for consumption."
        }
    }

    private var displayName: String {
        let text = record.foundIngredientsText.isEmpty ? record.rawText : record.foundIngredientsText
        let cleaned = text
            .replacingOccurrences(of: "Ingredients:", with: "")
            .replacingOccurrences(of: "Contains:", with: "")
            .replacingOccurrences(of: "May contain:", with: "")
            .replacingOccurrences(of: "Possible Ingredients:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let items = cleaned.components(separatedBy: ",").prefix(3)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
        let name = items.joined(separator: ", ")
        return name.isEmpty ? "Scanned Product" : String(name.prefix(50))
    }

    private var ingredientsSummary: String {
        return "\(ingredientList.count) ingredient\(ingredientList.count == 1 ? "" : "s") detected"
    }

    private var ingredientList: [String] {
        let text = record.foundIngredientsText.isEmpty ? record.rawText : record.foundIngredientsText
        let cleaned = text
            .replacingOccurrences(of: "Ingredients:", with: "")
            .replacingOccurrences(of: "Contains:", with: "")
            .replacingOccurrences(of: "May contain:", with: "")
            .replacingOccurrences(of: "Possible Ingredients:", with: "")
        return cleaned
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func isMatchedAllergen(_ ingredient: String) -> Bool {
        record.matches.contains { match in
            let alias = match.matchedAlias.lowercased()
            let text = match.matchedText.lowercased()
            return ingredient.contains(alias) || ingredient.contains(text) || alias.contains(ingredient)
        }
    }

    private var timeLabel: String {
        if Calendar.current.isDateInToday(record.createdAt) {
            return "TODAY"
        }
        if Calendar.current.isDateInYesterday(record.createdAt) {
            return "YESTERDAY"
        }
        return record.createdAt.formatted(date: .abbreviated, time: .omitted).uppercased()
    }

    private var guidanceItems: [String] {
        switch record.riskLevel {
        case .highRisk:
            return [
                "Do not consume this product. Even trace amounts may cause a reaction.",
                "Cross-contamination risk is high if the product shares equipment with known allergens."
            ]
        case .warning:
            return [
                "Review the ingredient list carefully before consuming.",
                "When in doubt, avoid the product and consult your healthcare provider."
            ]
        case .notFood:
            return [
                "This is not a food product and must not be consumed.",
                "If accidentally ingested, contact poison control or emergency services immediately."
            ]
        case .safe:
            return []
        }
    }
}

// MARK: - Translation

private struct TranslationScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var cameraModel = CameraCaptureModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showResult = false
    @State private var capturedImage: UIImage?
    @State private var originalText: String?
    @State private var detectedLanguage: String?
    @State private var languageCode: String?
    @State private var isProcessing = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            Group {
                if showResult, let image = capturedImage, let text = originalText {
                    TranslationResultView(
                        sourceImage: image,
                        originalText: text,
                        detectedLanguage: detectedLanguage ?? "Unknown",
                        languageCode: languageCode,
                        trackedAllergens: appModel.trackedAllergens,
                        onScanAgain: {
                            showResult = false
                            capturedImage = nil
                            originalText = nil
                            detectedLanguage = nil
                            languageCode = nil
                        },
                        onAnalyze: { translatedText in
                            Task {
                                await appModel.analyzeTranslatedText(translatedText)
                            }
                        }
                    )
                } else {
                    cameraScanView
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(item: $appModel.selectedRecord) { record in
            ResultDetailView(record: record)
        }
    }

    private var cameraScanView: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)
                .overlay {
                    if appModel.cameraPermissionGranted && cameraModel.isConfigured {
                        CameraPreview(session: cameraModel.session)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.metering.unknown")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                            Text(cameraModel.statusMessage)
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(height: 360)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "character.book.closed.fill")
                            .font(.caption)
                        Text("Translation Mode")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding()
                }

            if isProcessing {
                ProgressView("Recognizing text...")
            } else {
                Text("Point camera at a foreign language ingredient label")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    do {
                        let image = try await cameraModel.capturePhoto()
                        await processCapture(image)
                    } catch {
                        appModel.lastErrorMessage = error.localizedDescription
                    }
                }
            } label: {
                Label("Capture Label", systemImage: "camera.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(accentRed)
            .disabled(!appModel.cameraPermissionGranted || isProcessing || !cameraModel.isConfigured)

            Spacer()
        }
        .padding()
        .navigationTitle("Translation Mode")
        .task {
            await cameraModel.configureIfNeeded()
        }
    }

    private func processCapture(_ image: UIImage) async {
        isProcessing = true
        capturedImage = image

        do {
            let scanService = ScanService()
            let scan = try await scanService.recognizeMultiLanguage(from: image)
            originalText = scan.rawText

            let translationService = TranslationService()
            if let detected = translationService.detectLanguage(for: scan.rawText) {
                detectedLanguage = detected.name
                languageCode = detected.code
            } else {
                detectedLanguage = "Unknown"
                languageCode = nil
            }

            showResult = true
        } catch {
            appModel.lastErrorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}

private struct TranslationResultView: View {
    let sourceImage: UIImage
    let originalText: String
    let detectedLanguage: String
    let languageCode: String?
    let trackedAllergens: [Allergen]
    let onScanAgain: () -> Void
    let onAnalyze: (String) -> Void

    @State private var translatedText: String?
    @State private var isTranslating = true
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var allergenChips: [TranslationAllergenChip] = []

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                sourceImageSection
                detectedLanguageLabel
                originalTextCard
                translatedSection

                if !allergenChips.isEmpty {
                    allergenChipsSection
                }

                actionButtons
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Translation Result")
        .navigationBarTitleDisplayMode(.inline)
        .translationTask(translationConfig) { session in
            do {
                let response = try await session.translate(originalText)
                let service = TranslationService()
                let chips = service.findAllergenOccurrences(
                    in: response.targetText,
                    trackedAllergens: trackedAllergens
                )
                await MainActor.run {
                    translatedText = response.targetText
                    allergenChips = chips
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    isTranslating = false
                }
            }
        }
        .task {
            guard let code = languageCode, code != "en" else {
                translatedText = originalText
                isTranslating = false
                let service = TranslationService()
                allergenChips = service.findAllergenOccurrences(
                    in: originalText,
                    trackedAllergens: trackedAllergens
                )
                return
            }
            translationConfig = .init(
                source: Locale.Language(identifier: code),
                target: Locale.Language(identifier: "en")
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SCAN ANALYSIS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("Translation Result")
                    .font(.title2.bold())
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Live Detection")
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accentRed.opacity(0.08))
            .foregroundStyle(accentRed)
            .clipShape(Capsule())
        }
    }

    // MARK: - Source Image

    private var sourceImageSection: some View {
        Image(uiImage: sourceImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 160)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.caption2)
                    Text("Source Image")
                        .font(.caption2.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(10)
            }
    }

    // MARK: - Detected Language

    private var detectedLanguageLabel: some View {
        Text("DETECTED: \(detectedLanguage.uppercased())")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
    }

    // MARK: - Original Text Card

    private var originalTextCard: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentRed.opacity(0.6))
                .frame(width: 4)

            Text(originalText)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(accentRed.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Translated Section

    private var translatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("TRANSLATED: ENGLISH")
                    .font(.caption.bold())
                    .foregroundStyle(accentRed)
                Spacer()
                Circle().fill(accentRed).frame(width: 6, height: 6)
                Circle().fill(accentRed).frame(width: 6, height: 6)
            }

            if isTranslating {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Translating...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let translated = translatedText {
                highlightedText(translated)
                    .font(.body)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Allergen Chips

    private var allergenChipsSection: some View {
        ChipFlowLayout(spacing: 8) {
            ForEach(allergenChips) { chip in
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(chip.label)
                        .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(accentRed.opacity(0.08))
                .foregroundStyle(accentRed)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                if let text = translatedText {
                    onAnalyze(text)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Analyze Ingredients")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentRed)
            .disabled(translatedText == nil)

            Button {
                onScanAgain()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                    Text("Scan Again")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Highlighted Text

    private func highlightedText(_ text: String) -> Text {
        struct MatchInfo: Comparable {
            let range: Range<String.Index>
            let text: String
            static func < (lhs: MatchInfo, rhs: MatchInfo) -> Bool {
                lhs.range.lowerBound < rhs.range.lowerBound
            }
        }

        var matches: [MatchInfo] = []

        for allergen in trackedAllergens {
            let terms = [allergen.name] + allergen.aliases + allergen.hiddenAliases
            let sortedTerms = terms.sorted { $0.count > $1.count }

            for term in sortedTerms {
                var searchStart = text.startIndex
                while searchStart < text.endIndex {
                    guard let foundRange = text.range(of: term, options: .caseInsensitive, range: searchStart..<text.endIndex) else { break }
                    let overlaps = matches.contains { $0.range.overlaps(foundRange) }
                    if !overlaps {
                        matches.append(MatchInfo(range: foundRange, text: String(text[foundRange])))
                    }
                    searchStart = foundRange.upperBound
                }
            }
        }

        matches.sort()

        if matches.isEmpty { return Text(text) }

        var result = Text("")
        var currentIndex = text.startIndex

        for match in matches {
            if currentIndex < match.range.lowerBound {
                result = result + Text(text[currentIndex..<match.range.lowerBound])
            }
            result = result + Text(match.text).bold().foregroundColor(accentRed)
            currentIndex = match.range.upperBound
        }

        if currentIndex < text.endIndex {
            result = result + Text(text[currentIndex..<text.endIndex])
        }

        return result
    }
}

// MARK: - Travel Card

private enum TravelCardLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case vietnamese = "vi"
    case russian = "ru"
    case ukrainian = "uk"
    case japanese = "ja"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case thai = "th"
    case arabic = "ar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .vietnamese: "Vietnamese"
        case .russian: "Russian"
        case .ukrainian: "Ukrainian"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .chineseSimplified: "Chinese (Simplified)"
        case .chineseTraditional: "Chinese (Traditional)"
        case .thai: "Thai"
        case .arabic: "Arabic"
        }
    }

    var nativeName: String {
        switch self {
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .portuguese: "Português"
        case .vietnamese: "Tiếng Việt"
        case .russian: "Русский"
        case .ukrainian: "Українська"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .chineseSimplified: "简体中文"
        case .chineseTraditional: "繁體中文"
        case .thai: "ไทย"
        case .arabic: "العربية"
        }
    }

    var allergyPhrase: String {
        switch self {
        case .spanish: "Soy alérgico/a a:"
        case .french: "Je suis allergique à :"
        case .german: "Ich bin allergisch gegen:"
        case .italian: "Sono allergico/a a:"
        case .portuguese: "Sou alérgico/a a:"
        case .vietnamese: "Tôi bị dị ứng với:"
        case .russian: "У меня аллергия на:"
        case .ukrainian: "У мене алергія на:"
        case .japanese: "私は次のものにアレルギーがあります："
        case .korean: "저는 다음에 알레르기가 있습니다:"
        case .chineseSimplified: "我对以下食物过敏："
        case .chineseTraditional: "我對以下食物過敏："
        case .thai: "ฉันแพ้:"
        case .arabic: "أنا أعاني من حساسية تجاه:"
        }
    }

    var safetyPhrase: String {
        switch self {
        case .spanish: "Incluso pequeñas cantidades pueden causar una reacción grave. Por favor, evite cualquier traza o contaminación cruzada. Gracias."
        case .french: "Même de petites quantités peuvent provoquer une réaction grave. Veuillez éviter toute trace ou contamination croisée. Merci."
        case .german: "Schon kleine Mengen können eine schwere Reaktion auslösen. Bitte vermeiden Sie jegliche Spuren oder Kreuzkontamination. Danke."
        case .italian: "Anche piccole quantità possono causare una reazione grave. Si prega di evitare qualsiasi traccia o contaminazione incrociata. Grazie."
        case .portuguese: "Mesmo pequenas quantidades podem causar uma reação grave. Por favor, evite qualquer vestígio ou contaminação cruzada. Obrigado."
        case .vietnamese: "Ngay cả một lượng nhỏ cũng có thể gây phản ứng nghiêm trọng. Vui lòng tránh bất kỳ dấu vết hoặc lây nhiễm chéo nào. Cảm ơn."
        case .russian: "Даже малые количества могут вызвать серьёзную реакцию. Пожалуйста, избегайте любых следов или перекрёстного загрязнения. Спасибо."
        case .ukrainian: "Навіть малі кількості можуть викликати серйозну реакцію. Будь ласка, уникайте будь-яких слідів чи перехресного забруднення. Дякую."
        case .japanese: "少量でも重い反応を引き起こすことがあります。微量混入や交差汚染にもご注意ください。ありがとうございます。"
        case .korean: "소량이라도 심각한 반응을 일으킬 수 있습니다. 어떠한 흔적이나 교차 오염도 피해 주십시오. 감사합니다."
        case .chineseSimplified: "即使少量也可能引起严重反应。请避免任何残留或交叉污染。谢谢。"
        case .chineseTraditional: "即使少量也可能引起嚴重反應。請避免任何殘留或交叉污染。謝謝。"
        case .thai: "แม้ปริมาณเล็กน้อยก็อาจทำให้เกิดอาการรุนแรงได้ กรุณาหลีกเลี่ยงร่องรอยหรือการปนเปื้อนข้าม ขอบคุณค่ะ/ครับ"
        case .arabic: "حتى الكميات الصغيرة قد تسبب تفاعلاً خطيراً. يرجى تجنب أي آثار أو تلوث متبادل. شكراً."
        }
    }

    var isRTL: Bool { self == .arabic }
}

private enum AllergenTravelTranslations {
    static func translate(_ allergen: Allergen, to language: TravelCardLanguage) -> String {
        table[allergen.id]?[language] ?? allergen.name
    }

    private static let table: [String: [TravelCardLanguage: String]] = [
        "milk": [
            .spanish: "Lácteos", .french: "Produits laitiers", .german: "Milch",
            .italian: "Latticini", .portuguese: "Lacticínios", .vietnamese: "Sữa",
            .russian: "Молоко", .ukrainian: "Молоко", .japanese: "乳製品",
            .korean: "유제품", .chineseSimplified: "乳制品", .chineseTraditional: "乳製品",
            .thai: "นม", .arabic: "منتجات الألبان"
        ],
        "egg": [
            .spanish: "Huevo", .french: "Œuf", .german: "Ei",
            .italian: "Uovo", .portuguese: "Ovo", .vietnamese: "Trứng",
            .russian: "Яйца", .ukrainian: "Яйця", .japanese: "卵",
            .korean: "달걀", .chineseSimplified: "鸡蛋", .chineseTraditional: "雞蛋",
            .thai: "ไข่", .arabic: "بيض"
        ],
        "peanut": [
            .spanish: "Cacahuetes", .french: "Arachides", .german: "Erdnüsse",
            .italian: "Arachidi", .portuguese: "Amendoins", .vietnamese: "Đậu phộng",
            .russian: "Арахис", .ukrainian: "Арахіс", .japanese: "ピーナッツ",
            .korean: "땅콩", .chineseSimplified: "花生", .chineseTraditional: "花生",
            .thai: "ถั่วลิสง", .arabic: "فول سوداني"
        ],
        "tree_nut": [
            .spanish: "Frutos secos", .french: "Fruits à coque", .german: "Nüsse",
            .italian: "Frutta a guscio", .portuguese: "Frutos secos", .vietnamese: "Các loại hạt",
            .russian: "Орехи", .ukrainian: "Горіхи", .japanese: "ナッツ類",
            .korean: "견과류", .chineseSimplified: "坚果", .chineseTraditional: "堅果",
            .thai: "ถั่วเปลือกแข็ง", .arabic: "المكسرات"
        ],
        "soy": [
            .spanish: "Soja", .french: "Soja", .german: "Soja",
            .italian: "Soia", .portuguese: "Soja", .vietnamese: "Đậu nành",
            .russian: "Соя", .ukrainian: "Соя", .japanese: "大豆",
            .korean: "콩", .chineseSimplified: "大豆", .chineseTraditional: "大豆",
            .thai: "ถั่วเหลือง", .arabic: "فول الصويا"
        ],
        "wheat": [
            .spanish: "Trigo / Gluten", .french: "Blé / Gluten", .german: "Weizen / Gluten",
            .italian: "Grano / Glutine", .portuguese: "Trigo / Glúten", .vietnamese: "Lúa mì / Gluten",
            .russian: "Пшеница / Глютен", .ukrainian: "Пшениця / Глютен", .japanese: "小麦 / グルテン",
            .korean: "밀 / 글루텐", .chineseSimplified: "小麦 / 麸质", .chineseTraditional: "小麥 / 麩質",
            .thai: "ข้าวสาลี / กลูเตน", .arabic: "القمح / الغلوتين"
        ],
        "fish": [
            .spanish: "Pescado", .french: "Poisson", .german: "Fisch",
            .italian: "Pesce", .portuguese: "Peixe", .vietnamese: "Cá",
            .russian: "Рыба", .ukrainian: "Риба", .japanese: "魚",
            .korean: "생선", .chineseSimplified: "鱼", .chineseTraditional: "魚",
            .thai: "ปลา", .arabic: "السمك"
        ],
        "shellfish": [
            .spanish: "Mariscos", .french: "Crustacés", .german: "Schalentiere",
            .italian: "Crostacei", .portuguese: "Mariscos", .vietnamese: "Hải sản có vỏ",
            .russian: "Ракообразные", .ukrainian: "Ракоподібні", .japanese: "甲殻類",
            .korean: "갑각류", .chineseSimplified: "贝类", .chineseTraditional: "貝類",
            .thai: "หอย / กุ้ง / ปู", .arabic: "المحار والقشريات"
        ],
        "sesame": [
            .spanish: "Sésamo", .french: "Sésame", .german: "Sesam",
            .italian: "Sesamo", .portuguese: "Gergelim", .vietnamese: "Vừng",
            .russian: "Кунжут", .ukrainian: "Кунжут", .japanese: "ごま",
            .korean: "참깨", .chineseSimplified: "芝麻", .chineseTraditional: "芝麻",
            .thai: "งา", .arabic: "السمسم"
        ],
        "mustard": [
            .spanish: "Mostaza", .french: "Moutarde", .german: "Senf",
            .italian: "Senape", .portuguese: "Mostarda", .vietnamese: "Mù tạt",
            .russian: "Горчица", .ukrainian: "Гірчиця", .japanese: "マスタード",
            .korean: "겨자", .chineseSimplified: "芥末", .chineseTraditional: "芥末",
            .thai: "มัสตาร์ด", .arabic: "الخردل"
        ],
        "celery": [
            .spanish: "Apio", .french: "Céleri", .german: "Sellerie",
            .italian: "Sedano", .portuguese: "Aipo", .vietnamese: "Cần tây",
            .russian: "Сельдерей", .ukrainian: "Селера", .japanese: "セロリ",
            .korean: "셀러리", .chineseSimplified: "芹菜", .chineseTraditional: "芹菜",
            .thai: "ขึ้นฉ่าย", .arabic: "الكرفس"
        ],
        "lupin": [
            .spanish: "Altramuz", .french: "Lupin", .german: "Lupinen",
            .italian: "Lupini", .portuguese: "Tremoço", .vietnamese: "Đậu lupin",
            .russian: "Люпин", .ukrainian: "Люпин", .japanese: "ルピナス",
            .korean: "루핀", .chineseSimplified: "羽扇豆", .chineseTraditional: "羽扇豆",
            .thai: "ลูพิน", .arabic: "الترمس"
        ],
        "mollusc": [
            .spanish: "Moluscos", .french: "Mollusques", .german: "Weichtiere",
            .italian: "Molluschi", .portuguese: "Moluscos", .vietnamese: "Động vật thân mềm",
            .russian: "Моллюски", .ukrainian: "Молюски", .japanese: "軟体動物",
            .korean: "연체동물", .chineseSimplified: "软体动物", .chineseTraditional: "軟體動物",
            .thai: "หอย", .arabic: "الرخويات"
        ],
        "sulfite": [
            .spanish: "Sulfitos", .french: "Sulfites", .german: "Sulfite",
            .italian: "Solfiti", .portuguese: "Sulfitos", .vietnamese: "Sulfit",
            .russian: "Сульфиты", .ukrainian: "Сульфіти", .japanese: "亜硫酸塩",
            .korean: "아황산염", .chineseSimplified: "亚硫酸盐", .chineseTraditional: "亞硫酸鹽",
            .thai: "ซัลไฟต์", .arabic: "الكبريتات"
        ],
        "corn": [
            .spanish: "Maíz", .french: "Maïs", .german: "Mais",
            .italian: "Mais", .portuguese: "Milho", .vietnamese: "Ngô",
            .russian: "Кукуруза", .ukrainian: "Кукурудза", .japanese: "とうもろこし",
            .korean: "옥수수", .chineseSimplified: "玉米", .chineseTraditional: "玉米",
            .thai: "ข้าวโพด", .arabic: "الذرة"
        ],
        "coconut": [
            .spanish: "Coco", .french: "Noix de coco", .german: "Kokosnuss",
            .italian: "Cocco", .portuguese: "Coco", .vietnamese: "Dừa",
            .russian: "Кокос", .ukrainian: "Кокос", .japanese: "ココナッツ",
            .korean: "코코넛", .chineseSimplified: "椰子", .chineseTraditional: "椰子",
            .thai: "มะพร้าว", .arabic: "جوز الهند"
        ]
    ]

    static func icon(for allergenID: String) -> String {
        switch allergenID {
        case "milk": return "drop.fill"
        case "egg": return "circle.fill"
        case "fish", "shellfish", "mollusc": return "fish.fill"
        case "sesame": return "circle.grid.2x2.fill"
        case "mustard": return "drop.fill"
        case "sulfite": return "drop.triangle.fill"
        case "peanut", "tree_nut", "soy", "wheat", "lupin", "celery", "corn", "coconut": return "leaf.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
}

private struct TravelCardScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLanguage: TravelCardLanguage = .spanish
    @State private var showFullScreen = false

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    cardSection
                    actionButtonsSection
                    travelTipSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                TravelCardFullScreenView(
                    language: selectedLanguage,
                    allergens: appModel.trackedAllergens,
                    profileName: store.activeProfile?.name ?? "Verified User"
                )
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Allergy")
                    .font(.largeTitle.bold())
                Text("Information")
                    .font(.largeTitle.bold())
            }
            Spacer()
            Text("DIGITAL\nCARD")
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        }
    }

    private var cardSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(accentRed)
                .frame(height: 6)

            VStack(alignment: .leading, spacing: 20) {
                englishSection
                translationDivider
                translatedSection
                Divider()
                verifiedUserRow
            }
            .padding(20)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var englishSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ENGLISH")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text("I am allergic to:")
                .font(.title2.bold())

            VStack(spacing: 8) {
                ForEach(appModel.trackedAllergens) { allergen in
                    allergenChip(name: chipDisplayName(for: allergen), icon: AllergenTravelTranslations.icon(for: allergen.id))
                }
            }
        }
    }

    private var translationDivider: some View {
        HStack {
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
            Image(systemName: "character.bubble")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
        }
    }

    private var translatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            languagePicker

            Text(selectedLanguage.allergyPhrase)
                .font(.title2.bold())
                .multilineTextAlignment(selectedLanguage.isRTL ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: selectedLanguage.isRTL ? .trailing : .leading)

            VStack(alignment: selectedLanguage.isRTL ? .trailing : .leading, spacing: 10) {
                ForEach(appModel.trackedAllergens) { allergen in
                    translatedAllergenRow(allergen: allergen)
                }
            }
        }
    }

    private var languagePicker: some View {
        Menu {
            ForEach(TravelCardLanguage.allCases) { language in
                Button {
                    selectedLanguage = language
                } label: {
                    HStack {
                        Text("\(language.displayName) — \(language.nativeName)")
                        if language == selectedLanguage {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedLanguage.displayName.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
    }

    private func allergenChip(name: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(accentRed)
                .frame(width: 24, height: 24)
                .background(accentRed.opacity(0.1))
                .clipShape(Circle())

            Text(name)
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func translatedAllergenRow(allergen: Allergen) -> some View {
        let translated = AllergenTravelTranslations.translate(allergen, to: selectedLanguage)
        return HStack(spacing: 10) {
            Circle()
                .fill(accentRed)
                .frame(width: 6, height: 6)
            Text(translated)
                .font(.body.weight(.semibold))
            Spacer()
        }
    }

    private var verifiedUserRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.gray.opacity(0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text("VERIFIED USER")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(store.activeProfile?.name ?? "Verified User")
                    .font(.subheadline.bold())
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.blue)
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 10) {
            Button {
                showFullScreen = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("Show Full Screen")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentRed)

            ShareLink(item: shareText) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Card")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }

    private var travelTipSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Travel Tip")
                    .font(.subheadline.bold())
                Text("Show this card to servers and kitchen staff when ordering food abroad. It's pre-translated for clarity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func chipDisplayName(for allergen: Allergen) -> String {
        switch allergen.id {
        case "wheat": return "Gluten"
        case "milk": return "Dairy"
        case "tree_nut": return "Tree Nuts"
        default: return allergen.name
        }
    }

    private var shareText: String {
        let allergens = appModel.trackedAllergens
        guard !allergens.isEmpty else { return "Allergy Information" }
        let englishLines = allergens.map { "• \(chipDisplayName(for: $0))" }.joined(separator: "\n")
        let translatedLines = allergens
            .map { "• \(AllergenTravelTranslations.translate($0, to: selectedLanguage))" }
            .joined(separator: "\n")
        return """
        ALLERGY INFORMATION

        I am allergic to:
        \(englishLines)

        \(selectedLanguage.allergyPhrase)
        \(translatedLines)
        """
    }
}

private struct TravelCardFullScreenView: View {
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

// MARK: - First Aid

private struct FirstAidPlan {
    let allergenID: String
    let allergenName: String
    let symptoms: [Symptom]
    let actions: [Action]

    struct Symptom: Identifiable, Hashable {
        let title: String
        let description: String
        let icon: String
        var id: String { title }
    }

    struct Action: Identifiable, Hashable {
        let stepNumber: Int
        let title: String
        let description: String
        var id: Int { stepNumber }
    }
}

private enum FirstAidGuide {
    static func plan(for allergen: Allergen) -> FirstAidPlan {
        FirstAidPlan(
            allergenID: allergen.id,
            allergenName: allergen.name,
            symptoms: universalSymptoms,
            actions: actions(for: allergen)
        )
    }

    static var emergencyNumber: String {
        let region = Locale.current.region?.identifier ?? "US"
        switch region {
        case "US", "CA": return "911"
        case "GB": return "999"
        case "AU": return "000"
        case "NZ": return "111"
        case "JP": return "119"
        default: return "112"
        }
    }

    private static let universalSymptoms: [FirstAidPlan.Symptom] = [
        .init(title: "Swelling",   description: "Face, lips, or tongue expanding",  icon: "wave.3.right"),
        .init(title: "Hives",      description: "Red, itchy skin rashes or welts",  icon: "allergens"),
        .init(title: "Difficulty", description: "Wheezing or trouble breathing",    icon: "lungs.fill"),
        .init(title: "Dizziness",  description: "Fainting or rapid pulse drop",     icon: "heart.fill")
    ]

    private static func actions(for allergen: Allergen) -> [FirstAidPlan.Action] {
        let allergenLowercased = allergen.name.lowercased()
        return [
            .init(
                stepNumber: 1,
                title: "Use Epinephrine",
                description: "Inject your auto-injector (EpiPen) immediately into the outer thigh."
            ),
            .init(
                stepNumber: 2,
                title: "Call \(emergencyNumber) Immediately",
                description: "Tell the operator: \"Anaphylaxis\" and mention the \(allergenLowercased) exposure."
            ),
            .init(
                stepNumber: 3,
                title: "Position Correctly",
                description: "Lie down flat with legs raised. If vomiting, turn on your side."
            ),
            .init(
                stepNumber: 4,
                title: "Stay with Patient",
                description: "Monitor breathing until paramedics arrive. Record the time of injection."
            )
        ]
    }
}

private struct FirstAidListScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAllergen: Allergen?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCallout

                    if appModel.trackedAllergens.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appModel.trackedAllergens) { allergen in
                                Button {
                                    selectedAllergen = allergen
                                } label: {
                                    allergenRow(allergen)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    disclaimer
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("First Aid Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $selectedAllergen) { allergen in
                FirstAidScreen(allergen: allergen)
            }
        }
    }

    private var headerCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.title2)
                .foregroundStyle(accentRed)

            VStack(alignment: .leading, spacing: 4) {
                Text("Emergency Protocols")
                    .font(.headline)
                Text("Tap an allergen for the immediate response steps. The protocol applies the same to all food-allergic reactions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(accentRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func allergenRow(_ allergen: Allergen) -> some View {
        HStack(spacing: 14) {
            Image(systemName: AllergenTravelTranslations.icon(for: allergen.id))
                .font(.title3)
                .foregroundStyle(accentRed)
                .frame(width: 38, height: 38)
                .background(accentRed.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(allergen.name)
                    .font(.headline)
                Text("View emergency protocol")
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No tracked allergens")
                .font(.headline)
            Text("Add allergens to your profile to see emergency protocols.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text("This guide is for general reference. In any emergency, call your local emergency number first and follow your physician's individual care plan.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum FirstAidSeverity {
    case mild, severe
}

private struct FirstAidScreen: View {
    let allergen: Allergen
    @Environment(\.dismiss) private var dismiss
    @State private var severity: FirstAidSeverity?

    var body: some View {
        NavigationStack {
            Group {
                switch severity {
                case .none:
                    FirstAidTriageView(allergen: allergen) { severity = $0 }
                case .mild:
                    MildFirstAidView(allergen: allergen) { severity = .severe }
                case .severe:
                    SevereFirstAidView(allergen: allergen)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if severity != nil {
                        Button { severity = nil } label: {
                            Image(systemName: "chevron.backward")
                                .font(.subheadline.bold())
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: Triage

private struct FirstAidTriageView: View {
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

// MARK: Mild path

private struct MildFirstAidView: View {
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

// MARK: Severe path

private struct SevereFirstAidView: View {
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

// MARK: 911 Script

private struct EmergencyCallScriptView: View {
    let allergen: Allergen
    let injectionTime: Date?
    @Environment(\.dismiss) private var dismiss

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("READ THIS TO THE OPERATOR")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(0.8)

                    scriptCard

                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.blue)
                        Text("Speak slowly. Repeat the address. Stay on the line until paramedics arrive.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("911 Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var scriptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            scriptLine(label: "1", text: "I am having anaphylaxis from \(allergen.name.lowercased()) exposure.")
            Divider()
            scriptLine(label: "2", text: "I need an ambulance now.")
            Divider()
            scriptLine(label: "3", text: addressLine)
            Divider()
            scriptLine(label: "4", text: epinephrineLine)
            Divider()
            scriptLine(label: "5", text: "Please stay on the line. I may have trouble breathing.")
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func scriptLine(label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(.title2.bold())
                .foregroundStyle(accentRed)
                .frame(width: 26, alignment: .leading)
            Text(text)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var addressLine: String {
        "I am at [say your current address out loud]."
    }

    private var epinephrineLine: String {
        if let time = injectionTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "I used my EpiPen at \(formatter.string(from: time))."
        }
        return "I have not used an EpiPen yet."
    }
}

// MARK: - Flow Layout for Allergen Chips

private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += lineHeight + spacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct HistoryScreen: View {
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                if store.scanHistory.isEmpty {
                    ContentUnavailableView("No scans yet", systemImage: "doc.text.viewfinder", description: Text("Capture an ingredient label to create your first scan history item."))
                } else {
                    ForEach(store.scanHistory) { record in
                        Button {
                            appModel.selectedRecord = record
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(record.riskLevel.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundStyle(.secondary)
                                }
                                Text(record.matches.map(\.allergenName).joined(separator: ", ").ifEmpty("No tracked allergens detected"))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: appModel.deleteHistory)
                }
            }
            .navigationTitle("History")
            .sheet(item: $appModel.selectedRecord) { record in
                ResultDetailView(record: record)
            }
        }
    }
}

private struct SettingsGate: View {
    @EnvironmentObject private var store: PersistenceStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked = false
    @State private var isAuthenticating = false

    private let biometricAuthService = BiometricAuthService()
    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    private var lockEnabled: Bool { store.securitySettings.isBiometricLockEnabled }

    var body: some View {
        Group {
            if !lockEnabled || isUnlocked {
                SettingsScreen()
            } else {
                lockedScreen
            }
        }
        .onAppear {
            if lockEnabled && !isUnlocked {
                Task { await tryUnlock() }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-lock when the app goes to the background, NOT on tab switch
            // and NOT during the Face ID prompt itself (which can flip phase briefly).
            if newPhase == .background && !isAuthenticating {
                isUnlocked = false
            }
        }
    }

    private var lockedScreen: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(accentRed)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("Settings Locked")
                    .font(.title2.bold())
                Text("Use Face ID or Touch ID to access settings, profile, and emergency contact info.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                Task { await tryUnlock() }
            } label: {
                HStack(spacing: 8) {
                    if isAuthenticating {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "faceid")
                    }
                    Text("Unlock")
                        .font(.headline)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(accentRed)
                .clipShape(Capsule())
            }
            .disabled(isAuthenticating)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func tryUnlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let success = await biometricAuthService.authenticate(reason: "Unlock AllerScan settings")
        isUnlocked = success
    }
}

private struct SyncStatusRow: View {
    @EnvironmentObject private var syncService: SyncService

    private var icon: String {
        switch syncService.status {
        case .syncing:      return "arrow.triangle.2.circlepath"
        case .idle:         return "checkmark.icloud.fill"
        case .offline:      return "icloud.slash.fill"
        case .error:        return "exclamationmark.icloud.fill"
        case .notSignedIn:  return "icloud.slash"
        }
    }

    private var iconColor: Color {
        switch syncService.status {
        case .syncing:      return .blue
        case .idle:         return .green
        case .offline:      return .orange
        case .error:        return .red
        case .notSignedIn:  return .secondary
        }
    }

    private var title: String {
        switch syncService.status {
        case .syncing:      return "Syncing…"
        case .idle:         return "Up to date"
        case .offline:      return "Offline"
        case .error:        return "Sync failed"
        case .notSignedIn:  return "Not signed in"
        }
    }

    private var subtitle: String {
        switch syncService.status {
        case .syncing:
            return syncService.pendingOperations > 1
                ? "\(syncService.pendingOperations) changes uploading"
                : "Saving your changes…"
        case .idle:
            if let last = syncService.lastSyncDate {
                return "Last synced \(relativeText(from: last))"
            }
            return "Connected to cloud"
        case .offline:
            return "Changes will upload when you're back online"
        case .error(let message):
            return message
        case .notSignedIn:
            return "Sign in to back up your data"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Group {
                    if syncService.status == .syncing {
                        ProgressView().tint(iconColor)
                    } else {
                        Image(systemName: icon)
                            .foregroundStyle(iconColor)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func relativeText(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct SettingsScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService

    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var showMedicalIDInstructions = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfilesScreen()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(.blue)
                                Text(store.activeProfile?.name ?? "No profile")
                                    .font(.headline)
                            }
                            Text("\(store.profiles.count) profile\(store.profiles.count == 1 ? "" : "s") • \(store.activeProfile?.trackedAllergenIDs.count ?? 0) tracked allergens")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Edit current profile") {
                        if let profile = store.activeProfile {
                            appModel.startEditingProfile(profile)
                        }
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Tap above to switch between family members or add a new profile.")
                        .font(.caption)
                }

                Section {
                    TextField("Name", text: $contactName)
                        .textContentType(.name)
                    TextField("Phone number", text: $contactPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    Button("Save emergency contact") {
                        appModel.updateEmergencyContact(
                            EmergencyContact(
                                name: contactName.trimmingCharacters(in: .whitespaces),
                                phoneNumber: contactPhone.trimmingCharacters(in: .whitespaces)
                            )
                        )
                    }
                    .disabled(contactName.trimmingCharacters(in: .whitespaces).isEmpty
                              || contactPhone.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Emergency Contact")
                } footer: {
                    Text("During an allergic reaction, you can send an SMS with your location to this contact from the First Aid screen.")
                        .font(.caption)
                }

                Section {
                    Button {
                        copyAllergensAndOpenHealth()
                    } label: {
                        Label("Add allergens to Medical ID", systemImage: "heart.text.square.fill")
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Your tracked allergens will be copied to the clipboard. The Health app will open — tap Medical ID → Edit → Allergies & Reactions, then paste.")
                        .font(.caption)
                }

                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Siri in an Emergency")
                                .font(.subheadline.bold())
                            Text("Say \"Hey Siri, allergic reaction help in AllerScan\" to open the First Aid screen instantly.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Siri Shortcut")
                }

                Section {
                    Toggle("Lock Settings", isOn: Binding(
                        get: { store.securitySettings.isBiometricLockEnabled },
                        set: { newValue in
                            Task {
                                await appModel.updateBiometricLock(newValue)
                            }
                        }
                    ))
                } header: {
                    Text("Security")
                } footer: {
                    Text("Require Face ID or Touch ID to view or change profiles, allergens, emergency contact, and account info. Other parts of the app stay instantly accessible.")
                        .font(.caption)
                }

                Section("Notifications") {
                    Toggle("Daily safety reminder", isOn: Binding(
                        get: { store.securitySettings.notificationsEnabled },
                        set: { newValue in
                            Task {
                                await appModel.updateNotifications(enabled: newValue, reminderDate: appModel.reminderDate)
                            }
                        }
                    ))

                    DatePicker(
                        "Reminder time",
                        selection: Binding(
                            get: { appModel.reminderDate },
                            set: { newValue in
                                Task {
                                    await appModel.updateNotifications(
                                        enabled: store.securitySettings.notificationsEnabled,
                                        reminderDate: newValue
                                    )
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!store.securitySettings.notificationsEnabled)
                }

                Section {
                    SyncStatusRow()
                    Button {
                        Task { await syncService.syncNow() }
                    } label: {
                        Label(
                            syncService.status == .syncing ? "Syncing…" : "Sync Now",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .disabled(syncService.status == .syncing
                              || syncService.status == .notSignedIn
                              || syncService.status == .offline)
                } header: {
                    Text("Cloud Sync")
                } footer: {
                    Text("Profiles, scan history, and custom allergens are encrypted in transit and stored under your Apple ID-linked account in Firestore. Pushes happen automatically; tap Sync Now to pull the latest from cloud.")
                        .font(.caption)
                }

                Section {
                    Button(role: .destructive) {
                        try? authService.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } footer: {
                    if !authService.email.isEmpty {
                        Text("Signed in as \(authService.email)")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                contactName = store.securitySettings.emergencyContact.name
                contactPhone = store.securitySettings.emergencyContact.phoneNumber
            }
            .alert("Allergens copied", isPresented: $showMedicalIDInstructions) {
                Button("Open Health app") { openHealthApp() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your tracked allergens are on the clipboard. In Health: tap your photo → Medical ID → Edit → Allergies & Reactions, then paste.")
            }
        }
    }

    private func copyAllergensAndOpenHealth() {
        let names = appModel.trackedAllergens.map(\.name)
        guard !names.isEmpty else { return }
        UIPasteboard.general.string = names.joined(separator: ", ")
        showMedicalIDInstructions = true
    }

    private func openHealthApp() {
        if let url = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

private struct ProfilesScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @State private var profileToDelete: UserProfile?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        List {
            Section {
                ForEach(store.profiles) { profile in
                    profileRow(profile)
                }
            } header: {
                Text("Profiles")
            } footer: {
                Text("Switch between profiles to scan ingredients against different allergen lists. Useful for families.")
                    .font(.caption)
            }

            Section {
                Button {
                    appModel.startCreatingNewProfile()
                } label: {
                    Label("Add new profile", systemImage: "plus.circle.fill")
                        .foregroundStyle(accentRed)
                }
            }
        }
        .navigationTitle("Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Delete profile?",
            isPresented: Binding(get: { profileToDelete != nil }, set: { if !$0 { profileToDelete = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    appModel.deleteProfile(id: profile.id)
                }
                profileToDelete = nil
            }
            Button("Cancel", role: .cancel) { profileToDelete = nil }
        } message: {
            Text("\"\(profileToDelete?.name ?? "")\" will be removed. This can't be undone.")
        }
    }

    private func profileRow(_ profile: UserProfile) -> some View {
        let isActive = profile.id == store.activeProfile?.id

        return Button {
            appModel.switchActiveProfile(to: profile.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? accentRed : Color(.tertiaryLabel))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(profile.trackedAllergenIDs.count) allergen\(profile.trackedAllergenIDs.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        appModel.startEditingProfile(profile)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if store.profiles.count > 1 {
                        Button(role: .destructive) {
                            profileToDelete = profile
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PermissionRow: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension String {
    func ifEmpty(_ replacement: String) -> String {
        isEmpty ? replacement : self
    }
}
