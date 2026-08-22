import Foundation

/// A picture attached to something. Firestore doc: `photos/{id}`.
///
/// The document is the small half of a photo. The image itself is an encrypted
/// object in Cloud Storage that no client can reach directly; what lives here
/// is metadata, an encrypted thumbnail of a few kilobytes, and the encrypted
/// text Vision read on the device.
///
/// **The thumbnail is in the document on purpose.** It rides the same live
/// Firestore listener the app already uses for tasks, so the other household
/// member sees the picture within a second of the shutter — before the upload
/// of the real one has finished, and without a single Storage round-trip.
/// Everything about how this feature feels comes from that one decision.
public struct Photo: Identifiable, Equatable, Sendable {

    /// What a photo can hang off. Stored as a string so a fourth kind is
    /// additive rather than a migration.
    public enum Subject: String, Sendable, CaseIterable {
        case task
        case subtask
        case checklistItem = "checklist_item"
    }

    /// Where the image itself has got to.
    public enum UploadState: String, Sendable {
        /// The document exists and the thumbnail works; the full image is
        /// still on its way up from the device that took it.
        case pending
        case ready
        /// Fourteen days pending. The device that took it is not coming back,
        /// so the app stops saying "arriving" and says what is true. Only the
        /// full size is gone — the thumbnail still works, and so does search.
        case stranded
    }

    public let id: String
    public let householdId: String
    public let subjectType: Subject
    public let subjectId: String
    /// The place tag. Inferred at capture, never asked for.
    public var categoryId: String?
    public var uploadState: UploadState

    /// Decrypted for display; encrypted at rest. Base64 JPEG bytes.
    public var thumbnail: Data?
    /// Decrypted for display; encrypted at rest.
    public var caption: String?
    /// Vision OCR output, decrypted. Never leaves a device unencrypted.
    public var recognisedText: String?
    /// Vision labels as a JSON array string, decrypted.
    public var labels: String?

    public let contentHash: String?
    public let width: Int?
    public let height: Int?
    public let byteSize: Int?
    public let createdBy: String
    public let createdAt: Date

    public init(
        id: String, householdId: String, subjectType: Subject, subjectId: String,
        categoryId: String? = nil, uploadState: UploadState = .pending,
        thumbnail: Data? = nil, caption: String? = nil,
        recognisedText: String? = nil, labels: String? = nil,
        contentHash: String? = nil, width: Int? = nil, height: Int? = nil,
        byteSize: Int? = nil, createdBy: String, createdAt: Date
    ) {
        self.id = id
        self.householdId = householdId
        self.subjectType = subjectType
        self.subjectId = subjectId
        self.categoryId = categoryId
        self.uploadState = uploadState
        self.thumbnail = thumbnail
        self.caption = caption
        self.recognisedText = recognisedText
        self.labels = labels
        self.contentHash = contentHash
        self.width = width
        self.height = height
        self.byteSize = byteSize
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    /// Everything a search can match on, already decrypted. Deliberately
    /// includes the caption the person typed AND what the phone read, because
    /// a result that only matched machine-read text is confusing without it.
    public var searchableText: String {
        [caption, recognisedText, labels]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    /// Reads a Firestore map whose encrypted fields have ALREADY been opened
    /// by the repository. Nothing in PacelliKit's model layer holds a key.
    public init?(map: [String: Any]) {
        guard
            let id = map["id"] as? String ?? map["__id"] as? String,
            let householdId = map["household_id"] as? String,
            let subjectId = map["subject_id"] as? String,
            let subject = Subject(rawValue: map["subject_type"] as? String ?? "")
        else { return nil }

        self.init(
            id: id,
            householdId: householdId,
            subjectType: subject,
            subjectId: subjectId,
            categoryId: map["category_id"] as? String,
            uploadState: UploadState(rawValue: map["upload_state"] as? String ?? "")
                ?? .ready,
            thumbnail: (map["thumb"] as? String).flatMap { Data(base64Encoded: $0) },
            caption: map["caption"] as? String,
            recognisedText: map["recognised_text"] as? String,
            labels: map["labels"] as? String,
            contentHash: map["content_hash"] as? String,
            width: map["width"] as? Int,
            height: map["height"] as? Int,
            byteSize: map["byte_size"] as? Int,
            createdBy: map["created_by"] as? String ?? "",
            createdAt: DartISO8601.date(from: map["created_at"] as? String) ?? Date())
    }
}
