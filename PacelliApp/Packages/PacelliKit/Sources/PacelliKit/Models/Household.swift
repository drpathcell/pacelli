import Foundation

/// A household group. Firestore doc: `households/{id}`.
/// Wire parity with Dart `lib/core/models/household.dart` — snake_case
/// fields, ISO-8601 string dates, `name` stored E2E-encrypted.
public struct Household: Identifiable, Equatable, Sendable {
    public let id: String
    /// Decrypted for display; encrypted at rest.
    public var name: String
    public let createdBy: String
    public let createdAt: Date

    public init(id: String, name: String, createdBy: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let name = map["name"] as? String,
              let createdBy = map["created_by"] as? String,
              let createdAt = DartISO8601.date(from: map["created_at"] as? String)
        else { return nil }
        self.init(id: id, name: name, createdBy: createdBy, createdAt: createdAt)
    }

    public func toMap() -> [String: Any] {
        [
            "id": id,
            "name": name,
            "created_by": createdBy,
            "created_at": DartISO8601.string(from: createdAt),
        ]
    }
}

/// A member within a household. Firestore doc:
/// `household_members/{userId}_{householdId}` — the deterministic doc ID is
/// load-bearing (security rules call `exists()` on it).
public struct HouseholdMember: Equatable, Sendable {
    public let userId: String
    public let householdId: String
    public var role: String  // "admin" | "member"
    public let joinedAt: Date?
    /// Document ID of the `household_invites` or `household_join_codes` doc
    /// that authorised this membership. Security rules require it on create
    /// (except when founding a household) and verify it server-side — it is
    /// what stops any signed-in user from adding themselves to a household
    /// whose ID they happen to know. Nil for founders and legacy docs.
    public let joinedVia: String?

    public var documentID: String { "\(userId)_\(householdId)" }

    public init(
        userId: String, householdId: String, role: String, joinedAt: Date?,
        joinedVia: String? = nil
    ) {
        self.userId = userId
        self.householdId = householdId
        self.role = role
        self.joinedAt = joinedAt
        self.joinedVia = joinedVia
    }

    public init?(map: [String: Any]) {
        guard let userId = map["user_id"] as? String else { return nil }
        self.init(
            userId: userId,
            householdId: map["household_id"] as? String ?? "",
            role: map["role"] as? String ?? "member",
            joinedAt: DartISO8601.date(from: map["joined_at"] as? String),
            joinedVia: map["joined_via"] as? String)
    }

    public func toMap() -> [String: Any] {
        var map: [String: Any] = [
            "household_id": householdId,
            "user_id": userId,
            "role": role,
        ]
        if let joinedAt { map["joined_at"] = DartISO8601.string(from: joinedAt) }
        if let joinedVia { map["joined_via"] = joinedVia }
        return map
    }
}
