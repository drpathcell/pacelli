import Foundation

/// A task within a household. Firestore doc: `tasks/{id}`.
///
/// Wire parity with Dart `lib/core/models/task.dart` `toMap()` — flat
/// snake_case map, ISO-8601 string dates, explicit nulls on create,
/// `title`/`description` E2E-encrypted at rest.
///
/// Named `HouseholdTask` to avoid colliding with Swift concurrency's `Task`.
public struct HouseholdTask: Identifiable, Equatable, Sendable {
    public enum Status {
        public static let pending = "pending"
        public static let inProgress = "in_progress"
        public static let completed = "completed"
    }

    public enum Priority {
        public static let low = "low"
        public static let medium = "medium"
        public static let high = "high"
        public static let urgent = "urgent"
    }

    public let id: String
    public let householdId: String
    /// Decrypted for display; encrypted at rest.
    public var title: String
    /// Decrypted for display; encrypted at rest.
    public var description: String?
    public var categoryId: String?
    public var priority: String
    public var status: String
    public var dueDate: Date?
    /// Per-task reminder time as "HH:mm", overriding the device default.
    /// NOT encrypted — structural metadata of the same class as `dueDate`,
    /// which is also plain. Encrypting it would be inconsistent and would
    /// protect nothing the due date does not already reveal.
    public var reminderTime: String?
    public var startDate: Date?
    public var assignedTo: String?
    public var isShared: Bool
    public var recurrence: String
    public let createdBy: String
    public let createdAt: Date
    public var completedAt: Date?
    public var completedBy: String?

    public var isCompleted: Bool { status == Status.completed }

    public init(
        id: String, householdId: String, title: String, description: String? = nil,
        categoryId: String? = nil, priority: String = Priority.medium,
        status: String = Status.pending, dueDate: Date? = nil,
        reminderTime: String? = nil, startDate: Date? = nil,
        assignedTo: String? = nil, isShared: Bool = false, recurrence: String = "none",
        createdBy: String, createdAt: Date, completedAt: Date? = nil,
        completedBy: String? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.title = title
        self.description = description
        self.categoryId = categoryId
        self.priority = priority
        self.status = status
        self.dueDate = dueDate
        self.reminderTime = reminderTime
        self.startDate = startDate
        self.assignedTo = assignedTo
        self.isShared = isShared
        self.recurrence = recurrence
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.completedBy = completedBy
    }

    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let householdId = map["household_id"] as? String,
              let title = map["title"] as? String,
              let createdBy = map["created_by"] as? String,
              let createdAt = DartISO8601.date(from: map["created_at"] as? String)
        else { return nil }
        self.init(
            id: id,
            householdId: householdId,
            title: title,
            description: map["description"] as? String,
            categoryId: map["category_id"] as? String,
            priority: map["priority"] as? String ?? Priority.medium,
            status: map["status"] as? String ?? Status.pending,
            dueDate: DartISO8601.date(from: map["due_date"] as? String),
            reminderTime: map["reminder_time"] as? String,
            startDate: DartISO8601.date(from: map["start_date"] as? String),
            assignedTo: map["assigned_to"] as? String,
            isShared: map["is_shared"] as? Bool ?? false,
            recurrence: map["recurrence"] as? String ?? "none",
            createdBy: createdBy,
            createdAt: createdAt,
            completedAt: DartISO8601.date(from: map["completed_at"] as? String),
            completedBy: map["completed_by"] as? String)
    }

    /// Flat storage map. Mirrors Dart `createTask` — nullable fields are
    /// written as explicit `NSNull` so document shape matches exactly.
    public func toMap() -> [String: Any] {
        [
            "id": id,
            "household_id": householdId,
            "title": title,
            "description": description ?? NSNull(),
            "category_id": categoryId ?? NSNull(),
            "priority": priority,
            "status": status,
            "due_date": dueDate.map(DartISO8601.string(from:)) ?? NSNull(),
            "reminder_time": reminderTime ?? NSNull(),
            "start_date": startDate.map(DartISO8601.string(from:)) ?? NSNull(),
            "assigned_to": assignedTo ?? NSNull(),
            "is_shared": isShared,
            "recurrence": recurrence,
            "created_by": createdBy,
            "created_at": DartISO8601.string(from: createdAt),
            "completed_at": completedAt.map(DartISO8601.string(from:)) ?? NSNull(),
            "completed_by": completedBy ?? NSNull(),
        ]
    }
}
