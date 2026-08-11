import PacelliKit
import UserNotifications

/// Turns "A new task was added to your household" into "Buy milk".
///
/// The server cannot do this: Pacelli is end-to-end encrypted and the
/// household key never leaves the members' devices. So the Cloud Function
/// copies the already-encrypted title into the payload as `enc_title`, and
/// this extension — which shares the app's keychain access group — opens it
/// here, on the recipient's own device, microseconds before iOS draws it.
///
/// **Every failure path shows the generic body the payload arrived with.**
/// No key cached yet, a payload from an older build, a corrupt ciphertext, the
/// ~30-second budget running out: all of them fall through to text that leaks
/// nothing. That is the property that makes shipping this safe, and it is
/// worth more than any individual decryption succeeding.
final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let content = request.content.mutableCopy() as? UNMutableNotificationContent
        bestAttempt = content

        guard let content else {
            contentHandler(request.content)
            return
        }

        // Deliver the generic body unless every step below succeeds.
        defer { contentHandler(content) }

        let info = request.content.userInfo
        guard let encTitle = info["enc_title"] as? String, !encTitle.isEmpty,
            let householdId = info["household_id"] as? String
        else { return }

        // Keychain only. The extension deliberately has no Firestore client:
        // a network fetch inside a 30-second budget would sometimes work and
        // sometimes not, which is worse than consistently showing the generic
        // body. The app re-populates this cache on every foreground.
        guard let key = SecureStore.read("hk_\(householdId)") else { return }

        // Same PacelliCrypto the app uses — linked from the shared package
        // rather than reimplemented, so there is exactly one AES
        // implementation in the product and the cross-language vectors cover
        // this path too.
        guard let title = try? PacelliCrypto.decrypt(encTitle, key: key),
            !title.isEmpty
        else { return }

        content.body = title
    }

    /// iOS is about to run out of patience. Hand back whatever we have —
    /// which, if decryption has not finished, is still the generic body.
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttempt {
            contentHandler(bestAttempt)
        }
    }
}
