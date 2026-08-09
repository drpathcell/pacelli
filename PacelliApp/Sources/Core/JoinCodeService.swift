import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Household join codes — the provider-agnostic way into a household.
///
/// **Why this exists:** email-addressed invites (`MembershipService`) match on
/// `request.auth.token.email`. For Sign in with Apple with "Hide My Email"
/// that token carries an `@privaterelay.appleid.com` address that the inviter
/// has no way of knowing, so an invite sent to the person's real address can
/// never match. A join code inverts the direction — the household publishes a
/// short bearer secret, the joiner types it — which works for every auth
/// provider and in any sign-up order.
///
/// **Trust model:** the code IS the secret. It is the document ID (never in
/// the body), and the household key is wrapped for a key derived from it, so
/// holding the code is exactly what grants access — the same model as a
/// share link. Security rules allow `get` by exact ID (bearer lookup) but
/// restrict `list` to household members, so guessing costs one read per
/// attempt against ~39 bits. Expiry is enforced server-side in the rules,
/// not just here, so a stale screenshot is dead even against a patched client.
enum JoinCodeService {
    private static var db: Firestore { Firestore.firestore() }
    private static var uid: String? { Auth.auth().currentUser?.uid }

    /// Codes live 7 days; the rules independently cap this at 8.
    static let lifetime: TimeInterval = 7 * 24 * 60 * 60

    /// Unambiguous alphabet — no I/L/O/U/0/1, so a code read aloud or copied
    /// off a screen can't be mistyped into a different valid code.
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTVWXYZ23456789")
    private static let length = 8

    /// Namespaced so a code can never collide with a uid- or email-derived key.
    private static func keyMaterial(for code: String) -> String { "joincode:\(code)" }

    struct JoinCode: Sendable {
        let code: String
        let householdId: String
        let expiresAt: Date

        var isExpired: Bool { expiresAt <= Date() }

        /// `K7QP-4M2X` — grouped for reading aloud, never for storage.
        var formatted: String {
            guard code.count == length else { return code }
            let mid = code.index(code.startIndex, offsetBy: length / 2)
            return "\(code[code.startIndex..<mid])-\(code[mid...])"
        }
    }

    /// Accepts `k7qp-4m2x`, `K7QP 4M2X`, ` K7QP4M2X ` — all the same code.
    static func normalize(_ input: String) -> String {
        String(input.uppercased().filter { alphabet.contains($0) })
    }

    private static func generateCode() -> String {
        String((0..<length).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
    }

    // MARK: - Household side

    /// The household's current code, expired or not (members only — this is a
    /// `list`, which the rules restrict to members). Returning expired codes
    /// deliberately: the UI needs to say "expired, tap to regenerate" rather
    /// than silently showing nothing.
    static func currentCode(householdId: String) async throws -> JoinCode? {
        let snap = try await db.collection("household_join_codes")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()
        let codes = snap.documents.compactMap { doc -> JoinCode? in
            guard let expires = (doc.data()["expires_at"] as? Timestamp)?.dateValue()
            else { return nil }
            return JoinCode(
                code: doc.documentID, householdId: householdId, expiresAt: expires)
        }
        return codes.max { $0.expiresAt < $1.expiresAt }
    }

    /// Issues a fresh code and revokes every older one for this household, so
    /// "regenerate" genuinely invalidates what was shared before.
    @discardableResult
    static func regenerate(householdId: String) async throws -> JoinCode {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let householdKey = await KeyManager.shared.loadHouseholdKey(householdId)
        else { throw PacelliError.missingHouseholdKey }

        let code = generateCode()
        let expiresAt = Date().addingTimeInterval(lifetime)
        let wrapped = try PacelliCrypto.encryptKeyForUser(
            householdKey, userKey: PacelliCrypto.deriveUserKey(uid: keyMaterial(for: code)))

        try await db.collection("household_join_codes").document(code).setData([
            "household_id": householdId,
            "encrypted_key": wrapped,
            "created_by": uid,
            "created_at": FieldValue.serverTimestamp(),
            "expires_at": Timestamp(date: expiresAt),
        ])
        try await revokeAll(householdId: householdId, except: code)
        return JoinCode(code: code, householdId: householdId, expiresAt: expiresAt)
    }

    /// Revokes every code for the household (optionally keeping one).
    static func revokeAll(householdId: String, except keep: String? = nil) async throws {
        let snap = try await db.collection("household_join_codes")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()
        let stale = snap.documents.filter { $0.documentID != keep }
        guard !stale.isEmpty else { return }
        let batch = db.batch()
        for doc in stale { batch.deleteDocument(doc.reference) }
        try await batch.commit()
    }

    // MARK: - Joiner side

    enum JoinError: LocalizedError {
        case notFound
        case alreadyMember
        case keyUnwrapFailed

        var errorDescription: String? {
            switch self {
            case .notFound:
                String(
                    localized:
                        "That code isn't valid any more. Ask for a new one — codes expire after 7 days."
                )
            case .alreadyMember:
                String(localized: "You're already a member of that household.")
            case .keyUnwrapFailed:
                String(
                    localized:
                        "That code didn't unlock the household. Ask for a freshly generated one.")
            }
        }
    }

    /// Redeems a code: member doc + this user's re-wrapped household key in one
    /// batch. Both writes are self-authorised (`user_id == request.auth.uid`),
    /// so unlike the email-invite batch neither depends on a membership the
    /// same batch is creating — see firestore.rules.
    /// Returns the joined household id.
    @discardableResult
    static func join(code rawCode: String) async throws -> String {
        guard let user = Auth.auth().currentUser else { throw PacelliError.notSignedIn }
        let code = normalize(rawCode)
        guard code.count == length else { throw JoinError.notFound }

        // A `get` by exact ID — the rules reject expired codes server-side, so
        // an expired code is indistinguishable from a wrong one here.
        let doc = try? await db.collection("household_join_codes").document(code).getDocument()
        guard let data = doc?.data(),
            let householdId = data["household_id"] as? String,
            let wrapped = data["encrypted_key"] as? String
        else { throw JoinError.notFound }

        let existing = try await db.collection("household_members")
            .document("\(user.uid)_\(householdId)").getDocument()
        if existing.exists { throw JoinError.alreadyMember }

        guard
            let householdKey = try? PacelliCrypto.decryptKeyForUser(
                wrapped, userKey: PacelliCrypto.deriveUserKey(uid: keyMaterial(for: code)))
        else { throw JoinError.keyUnwrapFailed }

        let member = HouseholdMember(
            userId: user.uid, householdId: householdId, role: "member", joinedAt: Date())
        let rewrapped = try PacelliCrypto.encryptKeyForUser(
            householdKey, userKey: PacelliCrypto.deriveUserKey(uid: user.uid))

        let batch = db.batch()
        batch.setData(
            member.toMap(),
            forDocument: db.collection("household_members").document(member.documentID))
        batch.setData(
            [
                "household_id": householdId,
                "user_id": user.uid,
                "encrypted_key": rewrapped,
                "created_at": FieldValue.serverTimestamp(),
            ], forDocument: db.collection("household_keys").document())
        try await batch.commit()

        await KeyManager.shared.adoptHouseholdKey(householdKey, for: householdId)
        print("[JoinCode] joined \(householdId) via code")
        return householdId
    }
}
