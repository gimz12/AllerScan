import SwiftUI

enum AuthScreen: Hashable {
    case login, signUp, resetPassword
}

struct AuthFlowView: View {
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
