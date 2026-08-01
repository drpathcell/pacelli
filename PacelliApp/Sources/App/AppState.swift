import FirebaseAuth
import Foundation
import Observation
import PacelliKit

/// Session state machine: welcome → working → home.
///
/// Hard rules (build 26 field lesson — iPhone stuck on "Loading your home…"):
/// 1. Session restore runs ONCE per launch (`start()` from RootView), never
///    from view-appearance side effects — no retry loops.
/// 2. Every Firebase await is deadline-bound (`withTimeout`) — the UI can
///    never wait forever.
/// 3. A session that can't produce a usable Home within the deadline is
///    signed out: Keychain-restored sessions survive app reinstalls (the
///    Flutter app's session leaks into this bundle ID), and the walking
///    skeleton has no sign-in UI to serve them yet. Guest-first, no walls.
@MainActor
@Observable
final class AppState {
    enum Phase {
        case welcome
        case working(String)  // progress label
        case home(CurrentHousehold)
    }

    var phase: Phase = .welcome
    var errorMessage: String?

    private var didStart = false

    /// Single launch entry point. Restores an existing session if it can be
    /// made usable quickly; otherwise resets to a clean Welcome.
    func start() async {
        guard !didStart else { return }
        didStart = true

        #if DEBUG
        await debugSignInIfRequested()
        #endif

        guard Auth.auth().currentUser != nil else {
            phase = .welcome
            return
        }
        phase = .working(String(localized: "Loading your home…"))
        do {
            let current = try await withTimeout(15) {
                await HouseholdService.getCurrentHousehold()
            }
            if let current {
                phase = .home(current)
            } else {
                // Signed in but no household reachable — a state the
                // skeleton can't serve (no sign-in UI). Clean slate.
                print("[AppState] restored session has no usable household — resetting")
                await resetSession()
                phase = .welcome
            }
        } catch {
            print("[AppState] session restore failed/timed out: \(error) — resetting")
            await resetSession()
            errorMessage = String(
                localized: "We couldn't restore your previous session, so we've reset it. Continue as guest below.")
            phase = .welcome
        }
    }

    /// Guest mode with zero setup (Guideline 5.1.1(v)):
    /// anonymous auth → auto-provisioned household → usable Home.
    /// Anonymous data upgrades in place later via `linkWithCredential`.
    func enterGuestMode() async {
        errorMessage = nil
        phase = .working(String(localized: "Setting things up…"))
        let hadSession = Auth.auth().currentUser != nil
        do {
            if !hadSession {
                try await Auth.auth().signInAnonymously()
            }
            let current = try await withTimeout(20) {
                if let existing = await HouseholdService.getCurrentHousehold() {
                    return existing
                }
                return try await HouseholdService.createHousehold(
                    named: String(localized: "My Household"))
            }
            phase = .home(current)
        } catch {
            print("[AppState] enterGuestMode failed: \(error)")
            // Don't strand a half-provisioned anonymous session.
            if !hadSession { await resetSession() }
            errorMessage = String(
                localized: "Couldn't start guest mode. Please check your connection and try again.")
            phase = .welcome
        }
    }

    /// After a successful sign-in/up/upgrade: load (or auto-provision) the
    /// household and land on Home. Zero-wall philosophy applies to
    /// registered users too — no setup screens.
    func postAuth() async {
        errorMessage = nil
        phase = .working(String(localized: "Loading your home…"))
        do {
            let current = try await withTimeout(30) {
                // A pending email invite takes priority over auto-provisioning
                // a fresh household (invite-acceptance port + key handshake).
                if await MembershipService.checkAndAcceptInvite(),
                   let joined = await HouseholdService.getCurrentHousehold()
                {
                    return joined
                }
                if let existing = await HouseholdService.getCurrentHousehold() {
                    return existing
                }
                return try await HouseholdService.createHousehold(
                    named: String(localized: "My Household"))
            }
            phase = .home(current)
        } catch {
            print("[AppState] postAuth failed: \(error)")
            errorMessage = String(
                localized: "Signed in, but we couldn't load your home. Please try again.")
            phase = .welcome
        }
    }

    /// Explicit sign-out from Home.
    func signOut() async {
        await resetSession()
        errorMessage = nil
        phase = .welcome
    }

    private func resetSession() async {
        try? Auth.auth().signOut()
        await KeyManager.shared.clearKeys()
    }

    #if DEBUG
    /// Sim-only hook: sign in a real account before restore, e.g.
    /// SIMCTL_CHILD_PACELLI_DEBUG_EMAIL / _PASSWORD via `simctl launch`.
    /// Compiled out of Release builds.
    private func debugSignInIfRequested() async {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["PACELLI_DEBUG_EMAIL"],
              let password = env["PACELLI_DEBUG_PASSWORD"]
        else { return }
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            print("[AppState] DEBUG signed in as \(email)")
        } catch {
            print("[AppState] DEBUG sign-in failed: \(error)")
        }
    }
    #endif
}
