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

                    Button {
                        runGoogle()
                    } label: {
                        HStack(spacing: 10) {
                            // Google brand "G" (four-colour), drawn in text —
                            // no bundled asset needed, close to the brand mark.
                            Text("G")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color(red: 0.918, green: 0.263, blue: 0.208), location: 0.0),
                                            .init(color: Color(red: 0.984, green: 0.737, blue: 0.02), location: 0.35),
                                            .init(color: Color(red: 0.204, green: 0.659, blue: 0.325), location: 0.65),
                                            .init(color: Color(red: 0.259, green: 0.522, blue: 0.957), location: 1.0),
                                        ],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("Continue with Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(uiColor: .separator), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .disabled(busy)
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

private func runGoogle() {
        errorText = nil
        busy = true
        Task {
            do {
                try await AuthService.signInWithGoogle()
                dismiss()
                await appState.postAuth()
            } catch {
                if !isGoogleCancellation(error) {
                    print("[AuthView] google auth failed: \(error)")
                    errorText = friendlyMessage(for: error)
                }
            }
            busy = false
        }
    }

    /// GIDSignInError.canceled (user dismissed the sheet) — not worth surfacing.
    private func isGoogleCancellation(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == "com.google.GIDSignIn" && ns.code == -5
    }

    private func friendlyMessage(for error: Error) -> String {
        if error is TimeoutError {
            return String(localized: "That took too long. Check your connection and try again.")
        }
        return (error as NSError).localizedDescription
    }
}
