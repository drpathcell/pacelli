import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Manages per-household encryption keys.
/// Port of `lib/core/crypto/key_manager.dart` — same Firestore collection
/// (`household_keys`: household_id, user_id, encrypted_key, created_at),
/// same local cache key (`hk_<householdId>`), same v1→v2 rewrap-on-read.
actor KeyManager {
    static let shared = KeyManager()

    private var cachedKey: String?
    private var cachedHouseholdId: String?

    private var db: Firestore { Firestore.firestore() }
    private var uid: String? { Auth.auth().currentUser?.uid }

    /// The decrypted household key for `householdId`, or nil if unavailable.
    func loadHouseholdKey(_ householdId: String) async -> String? {
        guard let uid else { return nil }
        if cachedHouseholdId == householdId, let cachedKey { return cachedKey }

        // Local secure storage first (faster, works offline).
        if let local = SecureStore.read("hk_\(householdId)") {
            cachedKey = local
            cachedHouseholdId = householdId
            // Opportunistic: an install that predates the shared access group
            // holds this key where the notification extension cannot see it,
            // so its pushes show the generic body forever until it moves.
            // Cheap, idempotent, and a failure costs nothing but that.
            SecureStore.migrateToAccessGroup("hk_\(householdId)")
            return local
        }

        do {
            let snap = try await db.collection("household_keys")
                .whereField("household_id", isEqualTo: householdId)
                .whereField("user_id", isEqualTo: uid)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first,
                  let encryptedKey = doc.data()["encrypted_key"] as? String
            else { return nil }

            let decrypted = try PacelliCrypto.decryptKeyWithMigration(
                encryptedKey: encryptedKey, uid: uid)

            // If v1 wrapping was used, silently migrate to v2 (parity with Dart).
            let v2Key = PacelliCrypto.deriveUserKey(uid: uid)
            if (try? PacelliCrypto.decrypt(encryptedKey, key: v2Key)) == nil {
                if let rewrapped = try? PacelliCrypto.encryptKeyForUser(
                    decrypted, userKey: v2Key)
                {
                    try? await doc.reference.updateData(["encrypted_key": rewrapped])
                }
            }

            cachedKey = decrypted
            cachedHouseholdId = householdId
            SecureStore.write("hk_\(householdId)", value: decrypted)
            return decrypted
        } catch {
            return nil
        }
    }

    /// Generates + stores a new household key wrapped for the current user.
    /// Returns the plaintext key.
    func createHouseholdKey(_ householdId: String) async throws -> String {
        guard let uid else { throw PacelliError.notSignedIn }

        let householdKey = PacelliCrypto.generateHouseholdKey()
        let userKey = PacelliCrypto.deriveUserKey(uid: uid)
        let encryptedKey = try PacelliCrypto.encryptKeyForUser(householdKey, userKey: userKey)

        print("[KeyManager] writing household_keys doc for \(householdId)…")
        try await db.collection("household_keys").addDocument(data: [
            "household_id": householdId,
            "user_id": uid,
            "encrypted_key": encryptedKey,
            "created_at": FieldValue.serverTimestamp(),
        ])
        print("[KeyManager] household_keys doc written")

        cachedKey = householdKey
        cachedHouseholdId = householdId
        SecureStore.write("hk_\(householdId)", value: householdKey)
        return householdKey
    }

    /// Caches a household key obtained out of band (join-code redemption),
    /// so the first screen after joining decrypts without a Firestore round
    /// trip against a key doc that may not have propagated yet.
    func adoptHouseholdKey(_ key: String, for householdId: String) {
        cachedKey = key
        cachedHouseholdId = householdId
        SecureStore.write("hk_\(householdId)", value: key)
    }

    /// The currently-cached key (nil until a load/create succeeds).
    var householdKey: String? { cachedKey }

    /// Clears in-memory and Keychain caches (sign-out / burn).
    func clearKeys() {
        cachedKey = nil
        cachedHouseholdId = nil
        SecureStore.deleteAll()
    }

    /// Deletes this user's wrapped-key doc(s) for a household (burn).
    /// Mirrors Dart `deleteKeyFromFirestore` — non-fatal on failure.
    func deleteKeyFromFirestore(_ householdId: String) async {
        guard let uid else { return }
        do {
            let snap = try await db.collection("household_keys")
                .whereField("household_id", isEqualTo: householdId)
                .whereField("user_id", isEqualTo: uid)
                .getDocuments()
            for doc in snap.documents {
                try await doc.reference.delete()
            }
            print("[KeyManager] deleted key doc(s) for \(householdId)")
        } catch {
            print("[KeyManager] deleteKeyFromFirestore failed: \(error)")
        }
    }
}

enum PacelliError: Error {
    case notSignedIn
    case missingHouseholdKey
}
