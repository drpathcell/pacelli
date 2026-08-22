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

    var phase: Phase = .welcome {
        didSet {
            // Rebuild reminders whenever we land in a household — foregrounding
            // alone is not enough. `.onChange(of: scenePhase)` in RootView does
            // not fire for the initial `.active` value on a COLD launch, and
            // even when it did fire it ran while `phase` was still `.welcome`,
            // so `reconcileReminders()` bailed on its own guard. Net effect
            // before this: force-quit Pacelli and the pending set was never
            // rebuilt until the next background→foreground round trip.
            // Caught by scripts/check_reminders_e2e.sh, 2026-08-11.
            guard case .home(let current) = phase else { return }
            reminderReconcile?.cancel()
            reminderReconcile = Task { await reconcileReminders() }
            // Re-registered on every landing, not just the first: the token
            // carries household_id, so someone who joins a different
            // household must stop receiving the old one's activity.
            let householdId = current.household.id
            Task { await PushService.register(householdId: householdId) }
            // Backfill the display name. encryptProfileName used to run only
            // in createHousehold, so anyone who JOINED a household could never
            // have a name and showed up as "Member" forever. Idempotent and
            // non-fatal — it no-ops when there is nothing cached.
            Task {
                guard let uid = Auth.auth().currentUser?.uid,
                      let key = await KeyManager.shared.loadHouseholdKey(householdId)
                else { return }
                await HouseholdService.encryptProfileName(uid: uid, householdKey: key)
            }
        }
    }
    var errorMessage: String?

    private var didStart = false
    /// Held so two rapid `.home` assignments can't interleave a `cancelAll`
    /// from one reconcile with the `add` calls of another.
    private var reminderReconcile: Task<Void, Never>?

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
            let outcome = try await withTimeout(15) {
                // An invite can land AFTER this session was created (the common
                // case: install, tap through as guest or sign up, get invited
                // later). postAuth only runs at sign-in, so without this check
                // an already-signed-in user never joins. No-op — and no
                // Firestore round trip — for anonymous sessions.
                let invite = await MembershipService.checkAndAcceptInvite()
                let preferred: String? = if case .joined(let id) = invite { id } else { nil }
                return (
                    invite,
                    await HouseholdService.getCurrentHousehold(preferring: preferred)
                )
            }
            let current = outcome.1
            if case .failed = outcome.0 {
                errorMessage = String(
                    localized:
                        "There's an invite waiting for you, but we couldn't join that household. Ask whoever invited you for a join code instead."
                )
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
            let outcome = try await withTimeout(30) {
                // A pending email invite takes priority over auto-provisioning
                // a fresh household (invite-acceptance port + key handshake).
                let invite = await MembershipService.checkAndAcceptInvite()
                if case .joined(let invitedTo) = invite,
                    let joined = await HouseholdService.getCurrentHousehold(
                        preferring: invitedTo)
                {
                    return (invite, joined)
                }
                if let existing = await HouseholdService.getCurrentHousehold() {
                    return (invite, existing)
                }
                // An invite we KNOW exists but couldn't accept must not be
                // papered over with a fresh empty household — that is exactly
                // how the 1.1.0 failure stayed invisible for a week.
                if case .failed = invite {
                    throw MembershipService.InviteJoinFailed()
                }
                return (
                    invite,
                    try await HouseholdService.createHousehold(
                        named: String(localized: "My Household"))
                )
            }
            if case .failed = outcome.0 {
                errorMessage = String(
                    localized:
                        "There's an invite waiting for you, but we couldn't join that household. Ask whoever invited you for a join code instead."
                )
            }
            phase = .home(outcome.1)
        } catch is MembershipService.InviteJoinFailed {
            print("[AppState] postAuth: invite found but join denied")
            errorMessage = String(
                localized:
                    "You've been invited to a household, but we couldn't join it. Ask whoever invited you for a join code and use “I have a join code” below."
            )
            phase = .welcome
        } catch {
            print("[AppState] postAuth failed: \(error)")
            errorMessage = String(
                localized: "Signed in, but we couldn't load your home. Please try again.")
            phase = .welcome
        }
    }

    /// First-run join: redeem a code with no account and no setup.
    ///
    /// Guest-first (Guideline 5.1.1(v)) applies here too — a joiner should not
    /// have to make an account to accept a household invitation. If there is
    /// no session we sign in anonymously and redeem straight away, and
    /// crucially we do NOT auto-provision a household first, so a joiner never
    /// creates the orphan empty household that used to be left behind.
    func joinWithCode(_ code: String) async -> String? {
        errorMessage = nil
        let hadSession = Auth.auth().currentUser != nil
        phase = .working(String(localized: "Joining…"))
        do {
            if !hadSession { try await Auth.auth().signInAnonymously() }
            let joined = try await withTimeout(25) {
                try await JoinCodeService.join(code: code)
            }
            await discardEmptyHouseholdsAfterJoining(joined)
            await switchToHousehold(joined)
            return joined
        } catch {
            print("[AppState] joinWithCode failed: \(error)")
            // Don't strand a session we only created to redeem a code.
            if !hadSession { await resetSession() }
            errorMessage =
                (error as? JoinCodeService.JoinError)?.errorDescription
                ?? String(localized: "Couldn't join with that code. Check it and try again.")
            phase = .welcome
            return nil
        }
    }

    /// After joining, drop the household this user was parked in if it was
    /// their own auto-provisioned one and is provably empty. Strictly
    /// guarded and non-fatal — see `HouseholdService.discardIfEmpty`.
    private func discardEmptyHouseholdsAfterJoining(_ keep: String) async {
        let discarded = await HouseholdService.discardOwnEmptyHouseholds(except: keep)
        if discarded > 0 {
            print("[AppState] discarded \(discarded) empty household(s) after joining")
        }
    }

    /// Re-write this device's push registration from the current preferences.
    func refreshPushRegistration() async {
        guard case .home(let current) = phase else { return }
        await PushService.register(householdId: current.household.id)
    }

    /// Rebuild pending reminders from the current tasks.
    ///
    /// Local notifications have no idea what the other member did. Without
    /// this, Chloe ticking off "Buy milk" still leaves Juan's phone scheduled
    /// to remind him about it. Called on every foreground.
    /// Finishes any photo this device started and did not send, and clears
    /// local originals whose document has gone.
    ///
    /// Cloud Storage does not queue writes made offline the way Firestore
    /// does, so an upload interrupted by a dead connection or a killed app has
    /// to be picked up again by somebody. That somebody is this, on every
    /// launch and every foreground — and the list it works from is the photo
    /// documents themselves, not a second local queue that could disagree with
    /// them.
    ///
    /// Silent on purpose. A photo waiting to upload is not a problem the user
    /// needs told about; it already shows on the item, and on everyone else's.
    func reconcilePhotos() async {
        guard case .home(let current) = phase else { return }
        let householdId = current.household.id

        await PhotoService.resumePending(householdId: householdId)

        if let live = try? await PhotosRepository.liveIds(householdId: householdId) {
            PhotoStore.reconcile(householdId: householdId, keeping: live)
        }
    }

    func reconcileReminders() async {
        guard case .home(let current) = phase else { return }
        let prefs = ReminderPrefs.current
        guard prefs.enabled else {
            NotificationService.cancelAll()
            return
        }
        guard let tasks = try? await TasksRepository.fetchTasks(
            householdId: current.household.id)
        else { return }
        await NotificationService.reconcile(tasks: tasks, prefs: prefs)
    }

    /// Lands the session in a household the user just joined by code.
    /// Passes `preferring:` explicitly — the joiner usually still holds a
    /// member doc for their own auto-provisioned household, so "most recently
    /// joined" alone would be a coin flip against clock skew.
    func switchToHousehold(_ householdId: String) async {
        phase = .working(String(localized: "Joining…"))
        let joined = try? await withTimeout(20) {
            await HouseholdService.getCurrentHousehold(preferring: householdId)
        }
        if let joined = joined ?? nil {
            phase = .home(joined)
        } else {
            errorMessage = String(
                localized: "You joined, but we couldn't open the household. Try reopening Pacelli.")
            phase = .welcome
        }
    }

    /// Reflects a household rename in the session state so every view
    /// keyed off `phase` (e.g. the Tasks nav title) shows the new name.
    func householdRenamed(to name: String) {
        guard case .home(let current) = phase else { return }
        var household = current.household
        household.name = name
        phase = .home(CurrentHousehold(household: household, role: current.role))
    }

    /// Explicit sign-out from Home.
    func signOut() async {
        await resetSession()
        errorMessage = nil
        phase = .welcome
    }

    private func resetSession() async {
        NotificationService.cancelAll()
        // BEFORE signOut(): the device_tokens rules require
        // `user_id == request.auth.uid`, so deleting the row afterwards is
        // denied and the token lives on — quietly pushing this household's
        // activity to a phone that has signed out of it.
        await PushService.unregister()
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
