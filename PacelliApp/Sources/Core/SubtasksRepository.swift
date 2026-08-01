import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Subtask reads/writes. Parity with the Dart repository — `subtasks/{uuid}`
/// flat docs, encrypted `title`, `household_id` denormalized for the rules.
enum SubtasksRepository {
    private static var db: Firestore { Firestore.firestore() }

    /// All subtasks for one task, decrypted, in sort order.
    static func fetchSubtasks(taskId: String, householdId: String) async throws -> [Subtask] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let snap = try await db.collection("subtasks")
            .whereField("household_id", isEqualTo: householdId)
            .whereField("task_id", isEqualTo: taskId)
            .getDocuments()

        return snap.documents
            .compactMap { doc -> Subtask? in
                var data = doc.data()
                if let t = data["title"] as? String {
                    data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
                }
                return Subtask(map: data)
            }
            .sorted { ($0.sortOrder, $0.id) < ($1.sortOrder, $1.id) }
    }

    /// All subtasks for a household keyed by task ID (list-view badges).
    /// One rules-compatible query; grouping happens client-side.
    static func fetchSubtasksByTask(householdId: String) async throws -> [String: [Subtask]] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let snap = try await db.collection("subtasks")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()

        var result: [String: [Subtask]] = [:]
        for doc in snap.documents {
            var data = doc.data()
            if let t = data["title"] as? String {
                data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
            }
            guard let subtask = Subtask(map: data), !subtask.taskId.isEmpty else { continue }
            result[subtask.taskId, default: []].append(subtask)
        }
        for key in result.keys {
            result[key]?.sort { ($0.sortOrder, $0.id) < ($1.sortOrder, $1.id) }
        }
        return result
    }

    /// Creates a subtask (encrypting the title) and returns it.
    /// Mirrors Dart `addSubtask` doc shape.
    static func addSubtask(
        taskId: String, householdId: String, title: String, sortOrder: Int = 0
    ) async throws -> Subtask {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let subtask = Subtask(
            id: UUID().uuidString.lowercased(),
            taskId: taskId,
            householdId: householdId,
            title: title,
            sortOrder: sortOrder)

        var map = subtask.toMap()
        map["title"] = try PacelliCrypto.encrypt(title, key: key)

        try await db.collection("subtasks").document(subtask.id).setData(map)
        return subtask
    }

    /// Mirrors Dart `toggleSubtask`.
    static func setCompleted(_ subtask: Subtask, completed: Bool) async throws {
        try await db.collection("subtasks").document(subtask.id)
            .updateData(["is_completed": completed])
    }

    /// Mirrors Dart `deleteSubtask`.
    static func deleteSubtask(_ subtask: Subtask) async throws {
        try await db.collection("subtasks").document(subtask.id).delete()
    }
}
