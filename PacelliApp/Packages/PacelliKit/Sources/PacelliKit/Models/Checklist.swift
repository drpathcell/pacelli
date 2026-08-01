import Foundation

/// A checklist. Firestore doc: `checklists/{id}`.
///
/// Wire parity with Dart `lib/core/models/checklist.dart` — flat snake_case
/// map, ISO dates, `title` E2E-encrypted at rest. `items` live in their own
/// collection (`checklist_items`) and are attached client-side; `toMap()`
/// writes only the checklist doc fields (Dart parity).
public struct Checklist: Identifiable, Equatable, Sendable {
    public let id: String
    public let householdId: String
    /// Decrypted for display; encrypted at rest.
    public var title: String
    public let createdBy: String
    public let createdAt: Date
    public var updatedAt: Date?
    /// Attached client-side from `checklist_items`; never serialized.
    public var items: [ChecklistItem]

    public init(
        id: String, householdId: String, title: String, createdBy: String,
        createdAt: Date, updatedAt: Date? = nil, items: [ChecklistItem] = []
    ) {
        self.id = id
        self.householdId = householdId
        self.title = title
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
    }

    /// Mirrors Dart `Checklist.fromMap` required fields.
    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let householdId = map["household_id"] as? String,
              let title = map["title"] as? String,
              let createdBy = map["created_by"] as? String,
              let createdAt = DartISO8601.date(from: map["created_at"] as? String)
        else { return nil }
        self.init(
            id: id, householdId: householdId, title: title, createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: DartISO8601.date(from: map["updated_at"] as? String))
    }

    /// Checklist doc fields only — items are separate docs (Dart parity).
    public func toMap() -> [String: Any] {
        [
            "id": id,
            "household_id": householdId,
            "title": title,
            "created_by": createdBy,
            "created_at": DartISO8601.string(from: createdAt),
            "updated_at": updatedAt.map(DartISO8601.string(from:)) ?? NSNull(),
        ]
    }
}

/// A checklist item. Firestore doc: `checklist_items/{id}`.
/// `household_id` denormalized for the rules; `title` encrypted at rest.
public struct ChecklistItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let checklistId: String
    public let householdId: String
    /// Decrypted for display; encrypted at rest.
    public var title: String
    public var quantity: String?
    public var isChecked: Bool
    public let createdBy: String?
    public let createdAt: Date?
    public var checkedAt: Date?
    public var checkedBy: String?

    public init(
        id: String, checklistId: String, householdId: String = "", title: String,
        quantity: String? = nil, isChecked: Bool = false, createdBy: String? = nil,
        createdAt: Date? = nil, checkedAt: Date? = nil, checkedBy: String? = nil
    ) {
        self.id = id
        self.checklistId = checklistId
        self.householdId = householdId
        self.title = title
        self.quantity = quantity
        self.isChecked = isChecked
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.checkedAt = checkedAt
        self.checkedBy = checkedBy
    }

    /// Mirrors Dart `ChecklistItem.fromMap` — `id` and `title` required.
    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let title = map["title"] as? String
        else { return nil }
        self.init(
            id: id,
            checklistId: map["checklist_id"] as? String ?? "",
            householdId: map["household_id"] as? String ?? "",
            title: title,
            quantity: map["quantity"] as? String,
            isChecked: map["is_checked"] as? Bool ?? false,
            createdBy: map["created_by"] as? String,
            createdAt: DartISO8601.date(from: map["created_at"] as? String),
            checkedAt: DartISO8601.date(from: map["checked_at"] as? String),
            checkedBy: map["checked_by"] as? String)
    }

    /// Flat storage map. Mirrors Dart `addChecklistItem` doc shape.
    public func toMap() -> [String: Any] {
        [
            "id": id,
            "checklist_id": checklistId,
            "household_id": householdId,
            "title": title,
            "quantity": quantity ?? NSNull(),
            "is_checked": isChecked,
            "checked_at": checkedAt.map(DartISO8601.string(from:)) ?? NSNull(),
            "checked_by": checkedBy ?? NSNull(),
            "created_by": createdBy ?? NSNull(),
            "created_at": createdAt.map(DartISO8601.string(from:)) ?? NSNull(),
        ]
    }
}
