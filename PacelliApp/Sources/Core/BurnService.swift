import FirebaseAuth
import FirebaseFirestore
import Foundation
import GoogleSignIn
import PacelliKit

/// "Burn all data" — full data wipe. Port of the Dart
/// `wipeAllData`/`_wipeHouseholdData` (firebase_data_repository.dart) plus
/// the burn screen's local-cleanup steps.
///
/// Audit contract (pacelli-security-audit §Phase 5):
/// - delete ALL Firestore docs, batched ≤400, retried with backoff
/// - member doc + household doc deleted LAST (isMember() must hold for
///   every earlier batch)
/// - orphan sweep against the SERVER (cache can mask stragglers)
/// - verify deletion server-side; fail loudly, never fake success
/// - Keychain + prefs + Firestore persistence cleared; account deleted
///   (re-auth handled by the caller when Firebase demands it)
///
/// Not ported (not built natively yet): notification cancellation, local
/// SQLite deletion — both no-ops in this app today.
enum BurnService {
    private static var db: Firestore { Firestore.firestore() }

    enum BurnError: LocalizedError {
        case notSignedIn
        case verificationFailed(surviving: Int)
        case needsRecentLogin

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                String(localized: "You're not signed in.")
            case .verificationFailed(let surviving):
                String(
                    localized:
                    "Deletion verification found \(surviving) surviving record(s). Nothing has been hidden — please retry.")
            case .needsRecentLogin:
                String(localized: "Deleting your account needs a recent sign-in. Please confirm your identity.")
            }
        }
    }

    /// Firestore wipe + server-side verification. Throws on any failure.
    static func wipeFirestoreData(log: @escaping @MainActor (String) -> Void) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw BurnError.notSignedIn }
        await log("Finding your households…")

        let memberSnap = try await db.collection("household_members")
            .whereField("user_id", isEqualTo: uid)
            .getDocuments()
        let householdIds = Set(
            memberSnap.documents.compactMap { $0.data()["household_id"] as? String }
                .filter { !$0.isEmpty })
        await log("Found \(householdIds.count) household(s)")

        for householdId in householdIds {
            // Drive config FIRST — its rule needs the member doc to still exist.
            try? await db.collection("household_drive_config")
                .document(householdId).delete()
            try await wipeHousehold(householdId, uid: uid, log: log)
        }

        // Orphan sweep — SERVER source; the local cache can show stale
        // zero-doc results after the batch deletes.
        let orphanSnap = try await db.collection("household_members")
            .whereField("user_id", isEqualTo: uid)
            .getDocuments(source: .server)
        if !orphanSnap.documents.isEmpty {
            await log("Orphan sweep: \(orphanSnap.documents.count) surviving doc(s)")
            try await commitWithRetry(
                orphanSnap.documents.map(\.reference), label: "orphan sweep", log: log)
        }

        await log("Deleting your profile…")
        try? await db.collection("profiles").document(uid).delete()

        await log("Removing encryption keys…")
        for householdId in householdIds {
            await KeyManager.shared.deleteKeyFromFirestore(householdId)
        }
        await KeyManager.shared.clearKeys()

        // Verification — the audit's "never fake success" rule. Server source.
        let verify = try await db.collection("household_members")
            .whereField("user_id", isEqualTo: uid)
            .getDocuments(source: .server)
        guard verify.documents.isEmpty else {
            throw BurnError.verificationFailed(surviving: verify.documents.count)
        }
        await log("Verified: no household records remain")
    }

    /// All household-scoped docs; own member doc + household doc LAST.
    private static func wipeHousehold(
        _ householdId: String, uid: String, log: @escaping @MainActor (String) -> Void
    ) async throws {
        var refs: [DocumentReference] = []

        // Same collection list as Dart _wipeHouseholdData (order irrelevant
        // within the batches; membership doc survives until the final batch).
        // Single source of truth, shared with HouseholdService.discardOwnEmptyHouseholds:
        // "what burn deletes" and "what makes a household non-empty" must never
        // drift apart, or a household could be discarded while still holding data.
        let collections =
            HouseholdService.householdContentCollections
            + ["household_invites", "household_join_codes"]
        for collection in collections {
            let snap = try await db.collection(collection)
                .whereField("household_id", isEqualTo: householdId)
                .getDocuments()
            if !snap.documents.isEmpty {
                await log("\(collection): \(snap.documents.count) record(s)")
            }
            refs.append(contentsOf: snap.documents.map(\.reference))
        }

        // Other members' docs — OWNER ONLY. Removing other people became an
        // owner action in the 2026-08-24 rules change, and it always should
        // have been: someone deleting their own account has no business
        // evicting the household's other people on the way out. Ask the
        // household doc, never the member row's `role` — that field is written
        // by the client, so it is a claim, not a fact.
        let ownMemberDocID = "\(uid)_\(householdId)"
        let householdDoc = try? await db.collection("households")
            .document(householdId).getDocument()
        let isOwner = (householdDoc?.data()?["created_by"] as? String) == uid

        let members = try await db.collection("household_members")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()
        let otherMembers = members.documents.filter { $0.documentID != ownMemberDocID }
        if isOwner {
            refs.append(contentsOf: otherMembers.map(\.reference))
        } else if !otherMembers.isEmpty {
            await log("Leaving \(otherMembers.count) other membership(s) in place")
        }

        // Batched deletes, ≤400 per batch, ×3 retry with backoff.
        await log("Deleting \(refs.count) record(s)…")
        for (i, chunk) in refs.chunked(into: 400).enumerated() {
            try await commitWithRetry(chunk, label: "batch \(i + 1)", log: log)
        }

        // FINAL batch: own member doc + household doc — last, so isMember()
        // held for everything above. The household doc goes only when nobody
        // is left in it. Deleting it out from under surviving members is
        // precisely the orphan state the sweep above exists to clean up, and
        // a non-owner can no longer remove those members to avoid it.
        var finalRefs = [db.collection("household_members").document(ownMemberDocID)]
        if isOwner || otherMembers.isEmpty {
            finalRefs.append(db.collection("households").document(householdId))
        } else {
            await log("Household kept — other members remain")
        }
        try await commitWithRetry(
            finalRefs, label: "final (membership + household)", log: log)
    }

    private static func commitWithRetry(
        _ refs: [DocumentReference], label: String, log: @escaping @MainActor (String) -> Void,
        maxRetries: Int = 3
    ) async throws {
        var attempt = 1
        while true {
            do {
                let batch = db.batch()
                for ref in refs { batch.deleteDocument(ref) }
                try await batch.commit()
                return
            } catch {
                await log("\(label) attempt \(attempt) failed: \(error.localizedDescription)")
                guard attempt < maxRetries else { throw error }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                attempt += 1
            }
        }
    }

    // MARK: - Local cleanup + account

    /// Deletes the Firebase Auth account. Throws `needsRecentLogin` when
    /// Firebase demands re-auth — the caller re-authenticates and retries.
    static func deleteAccount(log: @escaping @MainActor (String) -> Void) async throws {
        guard let user = Auth.auth().currentUser else { throw BurnError.notSignedIn }
        do {
            try await user.delete()
            await log("Account deleted")
        } catch let error as NSError
            where error.code == AuthErrorCode.requiresRecentLogin.rawValue
        {
            throw BurnError.needsRecentLogin
        }
    }

    /// Keychain, Google session, Firestore persistence, app preferences.
    /// Sign-out is implicit when the account was just deleted; called
    /// defensively anyway.
    static func clearLocalState(log: @escaping @MainActor (String) -> Void) async {
        // Before anything else: pending reminders carry real task titles, so a
        // burned account that keeps buzzing would leak the very content the
        // wipe was meant to destroy.
        NotificationService.cancelAll()
        await log("Pending reminders cancelled")

        // Also while still signed in — the rules key deletion to
        // `user_id == request.auth.uid`, so a token deleted after signOut()
        // is a token that never gets deleted. A wiped account that keeps
        // buzzing is the exact failure a burn is supposed to prevent.
        await PushService.unregisterAllDevices()
        await log("Push tokens revoked on all devices")

        // The plaintext originals. Every other store in this wipe holds
        // ciphertext; this one holds readable pictures, so leaving it would be
        // the single worst thing a burn could miss. The encrypted objects in
        // Cloud Storage are already gone — deleting the `photos` documents took
        // them, through onPhotoDeleted.
        PhotoStore.deleteEverything()
        await log("Photos removed from this device")

        await KeyManager.shared.clearKeys()
        await log("Keychain cleared")

        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()

        do {
            try await db.clearPersistence()
            await log("Offline cache cleared")
        } catch {
            await log("Offline cache: \(error.localizedDescription)")
        }

        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("pacelli_") {
            defaults.removeObject(forKey: key)
        }
        await log("Preferences cleared")
    }
}

extension Array {
    fileprivate func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
