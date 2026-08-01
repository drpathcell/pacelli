import Foundation

/// A household-manual entry. Firestore doc: `manual_entries/{id}`.
///
/// Wire parity with Dart — flat snake_case map, `title`/`content`/`tags`
/// E2E-encrypted at rest. NOTE: unlike every other Pacelli collection,
/// `created_at`/`updated_at` are Firestore **Timestamps**, not ISO strings —
/// the repository converts them to `Date` before mapping (PacelliKit stays
/// Firebase-free).
public struct ManualEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let householdId: String
    /// Decrypted for display; encrypted at rest.
    public var title: String
    /// Markdown. Decrypted for display; encrypted at rest.
    public var content: String
    public var categoryId: String?
    /// Decrypted for display; each tag encrypted at rest.
    public var tags: [String]
    public var isPinned: Bool
    public let createdBy: String
    public let createdAt: Date
    public var updatedAt: Date
    public var lastEditedBy: String?

    public init(
        id: String, householdId: String, title: String, content: String = "",
        categoryId: String? = nil, tags: [String] = [], isPinned: Bool = false,
        createdBy: String, createdAt: Date, updatedAt: Date,
        lastEditedBy: String? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.title = title
        self.content = content
        self.categoryId = categoryId
        self.tags = tags
        self.isPinned = isPinned
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastEditedBy = lastEditedBy
    }

    /// Expects `created_at`/`updated_at` pre-converted to `Date`
    /// (Timestamp → Date happens in the repository).
    public init?(map: [String: Any]) {
        guard let id = map["id"] as? String,
              let householdId = map["household_id"] as? String,
              let title = map["title"] as? String,
              let createdBy = map["created_by"] as? String,
              let createdAt = map["created_at"] as? Date,
              let updatedAt = map["updated_at"] as? Date
        else { return nil }
        self.init(
            id: id, householdId: householdId, title: title,
            content: map["content"] as? String ?? "",
            categoryId: map["category_id"] as? String,
            tags: map["tags"] as? [String] ?? [],
            isPinned: map["is_pinned"] as? Bool ?? false,
            createdBy: createdBy, createdAt: createdAt, updatedAt: updatedAt,
            lastEditedBy: map["last_edited_by"] as? String)
    }
}
