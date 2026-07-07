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

        return CurrentHousehold(
            household: Household(id: householdId, name: name, createdBy: uid, createdAt: now),
            role: "admin")
    }

    /// The current user's household with its key loaded, or nil if none.
    static func getCurrentHousehold() async -> CurrentHousehold? {
        guard let uid else { return nil }
        do {
            print("[HouseholdService] membership query for \(uid)…")
            let memberSnap = try await db.collection("household_members")
                .whereField("user_id", isEqualTo: uid)
                .limit(to: 1)
                .getDocuments()
            print("[HouseholdService] membership docs: \(memberSnap.documents.count)")
            guard let membership = memberSnap.documents.first?.data(),
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
