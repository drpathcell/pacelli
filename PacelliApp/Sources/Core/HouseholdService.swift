import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

struct CurrentHousehold: Sendable {
    let household: Household
    let role: String
}

/// Household CRUD. Port of `lib/features/household/data/household_service.dart`
/// — identical collections, doc IDs, field names, and encryption points.
enum HouseholdService {
    private static var db: Firestore { Firestore.firestore() }
    private static var uid: String? { Auth.auth().currentUser?.uid }

    /// Creates a household and adds the current user as admin.
    /// Batch parity with Dart: `households/{uuid}` (encrypted name, ISO date)
    /// + `household_members/{uid}_{householdId}` (deterministic ID — rules).
    static func createHousehold(named name: String) async throws -> CurrentHousehold {
        guard let uid else { throw PacelliError.notSignedIn }

        let householdId = UUID().uuidString.lowercased()
        let now = Date()

        let householdKey = try await KeyManager.shared.createHouseholdKey(householdId)
        let encryptedName = try PacelliCrypto.encrypt(name, key: householdKey)

        let batch = db.batch()
        batch.setData(
            [
                "id": householdId,
                "name": encryptedName,
                "created_by": uid,
                "created_at": DartISO8601.string(from: now),
            ],
            forDocument: db.collection("households").document(householdId))

        let member = HouseholdMember(
            userId: uid, householdId: householdId, role: "admin", joinedAt: now)
        batch.setData(
            member.toMap(),
            forDocument: db.collection("household_members").document(member.documentID))

        try await batch.commit()

        // Dart parity (_encryptProfileName): now that a household key exists,
        // encrypt the locally-cached display name into the profile doc.
        await encryptProfileName(uid: uid, householdKey: householdKey)

        return CurrentHousehold(
            household: Household(id: householdId, name: name, createdBy: uid, createdAt: now),
            role: "admin")
    }


    /// Content collections that make a household non-empty. Same list as
    /// `BurnService.wipeHousehold` — if a household-scoped collection is added,
    /// it must be added in both places or an "empty" household could still
    /// hold data when it is discarded.
    static let householdContentCollections = [
        "tasks", "checklists", "scratch_plans",
        "task_categories", "task_attachments", "plan_attachments",
        "inventory_items", "inventory_categories",
        "inventory_locations", "inventory_logs", "inventory_attachments",
        "manual_entries", "manual_categories", "feedback", "diagnostics",
        "weekly_digests",
        "subtasks", "checklist_items", "plan_entries", "plan_checklist_items",
    ]

    /// Deletes the caller's own auto-provisioned households that are provably
    /// empty, keeping `keep`. Returns how many were discarded.
    ///
    /// Someone who used the app before being invited is left holding a second,
    /// empty household forever; they accumulate, and every extra membership is
    /// another way for `getCurrentHousehold` to pick wrong. Deliberately
    /// strict: it discards only a household the caller created, with no other
    /// member, and zero documents in EVERY content collection. Any doubt and
    /// it leaves the household alone. Non-fatal throughout — failing to tidy
    /// up must never break a successful join.
    @discardableResult
    static func discardOwnEmptyHouseholds(except keep: String) async -> Int {
        guard let uid else { return 0 }
        var discarded = 0
        do {
            let memberships = try await db.collection("household_members")
                .whereField("user_id", isEqualTo: uid)
                .getDocuments()
            for memberDoc in memberships.documents {
                guard let hid = memberDoc.data()["household_id"] as? String,
                      hid != keep, !hid.isEmpty
                else { continue }
                if await isDiscardable(hid, uid: uid) {
                    await discard(hid, uid: uid)
                    discarded += 1
                }
            }
        } catch {
            print("[HouseholdService] discardOwnEmptyHouseholds failed: \(error)")
        }
        return discarded
    }

    private static func isDiscardable(_ householdId: String, uid: String) async -> Bool {
        do {
            let household = try await db.collection("households")
                .document(householdId).getDocument()
            // Never touch a household someone else created.
            guard household.exists,
                  household.data()?["created_by"] as? String == uid
            else { return false }

            let members = try await db.collection("household_members")
                .whereField("household_id", isEqualTo: householdId)
                .getDocuments()
            guard members.documents.count == 1 else { return false }

            // A pending invite means somebody is expected — not abandoned.
            let invites = try await db.collection("household_invites")
                .whereField("household_id", isEqualTo: householdId)
                .limit(to: 1)
                .getDocuments()
            guard invites.documents.isEmpty else { return false }

            for collection in householdContentCollections {
                let snap = try await db.collection(collection)
                    .whereField("household_id", isEqualTo: householdId)
                    .limit(to: 1)
                    .getDocuments()
                guard snap.documents.isEmpty else { return false }
            }
            return true
        } catch {
            print("[HouseholdService] isDiscardable(\(householdId)) failed: \(error)")
            return false
        }
    }

    private static func discard(_ householdId: String, uid: String) async {
        do {
            // Join codes first: they are the only thing that could let someone
            // else walk into a household we are about to delete.
            try? await JoinCodeService.revokeAll(householdId: householdId)
            await KeyManager.shared.deleteKeyFromFirestore(householdId)
            let batch = db.batch()
            batch.deleteDocument(
                db.collection("household_members").document("\(uid)_\(householdId)"))
            batch.deleteDocument(db.collection("households").document(householdId))
            try await batch.commit()
            SecureStore.delete("hk_\(householdId)")
            print("[HouseholdService] discarded empty household \(householdId)")
        } catch {
            print("[HouseholdService] discard(\(householdId)) failed: \(error)")
        }
    }

    /// Reads the Keychain-cached profile name, encrypts it with the
    /// household key, writes it to `profiles/{uid}`. Non-fatal on failure.
    ///
    /// Was `private` and called only from `createHousehold`, which meant a
    /// name could only ever reach Firestore for the person who FOUNDED a
    /// household. Anyone who joined by code or invite stayed nameless forever
    /// and showed up in the members list as "Member". Now also called on join
    /// and whenever a session lands in a household.
    static func encryptProfileName(uid: String, householdKey: String) async {
        guard let localName = SecureStore.read("profile_name_\(uid)"),
              !localName.isEmpty,
              let encrypted = try? PacelliCrypto.encrypt(localName, key: householdKey)
        else { return }
        try? await db.collection("profiles").document(uid)
            .updateData(["full_name": encrypted])
    }

    /// Set (or change) the name other members see.
    ///
    /// Sign in with Apple hands back a name only on the very FIRST
    /// authorization, ever — sign in a second time and Apple returns nothing,
    /// permanently, unless the user revokes the app in iOS Settings. Relying
    /// on it meant most people could never have a name at all. This is the
    /// path that always works.
    ///
    /// Encrypted with the household key like every other piece of content, so
    /// the server never sees it. Cached in the Keychain too, so it survives
    /// into any household joined later.
    static func setDisplayName(_ name: String, householdId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw PacelliError.notSignedIn }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }

        if trimmed.isEmpty {
            SecureStore.delete("profile_name_\(uid)")
            try await db.collection("profiles").document(uid)
                .setData(["full_name": ""], merge: true)
            return
        }
        SecureStore.write("profile_name_\(uid)", value: trimmed)
        let encrypted = try PacelliCrypto.encrypt(trimmed, key: key)
        // merge:true, not updateData — a profile doc can be missing for an
        // account created before profiles existed, and updateData would throw.
        try await db.collection("profiles").document(uid)
            .setData(["full_name": encrypted], merge: true)
    }

    /// The current user's own name, decrypted, for pre-filling the field.
    static func currentDisplayName(householdId: String) async -> String {
        guard let uid = Auth.auth().currentUser?.uid else { return "" }
        if let cached = SecureStore.read("profile_name_\(uid)"), !cached.isEmpty {
            return cached
        }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId),
              let data = try? await db.collection("profiles").document(uid).getDocument().data(),
              let encrypted = data["full_name"] as? String, !encrypted.isEmpty
        else { return "" }
        return (try? PacelliCrypto.decrypt(encrypted, key: key)) ?? ""
    }

    /// Renames the household (any member — flat-membership model; Firestore
    /// rules allow `update` for `isMember`). Name is E2E-encrypted with the
    /// household key before upload, same as `createHousehold`.
    static func renameHousehold(_ householdId: String, to name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let encrypted = try PacelliCrypto.encrypt(trimmed, key: key)
        try await db.collection("households").document(householdId)
            .updateData(["name": encrypted])
    }

    /// The current user's household with its key loaded, or nil if none.
    /// - Parameter preferring: which household to land in when the user
    ///   belongs to more than one. Someone who used guest mode before being
    ///   invited ends up with two member docs; the old `limit(to: 1)` made the
    ///   winner whichever doc Firestore returned first, so a freshly accepted
    ///   invite could silently drop them back into their own empty household.
    ///   Without a preference we now take the most recently joined household,
    ///   which is at least deterministic.
    static func getCurrentHousehold(preferring preferredId: String? = nil) async
        -> CurrentHousehold?
    {
        guard let uid else { return nil }
        do {
            print("[HouseholdService] membership query for \(uid)…")
            let memberSnap = try await db.collection("household_members")
                .whereField("user_id", isEqualTo: uid)
                .getDocuments()
            print("[HouseholdService] membership docs: \(memberSnap.documents.count)")

            let memberships = memberSnap.documents.map { $0.data() }
            let preferred = preferredId.flatMap { wanted in
                memberships.first { $0["household_id"] as? String == wanted }
            }
            let newest = memberships.max { a, b in
                let lhs = DartISO8601.date(from: a["joined_at"] as? String) ?? .distantPast
                let rhs = DartISO8601.date(from: b["joined_at"] as? String) ?? .distantPast
                return lhs < rhs
            }
            guard let membership = preferred ?? newest,
                  let householdId = membership["household_id"] as? String
            else { return nil }

            let key = await KeyManager.shared.loadHouseholdKey(householdId)

            let doc = try await db.collection("households").document(householdId).getDocument()
            guard var data = doc.data() else { return nil }

            if let key, let encryptedName = data["name"] as? String {
                data["name"] = PacelliCrypto.decryptNullable(encryptedName, key: key)
                    ?? encryptedName
            }
            data["id"] = householdId

            guard let household = Household(map: data) else { return nil }
            return CurrentHousehold(
                household: household,
                role: membership["role"] as? String ?? "member")
        } catch {
            print("[HouseholdService] getCurrentHousehold failed: \(error)")
            return nil
        }
    }
}
