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
    static func createTask(householdId: String, title: String) async throws -> HouseholdTask {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }

        let task = HouseholdTask(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            title: title,
            createdBy: uid,
            createdAt: Date())

        var map = task.toMap()
        map["title"] = try PacelliCrypto.encrypt(title, key: key)

        try await db.collection("tasks").document(task.id).setData(map)
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
    }
}
