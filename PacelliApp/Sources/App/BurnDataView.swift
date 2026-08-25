import AuthenticationServices
import FirebaseAuth
import PacelliKit
import SwiftUI

/// The destructive screen — two operations that used to be one button.
///
/// Until 1.10.0 "Burn all data" wiped the household AND deleted the account in
/// a single confirm. That conflated an act affecting only you with an act
/// affecting everyone you live with, and it made the whole thing ungateable:
/// App Store Guideline 5.1.1(v) requires in-app account deletion, so any
/// permission attached to the combined button would have blocked account
/// deletion too and the app could not have shipped.
///
/// So the screen shows them apart:
///
///   - **Burn household data** — subject to the owner's `burn_permission`.
///     What the server allows is what this screen offers; the answer comes
///     from the same code that enforces it (`BurnPolicyService.fetch`), never
///     recomputed here.
///   - **Delete my account** — always available, no permission consulted, and
///     deliberately placed second so the safer-for-others option is not the
///     one under your thumb.
///
/// Fails loudly with a Retry — never fakes success.
struct BurnDataView: View {
    let current: CurrentHousehold
    let appState: AppState

    enum Phase: Equatable {
        case idle
        case running
        case needsReauth
        case failed(String)
        /// Household data gone; the account and the household still exist.
        case burned(Int)
        /// Account gone. Terminal — the app signs out behind it.
        case done
    }

    @State private var phase: Phase = .idle
    @State private var logLines: [String] = []
    @State private var confirmingBurn = false
    @State private var confirmingDelete = false

    @State private var policy: BurnPolicyService.Policy = .unknown
    @State private var policyError: String?
    @State private var loadingPolicy = true

    // Email re-auth prompt state.
    @State private var showPasswordPrompt = false
    @State private var reauthPassword = ""
    // SIWA re-auth nonce.
    @State private var appleNonce = ""

    private var user: User? { Auth.auth().currentUser }
    private var isGuest: Bool { user?.isAnonymous ?? false }
    private var providerID: String? { user?.providerData.first?.providerID }
    private var busy: Bool { phase == .running || phase == .needsReauth }

    var body: some View {
        List {
            householdBurnSection
            accountDeletionSection

            if !logLines.isEmpty {
                Section("Progress") {
                    ForEach(Array(logLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            switch phase {
            case .running:
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Working… don't close the app")
                    }
                }
            case .needsReauth:
                Section { reauthButtons }
            case .failed(let message):
                Section {
                    Label(message, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .accessibilityIdentifier("burnFailure")
                }
            case .burned(let total):
                Section {
                    Label(
                        "\(total) shared record(s) deleted. Your account is untouched.",
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("burnSucceeded")
                }
            case .done:
                Section {
                    Label("Your account has been deleted.", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            case .idle:
                EmptyView()
            }
        }
        .navigationTitle("Delete data")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(busy)
        .task { await loadPolicy() }
        .confirmationDialog(
            "Erase everything the household shares?",
            isPresented: $confirmingBurn, titleVisibility: .visible
        ) {
            Button("Burn household data", role: .destructive) { startBurn() }
        } message: {
            Text("Tasks, checklists, plans, photos and the manual will be permanently deleted for everyone in the household. Your account and everyone's membership stay.")
        }
        .confirmationDialog(
            "Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete my account", role: .destructive) { startAccountDeletion() }
        } message: {
            Text("Your membership, profile, encryption keys and sign-in are permanently deleted. Shared household data stays for the others — unless you are the last member, in which case it goes with you.")
        }
        .alert("Confirm your password", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $reauthPassword)
            Button("Cancel", role: .cancel) { reauthPassword = "" }
            Button("Confirm", role: .destructive) { reauthWithEmail() }
        } message: {
            Text("Deleting your account needs a recent sign-in.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var householdBurnSection: some View {
        Section {
            Label("Deletes tasks, checklists, plans, photos and the manual for EVERYONE in the household.", systemImage: "flame")
            Label("Files saved to Google Drive are NOT deleted — remove those in Drive yourself.", systemImage: "externaldrive")
            Label("This cannot be undone.", systemImage: "exclamationmark.triangle")

            if loadingPolicy {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Checking what you're allowed to do…").foregroundStyle(.secondary)
                }
            } else if let policyError {
                // Fails closed, and says why rather than hiding the button
                // without explanation.
                Label(policyError, systemImage: "wifi.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Try again") { Task { await loadPolicy() } }
            } else if policy.mayBurn {
                Button("Burn household data", role: .destructive) { confirmingBurn = true }
                    .accessibilityIdentifier("burnHouseholdButton")
                    .disabled(busy)
            } else {
                Label(
                    policy.permission == .nobody
                        ? String(localized: "Burning this household's data is switched off.")
                        : String(localized: "Only people the household owner has allowed can burn this household's data."),
                    systemImage: "lock"
                )
                .font(.callout)
                .accessibilityIdentifier("burnNotPermitted")
            }

            if policy.isOwner {
                NavigationLink {
                    BurnPermissionView(current: current, policy: policy) { updated in
                        policy = updated
                    }
                } label: {
                    Label("Who can burn this data", systemImage: "person.badge.shield.checkmark")
                }
                .accessibilityIdentifier("burnPermissionLink")
            }
        } header: {
            Text("Household data")
        } footer: {
            Text("Everyone in your household loses this data — tell them first.")
        }
        .font(.callout)
    }

    @ViewBuilder
    private var accountDeletionSection: some View {
        Section {
            Label("Deletes your membership, profile, encryption keys and sign-in.", systemImage: "person.crop.circle.badge.xmark")
            Label("The household's shared data stays for everyone else.", systemImage: "person.2")
            Button("Delete my account", role: .destructive) { confirmingDelete = true }
                .accessibilityIdentifier("deleteAccountButton")
                .disabled(busy)
        } header: {
            Text("Your account")
        } footer: {
            // Stated plainly because it is the promise the app makes to App
            // Review, and because a user reading a permission on the section
            // above will reasonably wonder whether this one is gated too.
            Text("Always available. No one can take this away from you, including the household owner.")
        }
        .font(.callout)
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

    private func loadPolicy() async {
        loadingPolicy = true
        policyError = nil
        do {
            policy = try await BurnPolicyService.fetch()
        } catch {
            // Deliberately leaves `policy` at `.unknown`, which permits
            // nothing. Account deletion below is unaffected — it never asks.
            policy = .unknown
            policyError = String(
                localized: "Couldn't check who's allowed to burn this household's data. \(error.localizedDescription)")
        }
        loadingPolicy = false
    }

    private func startBurn() {
        phase = .running
        logLines = []
        Task {
            do {
                let total = try await BurnService.burnHouseholdData(log: log)
                phase = .burned(total)
            } catch {
                log("FAILED: \(error.localizedDescription)")
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func startAccountDeletion() {
        phase = .running
        logLines = []
        Task {
            do {
                try await BurnService.deleteMyAccountData(log: log)
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
