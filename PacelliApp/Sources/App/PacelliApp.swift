import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import SwiftUI
import UIKit
import UserNotifications

@main
struct PacelliApp: App {
    // Push needs UIKit callbacks SwiftUI does not expose: the APNs device
    // token arrives on the app delegate, and FCM cannot mint a token until it
    // has been handed that.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }
}

/// Firebase setup plus the two push callbacks that only exist on UIKit.
///
/// Deliberately thin: it wires iOS's plumbing to `PushService` and nothing
/// else. No business logic lives here, because none of it is testable from
/// here.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        // Presentation of foreground notifications and taps.
        UNUserNotificationCenter.current().delegate = self
        // Ask iOS for an APNs token now. This is NOT the permission prompt —
        // that is asked later, by NotificationService, at the moment a
        // notification would first be useful. Registering early only means a
        // token exists when the user does opt in.
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Handing the APNs token to FCM is what lets `Messaging.token()`
        // resolve. Without this line it hangs or returns nil, and every
        // device silently fails to register.
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        // Expected on a simulator without a paired push channel, and on a
        // device with no network. Never fatal — the app works without push.
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }
}

extension AppDelegate: MessagingDelegate {
    /// Fires on first registration and whenever FCM rotates the token.
    ///
    /// A rotated token that is not re-registered means this device quietly
    /// stops receiving anything, with no error anywhere.
    // `nonisolated`: UIApplicationDelegate makes AppDelegate @MainActor, and
    // FCM calls this from its own queue. Without it Swift 6 rejects the
    // conformance outright as a data race.
    nonisolated func messaging(
        _ messaging: Messaging, didReceiveRegistrationToken token: String?
    ) {
        guard token != nil else { return }
        NotificationCenter.default.post(name: .pacelliPushTokenRefreshed, object: nil)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Show household activity even while the app is open — the point is that
    /// the other person did something, which is worth seeing either way.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

extension Notification.Name {
    static let pacelliPushTokenRefreshed = Notification.Name("pacelliPushTokenRefreshed")
}
