import Foundation

/// A reusable set of checklist items. Firestore doc: `checklist_templates/{id}`.
///
/// "Save 'quick Dunnes shop' once, and anyone in the house can turn it into a
/// real list when they're heading out." Routines, made cheap.
///
/// ## Why the items live inside this document
///
/// Checklists keep their items in a separate `checklist_items` collection,
/// because items there are individually mutable: ticked, renamed, re-quantified,
/// pushed to tasks. A template's items are none of those things — the whole
/// template is read, written and stamped out as one unit, so a second
/// collection would buy a query, a second rules block and a second test suite
/// for nothing.
///
/// It also closes a real gap. In `checklist_items` the title is encrypted and
/// the **quantity is not** — a leak inherited from the original Dart schema and
/// deliberately not patched mid-feature. Here the entire item list is one
/// encrypted blob, so a template's quantities are covered by construction.
public struct ChecklistTemplate: Identifiable, Equatable, Sendable {
    public let id: String
    public let householdId: String
    /// Decrypted for display; encrypted at rest.
    public var title: String
    /// Decrypted for display; encrypted at rest as one JSON blob.
    public var items: [TemplateItem]
    public let createdBy: String
    public let createdAt: Date
    public var updatedAt: Date?

    public init(
        id: String, householdId: String, title: String, items: [TemplateItem] = [],
        createdBy: String, createdAt: Date, updatedAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.title = title
        self.items = items
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Doc fields only. `title` and `items` are replaced with ciphertext by the
    /// repository before the write — never call this and write it raw.
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

/// One line of a template. Deliberately not `Identifiable` and deliberately
/// without a document id: these are values inside a template, not rows anyone
/// can address, tick or reorder independently.
public struct TemplateItem: Equatable, Sendable, Codable {
    public var title: String
    public var quantity: String?

    public init(title: String, quantity: String? = nil) {
        self.title = title
        self.quantity = quantity
    }
}

extension ChecklistTemplate {
    /// The items blob, as it is stored: JSON, then encrypted by the caller.
    ///
    /// JSON rather than a Firestore array so the whole list is a single
    /// ciphertext. An array of maps would leave every quantity, and the item
    /// count, readable on the server.
    public static func encodeItems(_ items: [TemplateItem]) throws -> String {
        let data = try JSONEncoder().encode(items)
        guard let s = String(data: data, encoding: .utf8) else {
            throw TemplateCodingError.notUTF8
        }
        return s
    }

    /// Lenient on purpose: a template that cannot be decoded should show up
    /// empty and be deletable, not crash the Checklists tab.
    public static func decodeItems(_ json: String) -> [TemplateItem] {
        guard let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([TemplateItem].self, from: data)
        else { return [] }
        return items
    }
}


/// `PacelliError` lives in the app target, not the Kit, so the Kit carries its
/// own — the same shape as `PacelliCryptoError` and `FeedbackSealError`.
public enum TemplateCodingError: Error, Equatable {
    case notUTF8
}
