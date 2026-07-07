import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn
import UIKit

/// Firebase auth flows. Ports the Flutter semantics:
/// - Anonymous (guest) users UPGRADE in place via `link(with:)`, preserving
///   uid → household membership → wrapped keys. On credential-already-in-use
///   the guest signs into the existing account instead (Dart
///   apple_sign_in_service.dart behaviour).
/// - First sign-in creates `profiles/{uid}` (empty full_name until a
///   household key exists) and caches the display name in the Keychain under
///   `profile_name_{uid}` (signup_screen.dart parity).
enum AuthService {
    private static var db: Firestore { Firestore.firestore() }

    // MARK: - Sign in with Apple

    /// Unhashed nonce for the current SIWA request (hashed copy goes to Apple).
    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let rc = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(rc == errSecSuccess, "SecRandomCopyBytes failed: \(rc)")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Completes SIWA after `SignInWithAppleButton` returns an authorization.
    static func signInWithApple(
        _ authorization: ASAuthorization, rawNonce: String
    ) async throws {
        guard let appleID = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleID.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else { throw AuthError.appleCredentialMissing }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken, rawNonce: rawNonce, fullName: appleID.fullName)

        let displayName = [
            appleID.fullName?.givenName, appleID.fullName?.familyName,
        ].compactMap(\.self).joined(separator: " ")

        try await completeSignIn(with: credential, displayNameHint: displayName)
    }

    // MARK: - Email / password

    static func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        try await ensureProfileDoc(for: result.user, typedName: nil)
    }

    static func signUp(email: String, password: String, name: String) async throws {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await completeSignIn(with: credential, displayNameHint: name, isSignUp: true)
    }

    // MARK: - Google

    /// Presents Google Sign-In, exchanges the tokens for a Firebase credential,
    /// then runs the shared (guest-upgrade-aware) completion. Interactive — the
    /// caller must NOT wrap this in a short deadline.
    @MainActor
    static func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.googleConfigMissing
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = topViewController() else {
            throw AuthError.noPresenter
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.googleCredentialMissing
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken, accessToken: result.user.accessToken.tokenString)

        try await completeSignIn(with: credential, displayNameHint: result.user.profile?.name)
    }

    /// Frontmost view controller to present the Google flow from.
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    // MARK: - Shared completion (guest upgrade aware)

    /// Signs in with `credential` — or, when the current user is an anonymous
    /// guest, LINKS the credential so uid/household/keys are preserved.
    static func completeSignIn(
        with credential: AuthCredential, displayNameHint: String?, isSignUp: Bool = false
    ) async throws {
        let user: User
        if let current = Auth.auth().currentUser, current.isAnonymous {
            do {
                user = try await current.link(with: credential).user
            } catch let error as NSError
                where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue
                || error.code == AuthErrorCode.emailAlreadyInUse.rawValue
            {
                if isSignUp {
                    // Creating a NEW account over a guest session with an
                    // email that already exists is a user mistake — surface
                    // it rather than silently signing into another account.
                    throw error
                }
                // Existing-account sign-in from a guest session: the guest
                // data is abandoned (Dart parity).
                if let updated = (error.userInfo[AuthErrorUserInfoUpdatedCredentialKey]
                    as? AuthCredential)
                {
                    user = try await Auth.auth().signIn(with: updated).user
                } else {
                    user = try await Auth.auth().signIn(with: credential).user
                }
            }
        } else {
            user = try await Auth.auth().signIn(with: credential).user
        }
        try await ensureProfileDoc(for: user, typedName: displayNameHint)
    }

    /// signup_screen.dart parity: create `profiles/{uid}` if missing and
    /// cache the display name locally for household-join encryption.
    static func ensureProfileDoc(for user: User, typedName: String?) async throws {
        let name = (typedName?.isEmpty == false ? typedName : user.displayName) ?? ""
        if !name.isEmpty {
            SecureStore.write("profile_name_\(user.uid)", value: name)
        }
        let ref = db.collection("profiles").document(user.uid)
        let snap = try await ref.getDocument()
        guard !snap.exists else { return }
        try await ref.setData([
            "full_name": "",  // Encrypted later, once a household key exists
            "avatar_url": user.photoURL?.absoluteString ?? "",
            "updated_at": FieldValue.serverTimestamp(),
        ])
    }

    static func signOut() throws {
        try Auth.auth().signOut()
    }
}

enum AuthError: LocalizedError {
    case appleCredentialMissing
    case googleConfigMissing
    case googleCredentialMissing
    case noPresenter

    var errorDescription: String? {
        switch self {
        case .appleCredentialMissing:
            String(localized: "Apple didn't return a valid credential. Please try again.")
        case .googleConfigMissing:
            String(localized: "Google Sign-In isn't configured. Please try another method.")
        case .googleCredentialMissing:
            String(localized: "Google didn't return a valid credential. Please try again.")
        case .noPresenter:
            String(localized: "Couldn't open Google Sign-In right now. Please try again.")
        }
    }
}
