import FirebaseAuth
import Foundation
import Observation
import PacelliKit

/// Session state machine: welcome → working → home.
/// `enterGuestMode()` is the 5.1.1(v) invariant — port of
/// `lib/features/auth/presentation/utils/guest_session.dart`.
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

    /// Guest mode with zero setup:
    /// 1. Anonymous auth (no personal data).
    /// 2. Auto-provision a default household when none exists.
    /// 3. Land on a usable Home — no walls.
    /// Anonymous data upgrades in place later via `linkWithCredential`.
    func enterGuestMode() async {
        errorMessage = nil
        phase = .working(String(localized: "Setting things up…"))
        do {
            if Auth.auth().currentUser == nil {
                try await Auth.auth().signInAnonymously()
            }
            let current: CurrentHousehold
            if let existing = await HouseholdService.getCurrentHousehold() {
                current = existing
            } else {
                current = try await HouseholdService.createHousehold(
                    named: String(localized: "My Household"))
            }
            phase = .home(current)
        } catch {
            print("[AppState] enterGuestMode failed: \(error)")
            errorMessage = String(
                localized: "Couldn't start guest mode. Please check your connection and try again.")
            phase = .welcome
        }
    }

    /// Restores an existing session (guest or registered) on launch.
    func restoreSession() async {
        guard Auth.auth().currentUser != nil else { return }
        phase = .working(String(localized: "Loading your home…"))
        if let existing = await HouseholdService.getCurrentHousehold() {
            phase = .home(existing)
        } else {
            phase = .welcome
        }
    }
}
