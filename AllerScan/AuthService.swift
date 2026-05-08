import Combine
import FirebaseAuth
import Foundation

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isInitializing = true
    @Published private(set) var isEmailVerified = false

    private var authStateListener: AuthStateDidChangeListenerHandle?

    var isAuthenticated: Bool { currentUser != nil }
    var displayName: String { currentUser?.displayName ?? "" }
    var email: String { currentUser?.email ?? "" }

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                self.currentUser = user
                self.isEmailVerified = user?.isEmailVerified ?? false
                self.isInitializing = false
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    func signUp(name: String, email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        try await result.user.sendEmailVerification()
        currentUser = result.user
        isEmailVerified = result.user.isEmailVerified
    }

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        currentUser = result.user
        isEmailVerified = result.user.isEmailVerified
    }

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        isEmailVerified = false
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func resendVerificationEmail() async throws {
        try await Auth.auth().currentUser?.sendEmailVerification()
    }

    @discardableResult
    func refreshVerificationStatus() async throws -> Bool {
        try await Auth.auth().currentUser?.reload()
        let verified = Auth.auth().currentUser?.isEmailVerified ?? false
        isEmailVerified = verified
        if verified {
            currentUser = Auth.auth().currentUser
        }
        return verified
    }
}

extension AuthService {
    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code)
        else {
            return error.localizedDescription
        }
        switch code {
        case .invalidEmail:                 return "That email address looks invalid."
        case .emailAlreadyInUse:            return "An account already exists with that email."
        case .weakPassword:                 return "Password must be at least 6 characters."
        case .wrongPassword, .invalidCredential, .userNotFound:
                                            return "Email or password is incorrect."
        case .userDisabled:                 return "This account has been disabled."
        case .networkError:                 return "Network error. Check your connection and try again."
        case .tooManyRequests:              return "Too many attempts. Wait a moment and try again."
        default:                            return error.localizedDescription
        }
    }
}
