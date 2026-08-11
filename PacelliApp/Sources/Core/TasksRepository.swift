import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Task reads/writes. Field-level parity with the Dart
/// `firebase_data_repository.dart` — `tasks/{uuid}` flat docs, encrypted
/// title/description, explicit nulls, ISO dates.
enum TasksRepository {
    private static var db: Firestore { Firestore.firestore() }
    private static var uid: String? { Auth.auth().currentUser?.uid }

    /// All tasks for a household, decrypted, newest first.
    static func fetchTasks(householdId: String) async throws -> [HouseholdTask] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let snap = try await db.collection("tasks")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()

        return snap.documents
            .compactMap { doc -> HouseholdTask? in
                var data = doc.data()
                if let t = data["title"] as? String {
                    data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
                }
                if let d = data["description"] as? String {
                    data["description"] = PacelliCrypto.decryptNullable(d, key: key)
                }
                return HouseholdTask(map: data)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Creates a pending task (encrypting title/description) and returns it.
    /// Optional fields mirror the Dart `createTask` parameters used by the
    /// checklist → task push (due/start today, shared).
    static func createTask(
        householdId: String, title: String,
        dueDate: Date? = nil, reminderTime: String? = nil,
        startDate: Date? = nil, isShared: Bool = false
    ) async throws -> HouseholdTask {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }

        let task = HouseholdTask(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            title: title,
            dueDate: dueDate,
            reminderTime: reminderTime,
            startDate: startDate,
            isShared: isShared,
            createdBy: uid,
            createdAt: Date())

        var map = task.toMap()
        map["title"] = try PacelliCrypto.encrypt(title, key: key)

        try await db.collection("tasks").document(task.id).setData(map)
        await NotificationService.schedule(task, prefs: ReminderPrefs.current)
        return task
    }

    /// Toggles completion. Mirrors the Dart update shape.
    static func setCompleted(_ task: HouseholdTask, completed: Bool) async throws {
        guard let uid else { throw PacelliError.notSignedIn }
        let updates: [String: Any] = completed
            ? [
                "status": HouseholdTask.Status.completed,
                "completed_at": DartISO8601.string(from: Date()),
                "completed_by": uid,
            ]
            : [
                "status": HouseholdTask.Status.pending,
                "completed_at": NSNull(),
                "completed_by": NSNull(),
            ]
        try await db.collection("tasks").document(task.id).updateData(updates)

        // A completed task must stop nagging; un-completing restores it.
        if completed {
            NotificationService.cancel(task.id)
        } else {
            var reopened = task
            reopened.status = HouseholdTask.Status.pending
            await NotificationService.schedule(reopened, prefs: ReminderPrefs.current)
        }
    }

    /// Partial update. Mirrors Dart `updateTask` — only provided fields are
    /// written; `title`/`description` are encrypted. Additionally supports
    /// explicit clears (`.some(nil)` → Firestore null) for the nullable
    /// fields, which the Dart API couldn't express; the resulting doc shape
    /// is identical to a create with those fields null.
    static func updateTask(
        _ task: HouseholdTask,
        title: String? = nil,
        description: String?? = nil,
        categoryId: String?? = nil,
        priority: String? = nil,
        dueDate: Date?? = nil,
        reminderTime: String?? = nil,
        startDate: Date?? = nil,
        recurrence: String? = nil
    ) async throws {
        guard let key = await KeyManager.shared.loadHouseholdKey(task.householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        var updates: [String: Any] = [:]
        if let title { updates["title"] = try PacelliCrypto.encrypt(title, key: key) }
        if let description {
            updates["description"] =
                try description.map { try PacelliCrypto.encrypt($0, key: key) } ?? NSNull()
        }
        if let categoryId { updates["category_id"] = categoryId ?? NSNull() }
        if let priority { updates["priority"] = priority }
        if let dueDate {
            updates["due_date"] = dueDate.map(DartISO8601.string(from:)) ?? NSNull()
        }
        if let reminderTime { updates["reminder_time"] = reminderTime ?? NSNull() }
        if let startDate {
            updates["start_date"] = startDate.map(DartISO8601.string(from:)) ?? NSNull()
        }
        if let recurrence { updates["recurrence"] = recurrence }

        guard !updates.isEmpty else { return }
        try await db.collection("tasks").document(task.id).updateData(updates)

        // Reschedule from the post-update values: a due date or reminder time
        // that moved must move its reminder with it, and clearing the due date
        // must cancel it.
        var updated = task
        if let title { updated.title = title }
        if let dueDate { updated.dueDate = dueDate }
        if let reminderTime { updated.reminderTime = reminderTime }
        await NotificationService.schedule(updated, prefs: ReminderPrefs.current)
    }

    /// Deletes a task and its subtasks. Mirrors Dart `deleteTask` — subtask
    /// query filters on `household_id` (required by the security rules for
    /// list queries) + `task_id`, then a single batch removes everything.
    static func deleteTask(_ task: HouseholdTask) async throws {
        let subtasks = try await db.collection("subtasks")
            .whereField("household_id", isEqualTo: task.householdId)
            .whereField("task_id", isEqualTo: task.id)
            .getDocuments()

        let batch = db.batch()
        for doc in subtasks.documents {
            batch.deleteDocument(doc.reference)
        }
        batch.deleteDocument(db.collection("tasks").document(task.id))
        try await batch.commit()
        NotificationService.cancel(task.id)
    }
}
