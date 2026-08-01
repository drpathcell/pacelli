import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Household-manual reads/writes. Parity with the Dart repository —
/// `manual_entries/{uuid}` flat docs, encrypted title/content/tags,
/// Firestore **Timestamp** dates (unique to this collection).
/// v1 scope: entries + pin; manual categories deferred.
enum ManualRepository {
    private static var db: Firestore { Firestore.firestore() }
    private static var uid: String? { Auth.auth().currentUser?.uid }

    /// All entries, pinned first then most-recently-updated.
    static func fetchEntries(householdId: String) async throws -> [ManualEntry] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let snap = try await db.collection("manual_entries")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()

        return snap.documents
            .compactMap { doc -> ManualEntry? in
                var data = doc.data()
                if let t = data["title"] as? String {
                    data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
                }
                if let c = data["content"] as? String {
                    data["content"] = PacelliCrypto.decryptNullable(c, key: key) ?? c
                }
                if let tags = data["tags"] as? [String] {
                    data["tags"] = tags.map {
                        PacelliCrypto.decryptNullable($0, key: key) ?? $0
                    }
                }
                // Timestamp → Date (this collection alone uses Timestamps).
                if let ts = data["created_at"] as? Timestamp {
                    data["created_at"] = ts.dateValue()
                }
                if let ts = data["updated_at"] as? Timestamp {
                    data["updated_at"] = ts.dateValue()
                }
                return ManualEntry(map: data)
            }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                return $0.updatedAt > $1.updatedAt
            }
    }

    /// Mirrors Dart `createManualEntry` doc shape.
    static func createEntry(
        householdId: String, title: String, content: String = "",
        isPinned: Bool = false
    ) async throws -> ManualEntry {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let now = Date()
        let entry = ManualEntry(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            title: title,
            content: content,
            isPinned: isPinned,
            createdBy: uid,
            createdAt: now,
            updatedAt: now,
            lastEditedBy: uid)

        try await db.collection("manual_entries").document(entry.id).setData([
            "id": entry.id,
            "household_id": householdId,
            "title": try PacelliCrypto.encrypt(title, key: key),
            "content": try PacelliCrypto.encrypt(content, key: key),
            "category_id": NSNull(),
            "tags": [],
            "is_pinned": isPinned,
            "created_by": uid,
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "last_edited_by": uid,
        ])
        return entry
    }

    /// Partial update. Mirrors Dart `updateManualEntry`.
    static func updateEntry(
        _ entry: ManualEntry, title: String? = nil, content: String? = nil,
        isPinned: Bool? = nil
    ) async throws {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(entry.householdId)
        else { throw PacelliError.missingHouseholdKey }
        var updates: [String: Any] = [
            "updated_at": Timestamp(date: Date()),
            "last_edited_by": uid,
        ]
        if let title { updates["title"] = try PacelliCrypto.encrypt(title, key: key) }
        if let content {
            updates["content"] = try PacelliCrypto.encrypt(content, key: key)
        }
        if let isPinned { updates["is_pinned"] = isPinned }
        try await db.collection("manual_entries").document(entry.id).updateData(updates)
    }

    /// Mirrors Dart `deleteManualEntry`.
    static func deleteEntry(_ entry: ManualEntry) async throws {
        try await db.collection("manual_entries").document(entry.id).delete()
    }
}

/// Feedback submission. Parity with Dart `feedback_service.dart` —
/// `feedback/{uuid}`, encrypted message/context (plaintext fallback when no
/// key, Dart parity), ISO dates. Submit-only in the app; entries are read
/// by the developer, not the UI.
enum FeedbackRepository {
    private static var db: Firestore { Firestore.firestore() }

    enum FeedbackType: String, CaseIterable, Identifiable {
        case general, bug
        case featureRequest

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .general: String(localized: "General")
            case .bug: String(localized: "Bug report")
            case .featureRequest: String(localized: "Feature request")
            }
        }
    }

    enum FeedbackRating: String, CaseIterable, Identifiable {
        case positive, neutral, negative

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .positive: String(localized: "😊 Good")
            case .neutral: String(localized: "😐 Okay")
            case .negative: String(localized: "🙁 Bad")
            }
        }
    }

    /// Mirrors Dart `submitFeedback` doc shape.
    static func submit(
        householdId: String, type: FeedbackType, rating: FeedbackRating,
        message: String
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw PacelliError.notSignedIn
        }
        let key = await KeyManager.shared.loadHouseholdKey(householdId)
        let encryptedMessage =
            key.flatMap { try? PacelliCrypto.encrypt(message, key: $0) } ?? message

        let id = UUID().uuidString.lowercased()
        try await db.collection("feedback").document(id).setData([
            "id": id,
            "household_id": householdId,
            "type": type.rawValue,
            "rating": rating.rawValue,
            "message": encryptedMessage,
            "context": NSNull(),
            "created_by": uid,
            "created_at": DartISO8601.string(from: Date()),
        ])
    }
}
