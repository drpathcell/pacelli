import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import PacelliKit
import UIKit

/// Push registration and the device-token lifecycle.
///
/// Local reminders (``NotificationService``) tell you about *your own* tasks.
/// Push exists for the one thing a device cannot know on its own: that the
/// OTHER person did something. Nothing else belongs here.
///
/// The server never learns anything it did not already hold. A notification
/// body is generic — the encrypted title rides along in the payload for the
/// Notification Service Extension to open on device (Phase C). Until that
/// extension exists the generic body is simply what the user sees, which is
/// the same thing that happens whenever decryption fails. Degrading to the
/// privacy-safe text is the design, not a stopgap.
enum PushService {

    private static var db: Firestore { Firestore.firestore() }

    /// Per-device, like the reminder settings — a phone gets notified, not a
    /// household. Default OFF: two people sharing one list generate constant
    /// "new task added" traffic, and an opt-out notification stream is how an
    /// app teaches people to ignore it.
    static let storageActivityPush = "push_activity_enabled"

    static var activityPushEnabled: Bool {
        UserDefaults.standard.bool(forKey: storageActivityPush)
    }

    /// The Firestore doc id is the FCM token itself, so re-registering the
    /// same token overwrites rather than accumulating rows.
    private static func ref(_ token: String) -> DocumentReference {
        db.collection("device_tokens").document(token)
    }

    /// Remembered so sign-out and burn can delete the exact row they created.
    /// `Messaging.token()` can fail or change at precisely the moment we most
    /// need it (signing out, wiping), and a token we cannot name is a token we
    /// cannot revoke — it would keep pushing a household's activity to a phone
    /// that has left it.
    private static let lastTokenKey = "push_last_registered_token"

    // MARK: - Registration

    /// Ask iOS for a device token. Safe to call repeatedly.
    ///
    /// Deliberately does NOT request authorisation — ``NotificationService``
    /// owns that, and asks at the moment a notification would first be useful.
    /// Registering without authorisation is fine: iOS still issues a token,
    /// and it is what lets a later opt-in work without another round trip.
    @MainActor
    static func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Store the token against the signed-in user and their household.
    ///
    /// Called on launch, on token refresh, and whenever the household changes
    /// — the household id is denormalised onto the row so a Cloud Function can
    /// find "everyone in this household except the author" with one query.
    static func register(householdId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let token = try? await Messaging.messaging().token() else { return }

        // A token that moves to a different household must not keep receiving
        // the old one's activity. Same row, overwritten, not a second row.
        let payload: [String: Any] = [
            "token": token,
            "user_id": uid,
            "household_id": householdId,
            "platform": "ios",
            // On the row, not just in the UI: the decision has to reach the
            // sender. A toggle that only hides things locally is a control
            // that does nothing, and the phone still gets woken up.
            "activity_push": activityPushEnabled,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                ?? "?",
            "updated_at": DartISO8601.string(from: Date()),
        ]
        do {
            try await ref(token).setData(payload, merge: true)
            UserDefaults.standard.set(token, forKey: lastTokenKey)
        } catch {
            // Never fatal: failing to register for push must not stop someone
            // using the app.
            print("[PushService] register failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Revocation

    /// Delete this device's token. Call on sign-out and on burn.
    ///
    /// Best-effort by necessity — the row is deleted while the user is still
    /// authenticated, because the rules require `user_id == request.auth.uid`.
    /// Doing it after `signOut()` would be denied, which is exactly the kind of
    /// failure that leaves a stale token pushing forever.
    static func unregister() async {
        let stored = UserDefaults.standard.string(forKey: lastTokenKey)
        let current = try? await Messaging.messaging().token()
        // Both, deduplicated: the token may have rotated since registration,
        // in which case the stored one is the row that actually exists.
        for token in Set([stored, current].compactMap { $0 }) {
            try? await ref(token).delete()
        }
        UserDefaults.standard.removeObject(forKey: lastTokenKey)
        // Drops the FCM registration itself, so this device stops being a
        // valid target even if the Firestore delete failed.
        try? await Messaging.messaging().deleteToken()
    }

    /// Delete EVERY token this user has, on every device. For burn only.
    ///
    /// Signing out of one phone should not silence another — that is what
    /// ``unregister()`` is for. Burning the account should silence all of
    /// them, and burn is the case where a missed token means a wiped account
    /// still buzzing on a device nobody is looking at.
    ///
    /// Must run while still authenticated: the rules scope both the query and
    /// the delete to `user_id == request.auth.uid`.
    static func unregisterAllDevices() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard
            let snap = try? await db.collection("device_tokens")
                .whereField("user_id", isEqualTo: uid)
                .getDocuments()
        else {
            await unregister()  // fall back to at least this device
            return
        }
        for d in snap.documents { try? await d.reference.delete() }
        UserDefaults.standard.removeObject(forKey: lastTokenKey)
        try? await Messaging.messaging().deleteToken()
    }
}
