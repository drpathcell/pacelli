import SwiftUI

/// Root of the native app.
///
/// **Design invariant (Guideline 5.1.1(v), build 25 rejection):** guest mode
/// is a first-class path. "Continue as guest" must land on a fully usable
/// Home — anonymous auth, auto-provisioned household, zero setup walls.
/// Account creation is an optional upgrade (`linkWithCredential` semantics),
/// never a gate.
struct RootView: View {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    // Theme (local prefs — Flutter SharedPreferences parity).
    @AppStorage(ThemeStorageKeys.colorScheme) private var schemeRaw =
        AppColorSchemeChoice.pacelli.rawValue
    @AppStorage(ThemeStorageKeys.themeMode) private var modeRaw =
        AppThemeModeChoice.system.rawValue

    var body: some View {
        Group {
            switch appState.phase {
            case .welcome:
                WelcomeView(appState: appState)
            case .working(let label):
                ProgressView(label)
            case .home(let current):
                HomeView(current: current, appState: appState)
            }
        }
        .tint((AppColorSchemeChoice(rawValue: schemeRaw) ?? .pacelli).tint)
        .preferredColorScheme(
            (AppThemeModeChoice(rawValue: modeRaw) ?? .system).preferredColorScheme)
        // Session restore runs exactly once per launch, at the root —
        // never from WelcomeView appearance (that caused a retry loop).
        .task { await appState.start() }
        // Reminders are rebuilt whenever the app comes forward, so the
        // schedule reflects what the household actually looks like now.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await appState.reconcileReminders() }
        }
    }
}

struct WelcomeView: View {
    let appState: AppState

    @State private var showSignIn = false
    @State private var showJoin = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Pacelli")
                .font(.largeTitle.bold())

            Text("A peaceful, organised home")
                .font(.title3)
                .foregroundStyle(.secondary)

            if let error = appState.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Guest-first: primary action requires no account.
            Button {
                Task { await appState.enterGuestMode() }
            } label: {
                Text("Continue as guest")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                showSignIn = true
            } label: {
                Text("Sign in")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            // A joiner's first run. Without this they sign in, get an empty
            // auto-provisioned household, and have to go hunting in Household
            // settings for the code field — and with Sign in with Apple hiding
            // their email, an emailed invite could never have reached them.
            Button {
                showJoin = true
            } label: {
                Text("I have a join code")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .accessibilityIdentifier("welcome_join_code")
        }
        .padding(24)
        .sheet(isPresented: $showSignIn) {
            AuthView(mode: .signIn, appState: appState)
        }
        .sheet(isPresented: $showJoin) {
            JoinHouseholdView(appState: appState)
        }
    }
}

/// Redeem a join code with no account and no setup — the joiner's entry
/// point. Signing in is not required: `AppState.joinWithCode` creates an
/// anonymous session if there isn't one, matching the guest-first invariant.
struct JoinHouseholdView: View {
    let appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var joining = false

    private var normalized: String { JoinCodeService.normalize(code) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("K7QP-4M2X", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced))
                        .accessibilityIdentifier("join_sheet_field")
                        .onSubmit(join)
                } header: {
                    Text("Join code")
                } footer: {
                    Text(
                        "Ask someone already in the household to open Household → Join code. You don't need an account — you can add one later."
                    )
                }

                Section {
                    Button(action: join) {
                        if joining {
                            ProgressView()
                        } else {
                            Text("Join household")
                        }
                    }
                    .disabled(normalized.count != 8 || joining)
                    .accessibilityIdentifier("join_sheet_submit")
                }
            }
            .navigationTitle("Join a household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func join() {
        guard normalized.count == 8, !joining else { return }
        joining = true
        Task {
            defer { joining = false }
            let joined = await appState.joinWithCode(normalized)
            // On failure AppState puts the message on the Welcome screen, so
            // dismiss either way rather than showing it in two places.
            dismiss()
            _ = joined
        }
    }
}

#Preview {
    RootView()
}
