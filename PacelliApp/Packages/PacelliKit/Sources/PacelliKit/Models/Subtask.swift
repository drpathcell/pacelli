import Foundation

/// A subtask of a household task. Firestore doc: `subtasks/{id}`.
///
/// Wire parity with Dart `lib/core/models/task.dart` `Subtask.toMap()` —
/// flat snake_case map, `title` E2E-encrypted at rest. `household_id` is
/// denormalized onto every doc because the security rules require it for
/// list queries.
public struct Subtask: Identifiable, Equatable, Sendable {
    public let id: String
    public let taskId: String
    public let householdId: String
    /// Decrypted for display; encrypted at rest.
    public var title: String
    public var isCompleted: Bool
    public var sortOrder: Int

    public init(
        id: String, taskId: String, householdId: String = "", title: String,
        isCompleted: Bool = false, sortOrder: Int = 0
    ) {
        self.id = id
        self.taskId = taskId
        self.householdId = householdId
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }

    /// Mirrors Dart `Subtask.fromMap` — `id` and `title` are required,
    /// everything else defaults.
    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let title = map["title"] as? String
        else { return nil }
        self.init(
            id: id,
            taskId: map["task_id"] as? String ?? "",
            householdId: map["household_id"] as? String ?? "",
            title: title,
            isCompleted: map["is_completed"] as? Bool ?? false,
            sortOrder: map["sort_order"] as? Int ?? 0)
    }

    /// Flat storage map. Mirrors Dart `addSubtask` doc shape exactly.
    public func toMap() -> [String: Any] {
        [
            "id": id,
            "task_id": taskId,
            "household_id": householdId,
            "title": title,
            "is_completed": isCompleted,
            "sort_order": sortOrder,
        ]
    }
}
