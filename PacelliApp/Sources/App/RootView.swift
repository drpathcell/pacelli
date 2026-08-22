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
    @State private var lock = BiometricLock()
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
        // Covers the household whenever the app is not frontmost, which
        // includes the app-switcher snapshot iOS takes on the way out. A lock
        // that only appears on return still shows your tasks to anyone who
        // double-taps the home bar.
        .overlay {
            if lock.isEnabled && (lock.isLocked || scenePhase != .active) {
                LockScreen(lock: lock, canPrompt: scenePhase == .active)
                    .transition(.opacity)
            }
        }
        // Session restore runs exactly once per launch, at the root —
        // never from WelcomeView appearance (that caused a retry loop).
        .task { await appState.start() }
        // A cold launch starts locked. Doing this in .task rather than in the
        // initialiser keeps it off the main-actor init path and means the
        // prompt appears once the window exists to present it over.
        .task {
            lock.lockIfEnabled()
            await lock.unlock()
            await appState.reconcilePhotos()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lock.lockIfEnabled()
            case .active:
                // Reminders are rebuilt whenever the app comes forward, so the
                // schedule reflects what the household actually looks like now.
                Task { await appState.reconcileReminders() }
                // Same moment, same reason: a photo whose upload was cut off
                // gets another go, and local originals whose document has gone
                // get cleaned up.
                Task { await appState.reconcilePhotos() }
                Task { await lock.unlock() }
            default:
                break
            }
        }
    }
}

/// The cover. Two jobs, and it must be able to do the first without the
/// second: hide the content, and offer a way back in.
///
/// `canPrompt` is false while the app is inactive — raising a Face ID sheet
/// against a backgrounding app is how you get a prompt the user cannot answer
/// and a lock they cannot clear.
struct LockScreen: View {
    let lock: BiometricLock
    let canPrompt: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)

                Text("Pacelli is locked")
                    .font(.title3.weight(.semibold))

                if canPrompt {
                    Button("Unlock with \(BiometricLock.biometryLabel)") {
                        Task { await lock.unlock() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lock_unlock_button")

                    if let error = lock.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
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
