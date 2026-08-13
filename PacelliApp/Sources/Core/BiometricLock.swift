import Foundation
import LocalAuthentication
import Observation

/// Face ID / passcode gate on the app itself.
///
/// ## Why this is not a keychain access-control flag
///
/// The obvious implementation is `kSecAccessControl` with `.biometryCurrentSet`
/// on the household key, so the key cannot leave the Keychain without a face.
/// That would break push notifications outright.
///
/// Since 1.4.0 the notification service extension reads `hk_<householdId>` to
/// decrypt a push title, and it runs headless in the background with no UI and
/// no user present. `SecItemCopyMatching` on an item guarded by user presence
/// returns `errSecInteractionNotAllowed` there — every time, not sometimes. The
/// cost of keychain-level gating is therefore that every notification silently
/// reverts to "A new task was added to your household", permanently, which is
/// the entire feature 1.4.0 shipped.
///
/// So the gate is on the app, and the key keeps
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
///
/// ## What that buys, honestly
///
/// It stops a person holding your unlocked phone from reading the household —
/// a guest, a child, a repair counter. That is the realistic threat for a
/// family app and it is the one this closes.
///
/// It does NOT protect the key from anyone who can extract the Keychain
/// itself: forensic tooling, a jailbreak, a device backup attack. The key is
/// still readable by this app's own process without user presence, because the
/// extension needs exactly that. Anyone reading this later looking for
/// at-rest-under-duress protection: it is not here, and adding it costs
/// decrypted notifications.
@MainActor
@Observable
final class BiometricLock {

    /// Opt-in. Default off, and it stays off on any device that cannot
    /// evaluate the policy — see `isAvailable`.
    static let enabledKey = "pacelli.biometricLock.enabled"

    private(set) var isLocked = false
    private(set) var lastError: String?

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// True when the device can actually challenge the user.
    ///
    /// `deviceOwnerAuthentication` — not `...WithBiometrics` — so a device with
    /// no enrolled face or fingerprint falls back to the passcode instead of
    /// being unable to unlock. A device with no passcode at all cannot
    /// evaluate anything, and there the toggle must not be offerable: enabling
    /// it would lock the household away with no way back in.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Human name for the hardware, for the Settings row.
    static var biometryLabel: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "your passcode"
        }
    }

    /// Called when the app leaves the foreground.
    ///
    /// Locks immediately rather than after a grace period. A grace period is
    /// the friendlier choice and the wrong one here: the threat is somebody
    /// picking up the unlocked phone you just put down, which is exactly the
    /// window a grace period leaves open.
    func lockIfEnabled() {
        guard isEnabled, Self.isAvailable else {
            isLocked = false
            return
        }
        isLocked = true
    }

    /// Challenge the user. Safe to call repeatedly; a failure leaves the app
    /// locked and retryable rather than stranded.
    func unlock() async {
        guard isLocked else { return }

        // A fresh context per attempt. Reusing one lets iOS reply from a
        // cached successful evaluation, which would turn "unlock" into a
        // no-op after the first success of the session.
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"

        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            // Biometry was available when the toggle was set and is not now —
            // passcode removed, device restored. Refusing to unlock here would
            // lock the household away for good, so the gate yields. It is a
            // convenience lock, and it must never become a data-loss event.
            lastError = nil
            isLocked = false
            return
        }

        do {
            let ok = try await ctx.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Pacelli to see your household."
            )
            if ok {
                isLocked = false
                lastError = nil
            }
        } catch let error as LAError where error.code == .userCancel
            || error.code == .appCancel || error.code == .systemCancel
        {
            // Cancelling is a choice, not a failure. Stay locked, say nothing.
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Turning the lock off requires passing it once, so that someone who has
    /// picked up an unlocked phone cannot simply switch it off in Settings.
    func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            guard Self.isAvailable else { return false }
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
            return true
        }

        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            return true
        }
        let ok = (try? await ctx.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Turn off the Pacelli lock."
        )) ?? false
        if ok { UserDefaults.standard.set(false, forKey: Self.enabledKey) }
        return ok
    }
}
