import AuthenticationServices
import SwiftUI

/// Sign-in / create-account sheet. Two modes:
/// - `.signIn`   — from Welcome ("Sign in")
/// - `.upgrade`  — from Home for guests ("Create account"): the SAME flows,
///   but the anonymous session is upgraded in place (uid, household and
///   keys preserved) via `linkWithCredential` semantics in AuthService.
struct AuthView: View {
    enum Mode {
        case signIn
        case upgrade
    }

    let mode: Mode
    let appState: AppState

    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingAccount: Bool
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var appleNonce = ""

    init(mode: Mode, appState: AppState) {
        self.mode = mode
        self.appState = appState
        _isCreatingAccount = State(initialValue: mode == .upgrade)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SignInWithAppleButton(.continue) { request in
                        appleNonce = AuthService.randomNonce()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AuthService.sha256(appleNonce)
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            run {
                                try await AuthService.signInWithApple(
                                    authorization, rawNonce: appleNonce)
                            }
                        case .failure(let error):
                            // User-cancelled is not an error worth showing.
                            if (error as? ASAuthorizationError)?.code != .canceled {
                                errorText = error.localizedDescription
                            }
                        }
                    }
                    .frame(height: 48)
                    .listRowInsets(EdgeInsets())
                }

                Section(isCreatingAccount ? "Create account" : "Sign in") {
                    if isCreatingAccount {
                        TextField("Name", text: $name)
                            .textContentType(.name)
                    }
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(isCreatingAccount ? .newPassword : .password)

                    Button(isCreatingAccount ? "Create account" : "Sign in") {
                        // Snapshot main-actor state before the @Sendable flow.
                        let creating = isCreatingAccount
                        let email = email, password = password, name = name
                        run {
                            if creating {
                                try await AuthService.signUp(
                                    email: email, password: password, name: name)
                            } else {
                                try await AuthService.signIn(
                                    email: email, password: password)
                            }
                        }
                    }
                    .disabled(busy || email.isEmpty || password.isEmpty)
                }

                Section {
                    Button(
                        isCreatingAccount
                            ? "Already have an account? Sign in"
                            : "New here? Create an account"
                    ) {
                        isCreatingAccount.toggle()
                        errorText = nil
                    }
                    .font(.callout)
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode == .upgrade ? "Create your account" : "Welcome back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if busy {
                    ToolbarItem(placement: .confirmationAction) { ProgressView() }
                }
            }
            .interactiveDismissDisabled(busy)
        }
    }

    /// Runs an auth flow with a deadline, then hands off to AppState.
    private func run(_ flow: @escaping @Sendable () async throws -> Void) {
        errorText = nil
        busy = true
        Task {
            do {
                try await withTimeout(30) { try await flow() }
                dismiss()
                await appState.postAuth()
            } catch {
                print("[AuthView] auth failed: \(error)")
                errorText = friendlyMessage(for: error)
            }
            busy = false
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if error is TimeoutError {
            return String(localized: "That took too long. Check your connection and try again.")
        }
        return (error as NSError).localizedDescription
    }
}
