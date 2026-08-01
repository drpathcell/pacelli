import FirebaseFirestore
import Foundation
import PacelliKit

/// Task-category reads/writes. Parity with the Dart repository —
/// `task_categories/{uuid}` flat docs, encrypted `name`, hex `color`.
enum CategoriesRepository {
    private static var db: Firestore { Firestore.firestore() }

    /// All categories for a household, decrypted. Defaults first, then by
    /// name (Dart sort order).
    static func fetchCategories(householdId: String) async throws -> [TaskCategory] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let snap = try await db.collection("task_categories")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()

        return snap.documents
            .compactMap { doc -> TaskCategory? in
                var data = doc.data()
                if let n = data["name"] as? String {
                    data["name"] = PacelliCrypto.decryptNullable(n, key: key) ?? n
                }
                return TaskCategory(map: data)
            }
            .sorted {
                if $0.isDefault != $1.isDefault { return $0.isDefault }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    /// Creates a category (encrypting the name) and returns it.
    /// Mirrors Dart `createCategory` doc shape.
    static func createCategory(
        householdId: String, name: String,
        icon: String = TaskCategory.defaultIcon,
        color: String = TaskCategory.defaultColor
    ) async throws -> TaskCategory {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let category = TaskCategory(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            name: name,
            icon: icon,
            color: color,
            isDefault: false)

        var map = category.toMap()
        map["name"] = try PacelliCrypto.encrypt(name, key: key)

        try await db.collection("task_categories").document(category.id).setData(map)
        return category
    }

    /// Mirrors Dart `deleteCategory` — default categories are never deleted.
    static func deleteCategory(_ category: TaskCategory) async throws {
        guard !category.isDefault else { return }
        try await db.collection("task_categories").document(category.id).delete()
    }
}
