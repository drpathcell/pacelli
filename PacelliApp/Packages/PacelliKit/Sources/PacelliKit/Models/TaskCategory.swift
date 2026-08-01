import Foundation

/// A task category. Firestore doc: `task_categories/{id}`.
///
/// Wire parity with Dart `lib/core/models/task.dart` `TaskCategory.toMap()`
/// — flat snake_case map, `name` E2E-encrypted at rest, hex `color`.
public struct TaskCategory: Identifiable, Equatable, Sendable {
    public static let defaultIcon = "category"
    public static let defaultColor = "#7EA87E"

    public let id: String
    public let householdId: String?
    /// Decrypted for display; encrypted at rest.
    public var name: String
    public var icon: String
    public var color: String
    public let isDefault: Bool

    public init(
        id: String, householdId: String? = nil, name: String,
        icon: String = TaskCategory.defaultIcon,
        color: String = TaskCategory.defaultColor,
        isDefault: Bool = false
    ) {
        self.id = id
        self.householdId = householdId
        self.name = name
        self.icon = icon
        self.color = color
        self.isDefault = isDefault
    }

    /// Mirrors Dart `TaskCategory.fromMap` — `id` and `name` required.
    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let name = map["name"] as? String
        else { return nil }
        self.init(
            id: id,
            householdId: map["household_id"] as? String,
            name: name,
            icon: map["icon"] as? String ?? TaskCategory.defaultIcon,
            color: map["color"] as? String ?? TaskCategory.defaultColor,
            isDefault: map["is_default"] as? Bool ?? false)
    }

    /// Flat storage map. Mirrors Dart `createCategory` doc shape exactly.
    public func toMap() -> [String: Any] {
        [
            "id": id,
            "household_id": householdId ?? NSNull(),
            "name": name,
            "icon": icon,
            "color": color,
            "is_default": isDefault,
        ]
    }
}
