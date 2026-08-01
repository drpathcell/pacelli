import AuthenticationServices
import FirebaseAuth
import SwiftUI

/// Burn-all-data screen. Port of the Flutter `burn_data_screen.dart` flow:
/// warnings → confirm → staged wipe with live log → account deletion
/// (re-auth on demand) → local cleanup → back to Welcome.
/// Fails loudly with a Retry — never fakes success.
struct BurnDataView: View {
    let appState: AppState

    enum Phase: Equatable {
        case idle
        case running
        case needsReauth
        case failed(String)
        case done
    }

    @State private var phase: Phase = .idle
    @State private var logLines: [String] = []
    @State private var confirming = false

    // Email re-auth prompt state.
    @State private var showPasswordPrompt = false
    @State private var reauthPassword = ""
    // SIWA re-auth nonce.
    @State private var appleNonce = ""

    private var user: User? { Auth.auth().currentUser }
    private var isGuest: Bool { user?.isAnonymous ?? false }
    private var providerID: String? { user?.providerData.first?.providerID }

    var body: some View {
        List {
            Section {
                Label("This permanently deletes your tasks, checklists, plans, categories, household and account.", systemImage: "flame")
                Label("Everyone in your household loses this data — tell them first.", systemImage: "person.2")
                Label("Files saved to Google Drive are NOT deleted — remove those in Drive yourself.", systemImage: "externaldrive")
                Label("This cannot be undone.", systemImage: "exclamationmark.triangle")
            } header: {
                Text("Before you burn")
            }
            .font(.callout)

            if !logLines.isEmpty {
                Section("Progress") {
                    ForEach(Array(logLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                switch phase {
                case .idle:
                    Button("Burn all data", role: .destructive) { confirming = true }
                        .accessibilityIdentifier("burnButton")
                case .running:
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Burning… don't close the app")
                    }
                case .needsReauth:
                    reauthButtons
                case .failed(let message):
                    Label(message, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                        .font(.callout)
                    Button("Retry", role: .destructive) { start() }
                case .done:
                    Label("Everything has been deleted.", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Burn all data")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(phase == .running)
        .confirmationDialog(
            "Delete everything?", isPresented: $confirming, titleVisibility: .visible
        ) {
            Button("Burn all data and delete my account", role: .destructive) {
                start()
            }
        } message: {
            Text("Your household data, encryption keys and account will be permanently deleted. This can't be undone.")
        }
        .alert("Confirm your password", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $reauthPassword)
            Button("Cancel", role: .cancel) { reauthPassword = "" }
            Button("Confirm", role: .destructive) { reauthWithEmail() }
        } message: {
            Text("Deleting your account needs a recent sign-in.")
        }
    }

    /// Provider-appropriate re-auth affordances, shown only when Firebase
    /// rejected the deletion with requires-recent-login.
    @ViewBuilder
    private var reauthButtons: some View {
        Label("Confirm your identity to finish deleting your account.", systemImage: "person.badge.key")
            .font(.callout)
        switch providerID {
        case "apple.com":
            SignInWithAppleButton(.continue) { request in
                appleNonce = AuthService.randomNonce()
                request.requestedScopes = []
                request.nonce = AuthService.sha256(appleNonce)
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    reauthWithApple(authorization)
                case .failure(let error):
                    phase = .failed(error.localizedDescription)
                }
            }
            .frame(height: 44)
        case "google.com":
            Button("Continue with Google") { reauthWithGoogle() }
        default:  // password (or unknown): prompt for the password
            Button("Confirm password") { showPasswordPrompt = true }
        }
        Button("Cancel") {
            phase = .failed(String(localized: "Account deletion was cancelled. Your data has already been wiped; sign-in state is unchanged."))
        }
    }

    // MARK: - Flow

    private func log(_ line: String) {
        Task { @MainActor in logLines.append(line) }
    }

    private func start() {
        phase = .running
        logLines = []
        Task {
            do {
                // Steps mirror the Dart burn screen order.
                try await BurnService.wipeFirestoreData(log: log)
                try await deleteAccountStep()
                await finish()
            } catch BurnService.BurnError.needsRecentLogin {
                if isGuest {
                    // Guests have no credential to re-auth with. Their data
                    // is already wiped; the empty anonymous auth record is
                    // abandoned on sign-out (holds no data, can't be reused).
                    log("Guest account record couldn't be deleted (stale session) — it holds no data; signing out instead")
                    await finish()
                } else {
                    log("Account deletion needs a recent sign-in")
                    phase = .needsReauth
                }
            } catch {
                log("FAILED: \(error.localizedDescription)")
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func deleteAccountStep() async throws {
        log("Deleting your account…")
        try await BurnService.deleteAccount(log: log)
    }

    /// Post-reauth continuation: delete account, then local cleanup.
    private func resumeAfterReauth() {
        phase = .running
        Task {
            do {
                try await deleteAccountStep()
                await finish()
            } catch {
                log("FAILED: \(error.localizedDescription)")
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func finish() async {
        await BurnService.clearLocalState(log: log)
        log("Done")
        phase = .done
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        await appState.signOut()
    }

    // MARK: - Re-auth paths

    private func reauthWithEmail() {
        guard let email = user?.email else {
            phase = .failed(String(localized: "No email on this account."))
            return
        }
        let password = reauthPassword
        reauthPassword = ""
        phase = .running
        Task {
            do {
                try await AuthService.reauthenticate(email: email, password: password)
                log("Identity confirmed")
                resumeAfterReauth()
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func reauthWithApple(_ authorization: ASAuthorization) {
        phase = .running
        Task {
            do {
                try await AuthService.reauthenticateWithApple(
                    authorization, rawNonce: appleNonce)
                log("Identity confirmed")
                resumeAfterReauth()
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func reauthWithGoogle() {
        phase = .running
        Task {
            do {
                try await AuthService.reauthenticateWithGoogle()
                log("Identity confirmed")
                resumeAfterReauth()
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
