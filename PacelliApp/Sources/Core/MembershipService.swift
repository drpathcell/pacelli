import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Household membership: member list, email invites, invite acceptance,
/// member removal. Ports `household_service.dart` (invites section).
///
/// **Key handshake (native improvement over the Flutter app):** Flutter's
/// `shareKeyWithMember` was never called, so invited members joined without
/// the household key and saw "[encrypted]" forever. Here the INVITER wraps
/// the household key for a key derived from the invitee's lowercased email
/// (`deriveUserKey` is a deterministic KDF — same trust model as uid-derived
/// user keys) and stores it on the invite doc (`encrypted_key` — an
/// additive field, harmless to Dart readers). The invite doc is only
/// readable by household members and the invited email (firestore.rules).
/// On acceptance the invitee unwraps it and re-wraps for their own uid into
/// `household_keys`, completing the E2E chain.
enum MembershipService {
    private static var db: Firestore { Firestore.firestore() }
    private static var uid: String? { Auth.auth().currentUser?.uid }

    struct Member: Identifiable, Sendable {
        let id: String  // member doc id: {uid}_{householdId}
        let userId: String
        let role: String
        let joinedAt: Date?
        let displayName: String?
    }

    struct PendingInvite: Identifiable, Sendable {
        let id: String
        let email: String
        let createdAt: Date?
    }

    // MARK: - Members

    /// Members with decrypted display names (profiles join).
    static func fetchMembers(householdId: String) async throws -> [Member] {
        let key = await KeyManager.shared.loadHouseholdKey(householdId)
        let snap = try await db.collection("household_members")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()

        var members: [Member] = []
        for doc in snap.documents {
            let data = doc.data()
            guard let userId = data["user_id"] as? String else { continue }
            var name: String?
            if let profile = try? await db.collection("profiles").document(userId)
                .getDocument().data(),
                let encrypted = profile["full_name"] as? String, !encrypted.isEmpty,
                let key
            {
                name = PacelliCrypto.decryptNullable(encrypted, key: key)
            }
            members.append(
                Member(
                    id: doc.documentID,
                    userId: userId,
                    role: data["role"] as? String ?? "member",
                    joinedAt: DartISO8601.date(from: data["joined_at"] as? String),
                    displayName: name))
        }
        return members.sorted { ($0.joinedAt ?? .distantPast) < ($1.joinedAt ?? .distantPast) }
    }

    /// Mirrors Dart `removeMember` — deterministic doc + legacy sweep.
    static func removeMember(householdId: String, userId: String) async throws {
        let batch = db.batch()
        batch.deleteDocument(
            db.collection("household_members").document("\(userId)_\(householdId)"))
        let legacy = try await db.collection("household_members")
            .whereField("household_id", isEqualTo: householdId)
            .whereField("user_id", isEqualTo: userId)
            .getDocuments()
        for doc in legacy.documents where doc.documentID != "\(userId)_\(householdId)" {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Invites

    /// Mirrors Dart `inviteByEmail`, plus the key handshake (see header).
    static func inviteByEmail(householdId: String, email: String) async throws {
        guard let uid else { throw PacelliError.notSignedIn }
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)

        var doc: [String: Any] = [
            "id": UUID().uuidString.lowercased(),
            "household_id": householdId,
            "invited_email": normalized,
            "invited_by": uid,
            "status": "pending",
            "created_at": DartISO8601.string(from: Date()),
        ]
        if let householdKey = await KeyManager.shared.loadHouseholdKey(householdId) {
            let inviteKey = PacelliCrypto.deriveUserKey(uid: normalized)
            doc["encrypted_key"] = try PacelliCrypto.encryptKeyForUser(
                householdKey, userKey: inviteKey)
        }
        try await db.collection("household_invites")
            .document(doc["id"] as! String).setData(doc)
    }

    static func fetchPendingInvites(householdId: String) async throws -> [PendingInvite] {
        let snap = try await db.collection("household_invites")
            .whereField("household_id", isEqualTo: householdId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        return snap.documents.compactMap { doc in
            let data = doc.data()
            guard let email = data["invited_email"] as? String else { return nil }
            return PendingInvite(
                id: doc.documentID,
                email: email,
                createdAt: DartISO8601.date(from: data["created_at"] as? String))
        }
    }

    static func revokeInvite(_ invite: PendingInvite) async throws {
        try await db.collection("household_invites").document(invite.id).delete()
    }

    /// Port of Dart `checkAndAcceptInvite` + the native key handshake.
    /// Returns true when an invite was accepted (caller should reload).
    /// Safe to call for any signed-in user; no-op without a pending invite.
    static func checkAndAcceptInvite() async -> Bool {
        guard let user = Auth.auth().currentUser, let email = user.email?.lowercased()
        else { return false }
        do {
            let inviteSnap = try await db.collection("household_invites")
                .whereField("invited_email", isEqualTo: email)
                .whereField("status", isEqualTo: "pending")
                .limit(to: 1)
                .getDocuments()
            guard let inviteDoc = inviteSnap.documents.first,
                  let householdId = inviteDoc.data()["household_id"] as? String
            else { return false }

            // Member doc + invite status in one batch (Dart parity).
            let batch = db.batch()
            let member = HouseholdMember(
                userId: user.uid, householdId: householdId, role: "member",
                joinedAt: Date())
            batch.setData(
                member.toMap(),
                forDocument: db.collection("household_members")
                    .document(member.documentID))
            batch.updateData(["status": "accepted"], forDocument: inviteDoc.reference)
            try await batch.commit()

            // Key handshake: unwrap the invite-wrapped key and re-wrap for
            // this uid so decryption works immediately.
            if let wrapped = inviteDoc.data()["encrypted_key"] as? String {
                let inviteKey = PacelliCrypto.deriveUserKey(uid: email)
                if let householdKey = try? PacelliCrypto.decryptKeyForUser(
                    wrapped, userKey: inviteKey)
                {
                    let ownKey = PacelliCrypto.deriveUserKey(uid: user.uid)
                    let rewrapped = try PacelliCrypto.encryptKeyForUser(
                        householdKey, userKey: ownKey)
                    try await db.collection("household_keys").addDocument(data: [
                        "household_id": householdId,
                        "user_id": user.uid,
                        "encrypted_key": rewrapped,
                        "created_at": FieldValue.serverTimestamp(),
                    ])
                    print("[Membership] invite key handshake complete")
                }
            } else {
                print("[Membership] legacy invite without key — content stays encrypted until a member shares the key")
            }
            return true
        } catch {
            print("[Membership] checkAndAcceptInvite failed: \(error)")
            return false
        }
    }
}
