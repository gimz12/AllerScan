import SwiftUI

struct SettingsGate: View {
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
