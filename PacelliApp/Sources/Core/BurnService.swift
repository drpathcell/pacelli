import FirebaseAuth
import FirebaseFirestore
import Foundation
import GoogleSignIn
import PacelliKit

/// Deleting your account, and burning the household's data.
///
/// **These were one button until 1.10.0 and they are now two operations, for a
/// reason that is not cosmetic.** App Store Guideline 5.1.1(v) requires in-app
/// account deletion — it is why guest mode and burn exist at all, after the 1.0
/// rejection — so it can never be gated. Wiping what the household SHARES is a
/// different act, affecting people who are not in the room, and the household
/// owner now controls who may do it.
///
/// So the split is:
///
///   - `deleteMyAccountData` — this file, client-side, ungateable. The
///     caller's membership, profile, keys and tokens. It touches shared
///     content in exactly one case: when the caller is the last member, where
///     "shared" no longer means anything and leaving the data would be
///     abandoning it, not protecting anyone.
///   - `burnHouseholdData` — a call to the `burnHousehold` Cloud Function,
///     which checks the household's `burn_permission` itself. Not enforced in
///     `firestore.rules`, and it cannot be: a burn is a few hundred ordinary
///     deletes and rules cannot tell it apart from tidying up. See
///     `functions/src/functions/burn.ts`.
///
/// Port lineage: the Dart `wipeAllData`/`_wipeHouseholdData`
/// (firebase_data_repository.dart) plus the burn screen's local-cleanup steps.
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
        /// The server refused the burn. Its sentence is carried through
        /// verbatim: it names the policy in force, which is the one useful
        /// fact, and flattening it into "something went wrong" would send the
        /// user to ask the owner a question the app already knows the answer
        /// to.
        case refused(String)

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
            case .refused(let message):
                message
            }
        }
    }

    // MARK: - Burning the household's shared data

    /// Wipes everything the household shares — tasks, checklists, plans,
    /// photos, the manual, live invites and join codes — through the
    /// `burnHousehold` Cloud Function.
    ///
    /// The function does the checking and the deleting. Nothing here decides
    /// whether the caller is allowed: a client-side guard would be a second
    /// implementation of the rule, and the one that drifts is always the one
    /// that says yes.
    ///
    /// It does NOT dissolve the household. Everyone who was in it is still in
    /// it afterwards, looking at an empty app — which is what "burn the data"
    /// means, as distinct from "delete my account".
    @discardableResult
    static func burnHouseholdData(log: @escaping @MainActor (String) -> Void) async throws -> Int {
        await log("Asking the server to erase household data…")
        do {
            let data = try await FunctionsClient.postObject("burnHousehold")
            let total = data["total"] as? Int ?? 0
            if let deleted = data["deleted"] as? [String: Int] {
                for (collection, count) in deleted.sorted(by: { $0.key < $1.key }) {
                    await log("\(collection): \(count) record(s)")
                }
            }
            await log("Household data erased — \(total) record(s)")
            return total
        } catch let error as FunctionsClient.APIError {
            // Includes the 403 a restricted member gets. It is the feature
            // working, not a fault, and it says which policy is in force.
            throw BurnError.refused(error.message)
        }
    }

    // MARK: - Deleting your own account

    /// Deletes everything that is the caller's alone, then proves it.
    ///
    /// Never gated, never asks about `burn_permission`: Guideline 5.1.1(v).
    /// Shared content survives — with one exception, below, where there is
    /// nobody left for it to be shared with.
    static func deleteMyAccountData(log: @escaping @MainActor (String) -> Void) async throws {
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
            try await leaveHousehold(householdId, uid: uid, log: log)
        }

        // Orphan sweep — SERVER source; the local cache can show stale
        // zero-doc results after the batch deletes. Legacy member rows with no
        // household_id at all are only reachable here.
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

    /// Leaves one household. Removes the caller's own membership and nothing
    /// of anyone else's — **unless the caller is the last member out**, in
    /// which case the household's content is theirs alone and is deleted with
    /// them.
    ///
    /// That exception is what keeps 5.1.1(v) satisfied without handing a
    /// restricted member a way around the burn policy: nobody else can be
    /// harmed by wiping a household nobody else is in. It is also why the
    /// household document is deleted only in the same branch — deleting it out
    /// from under surviving members is precisely the orphan state the sweep
    /// above exists to clean up.
    ///
    /// Removing OTHER people's memberships was in this path until 1.10.0 and
    /// is gone. Someone deleting their own account has no business evicting a
    /// household's other people, whether or not they founded it.
    private static func leaveHousehold(
        _ householdId: String, uid: String, log: @escaping @MainActor (String) -> Void
    ) async throws {
        let ownMemberDocID = "\(uid)_\(householdId)"

        let members = try await db.collection("household_members")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()
        let otherMembers = members.documents.filter { $0.documentID != ownMemberDocID }

        guard otherMembers.isEmpty else {
            await log("Leaving \(otherMembers.count) member(s) and their shared data in place")
            try await commitWithRetry(
                [db.collection("household_members").document(ownMemberDocID)],
                label: "membership", log: log)
            return
        }

        await log("You are the last member — this household's data goes with you")

        // Drive config FIRST — its rule needs the member doc to still exist.
        try? await db.collection("household_drive_config")
            .document(householdId).delete()

        var refs: [DocumentReference] = []
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

        await log("Deleting \(refs.count) record(s)…")
        for (i, chunk) in refs.chunked(into: 400).enumerated() {
            try await commitWithRetry(chunk, label: "batch \(i + 1)", log: log)
        }

        // FINAL batch: own member doc + household doc — last, so isMember()
        // held for everything above.
        try await commitWithRetry(
            [
                db.collection("household_members").document(ownMemberDocID),
                db.collection("households").document(householdId),
            ],
            label: "final (membership + household)", log: log)
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
