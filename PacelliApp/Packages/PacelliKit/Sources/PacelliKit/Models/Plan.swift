import Foundation

/// A scratch plan. Firestore doc: `scratch_plans/{id}` (the collection name
/// is historic — this is the plans feature).
///
/// Wire parity with Dart `lib/core/models/plan.dart` — flat snake_case map,
/// date-ONLY strings (`yyyy-MM-dd`) for start/end dates, ISO timestamps for
/// created/updated, `title` + `template_name` E2E-encrypted at rest.
/// Entries and checklist items live in `plan_entries` /
/// `plan_checklist_items` and attach client-side; `toMap()` writes only the
/// plan doc fields.
public struct Plan: Identifiable, Equatable, Sendable {
    public enum PlanType {
        public static let weekly = "weekly"
        public static let daily = "daily"
        public static let custom = "custom"
    }

    public enum Status {
        public static let draft = "draft"
        public static let finalised = "finalised"
    }

    public let id: String
    public let householdId: String
    /// Decrypted for display; encrypted at rest.
    public var title: String
    public let type: String
    public var status: String
    public var startDate: Date
    public var endDate: Date
    public let isTemplate: Bool
    /// Decrypted for display; encrypted at rest (nullable).
    public let templateName: String?
    public let createdBy: String
    public let createdAt: Date
    public var updatedAt: Date?
    /// Attached client-side; never serialized.
    public var entries: [PlanEntry]
    /// Attached client-side; never serialized.
    public var checklistItems: [PlanChecklistItem]

    public init(
        id: String, householdId: String, title: String,
        type: String = PlanType.weekly, status: String = Status.draft,
        startDate: Date, endDate: Date, isTemplate: Bool = false,
        templateName: String? = nil, createdBy: String, createdAt: Date,
        updatedAt: Date? = nil, entries: [PlanEntry] = [],
        checklistItems: [PlanChecklistItem] = []
    ) {
        self.id = id
        self.householdId = householdId
        self.title = title
        self.type = type
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.isTemplate = isTemplate
        self.templateName = templateName
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.entries = entries
        self.checklistItems = checklistItems
    }

    /// Mirrors Dart `Plan.fromMap` required fields.
    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let householdId = map["household_id"] as? String,
              let title = map["title"] as? String,
              let startDate = DartDateOnly.date(from: map["start_date"] as? String),
              let endDate = DartDateOnly.date(from: map["end_date"] as? String),
              let createdBy = map["created_by"] as? String,
              let createdAt = DartISO8601.date(from: map["created_at"] as? String)
        else { return nil }
        self.init(
            id: id, householdId: householdId, title: title,
            type: map["type"] as? String ?? PlanType.weekly,
            status: map["status"] as? String ?? Status.draft,
            startDate: startDate, endDate: endDate,
            isTemplate: map["is_template"] as? Bool ?? false,
            templateName: map["template_name"] as? String,
            createdBy: createdBy, createdAt: createdAt,
            updatedAt: DartISO8601.date(from: map["updated_at"] as? String))
    }

    /// Plan doc fields only — children are separate docs (Dart parity).
    public func toMap() -> [String: Any] {
        [
            "id": id,
            "household_id": householdId,
            "title": title,
            "type": type,
            "status": status,
            "start_date": DartDateOnly.string(from: startDate),
            "end_date": DartDateOnly.string(from: endDate),
            "is_template": isTemplate,
            "template_name": templateName ?? NSNull(),
            "created_by": createdBy,
            "created_at": DartISO8601.string(from: createdAt),
            "updated_at": updatedAt.map(DartISO8601.string(from:)) ?? NSNull(),
        ]
    }
}

/// A single entry/row within a plan day. Firestore doc: `plan_entries/{id}`.
public struct PlanEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let planId: String
    public let householdId: String
    public var entryDate: Date
    /// Decrypted for display; encrypted at rest.
    public var title: String
    /// Decrypted for display; encrypted at rest (nullable).
    public var label: String?
    /// Decrypted for display; encrypted at rest (nullable).
    public var description: String?
    public var sortOrder: Int
    public let createdBy: String?
    public let createdAt: Date?

    public init(
        id: String, planId: String, householdId: String = "", entryDate: Date,
        title: String, label: String? = nil, description: String? = nil,
        sortOrder: Int = 0, createdBy: String? = nil, createdAt: Date? = nil
    ) {
        self.id = id
        self.planId = planId
        self.householdId = householdId
        self.entryDate = entryDate
        self.title = title
        self.label = label
        self.description = description
        self.sortOrder = sortOrder
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    /// Mirrors Dart `PlanEntry.fromMap` — id, entry_date, title required.
    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let entryDate = DartDateOnly.date(from: map["entry_date"] as? String),
              let title = map["title"] as? String
        else { return nil }
        self.init(
            id: id,
            planId: map["plan_id"] as? String ?? "",
            householdId: map["household_id"] as? String ?? "",
            entryDate: entryDate,
            title: title,
            label: map["label"] as? String,
            description: map["description"] as? String,
            sortOrder: map["sort_order"] as? Int ?? 0,
            createdBy: map["created_by"] as? String,
            createdAt: DartISO8601.date(from: map["created_at"] as? String))
    }

    /// Flat storage map. Mirrors Dart `addEntry` doc shape.
    public func toMap() -> [String: Any] {
        [
            "id": id,
            "plan_id": planId,
            "household_id": householdId,
            "entry_date": DartDateOnly.string(from: entryDate),
            "title": title,
            "label": label ?? NSNull(),
            "description": description ?? NSNull(),
            "sort_order": sortOrder,
            "created_by": createdBy ?? NSNull(),
            "created_at": createdAt.map(DartISO8601.string(from:)) ?? NSNull(),
        ]
    }
}

/// A checklist item belonging to a plan (optionally linked to an entry).
/// Firestore doc: `plan_checklist_items/{id}`.
public struct PlanChecklistItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let planId: String
    public let householdId: String
    public let entryId: String?
    /// Decrypted for display; encrypted at rest.
    public var title: String
    public var quantity: String?
    public var isChecked: Bool
    public let createdBy: String?
    public let createdAt: Date?
    public var checkedAt: Date?
    public var checkedBy: String?

    public init(
        id: String, planId: String, householdId: String = "",
        entryId: String? = nil, title: String, quantity: String? = nil,
        isChecked: Bool = false, createdBy: String? = nil,
        createdAt: Date? = nil, checkedAt: Date? = nil, checkedBy: String? = nil
    ) {
        self.id = id
        self.planId = planId
        self.householdId = householdId
        self.entryId = entryId
        self.title = title
        self.quantity = quantity
        self.isChecked = isChecked
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.checkedAt = checkedAt
        self.checkedBy = checkedBy
    }

    /// Mirrors Dart `PlanChecklistItem.fromMap` — id + title required.
    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let title = map["title"] as? String
        else { return nil }
        self.init(
            id: id,
            planId: map["plan_id"] as? String ?? "",
            householdId: map["household_id"] as? String ?? "",
            entryId: map["entry_id"] as? String,
            title: title,
            quantity: map["quantity"] as? String,
            isChecked: map["is_checked"] as? Bool ?? false,
            createdBy: map["created_by"] as? String,
            createdAt: DartISO8601.date(from: map["created_at"] as? String),
            checkedAt: DartISO8601.date(from: map["checked_at"] as? String),
            checkedBy: map["checked_by"] as? String)
    }

    /// Flat storage map. Mirrors Dart `addPlanChecklistItem` doc shape.
    public func toMap() -> [String: Any] {
        [
            "id": id,
            "plan_id": planId,
            "household_id": householdId,
            "entry_id": entryId ?? NSNull(),
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
