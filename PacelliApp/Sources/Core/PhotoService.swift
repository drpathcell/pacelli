import CommonCrypto
import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Attaching a photo, getting it up, and getting it back.
///
/// The ordering here is the feature. The document is written — thumbnail and
/// all — **before** the image is uploaded, which buys three things that would
/// otherwise each need their own machinery:
///
///  1. the other household member sees the picture within a second, on the
///     Firestore listener the app already runs, with no Storage round-trip;
///  2. `upload_state: pending` IS the retry queue. Firestore syncs writes made
///     offline; Cloud Storage does not. Rather than a local outbox that can
///     drift, the app asks Firestore which of its own photos are unfinished;
///  3. a phone lost mid-upload leaves a photo that still shows and still
///     searches. Only the full size is missing, and the app says so.
///
/// Nothing on this path can fail in a way that loses the picture, which is why
/// nothing on it is phrased as an error.
enum PhotoService {

    private static var db: Firestore { Firestore.firestore() }
    private static var uid: String? { Auth.auth().currentUser?.uid }

    struct PhotoError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Attaching

    /// Prepares, stores locally, writes the document, then uploads.
    ///
    /// Returns as soon as the document exists, which is the moment the photo is
    /// visible to everyone. The upload continues in the background; if it
    /// fails, the photo stays `pending` and `resumePending` picks it up.
    @discardableResult
    static func attach(
        imageData: Data,
        to subject: Photo.Subject,
        subjectId: String,
        householdId: String,
        categoryId: String? = nil
    ) async throws -> String {
        guard let uid else { throw PhotoError(message: String(localized: "You need to be signed in.")) }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PhotoError(message: String(localized: "Couldn't unlock this household."))
        }

        let prepared = try ImagePrep.prepare(imageData)
        let photoId = db.collection("photos").document().documentID

        // Local first. If everything after this line fails, the person who took
        // the photo still has it.
        try PhotoStore.write(prepared.jpeg, householdId: householdId, photoId: photoId)

        // `??` takes an autoclosure, and an autoclosure is not async — so the
        // inference has to happen in a statement rather than a fallback chain.
        var category = categoryId
        if category == nil {
            category = try? await inferCategory(
                for: subject, subjectId: subjectId, householdId: householdId)
        }

        var doc: [String: Any] = [
            "id": photoId,
            "household_id": householdId,
            "subject_type": subject.rawValue,
            "subject_id": subjectId,
            "upload_state": Photo.UploadState.pending.rawValue,
            "thumb": try PacelliCrypto.encrypt(prepared.thumbnailJPEG, key: key)
                .base64EncodedString(),
            "content_hash": Hashing.sha256Hex(prepared.jpeg),
            "width": prepared.width,
            "height": prepared.height,
            "byte_size": prepared.jpeg.count,
            "created_by": uid,
            "created_at": DartISO8601.string(from: Date()),
        ]
        if let category { doc["category_id"] = category }

        try await db.collection("photos").document(photoId).setData(doc)

        // Deliberately not awaited by the caller's UI path.
        Task.detached(priority: .utility) {
            try? await upload(photoId: photoId, householdId: householdId)
        }
        return photoId
    }

    /// Uploads one already-documented photo and flips it to `ready`.
    static func upload(photoId: String, householdId: String) async throws {
        guard let jpeg = PhotoStore.read(householdId: householdId, photoId: photoId) else {
            // The local original is gone and this photo never uploaded, so
            // there is nothing left to send. The thumbnail still works.
            throw PhotoError(message: String(localized: "That photo is no longer on this device."))
        }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PhotoError(message: String(localized: "Couldn't unlock this household."))
        }

        let sealed = try PacelliCrypto.encrypt(jpeg, key: key)
        let minted = try await FunctionsClient.postObject(
            "photoUploadUrl", body: ["photoId": photoId])
        guard let urlString = minted["url"] as? String, let url = URL(string: urlString) else {
            throw PhotoError(message: String(localized: "Couldn't start the upload."))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(
            minted["contentType"] as? String ?? "application/octet-stream",
            forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(for: request, from: sealed)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw PhotoError(message: String(localized: "The upload didn't finish (\(status))."))
        }

        try await db.collection("photos").document(photoId).updateData([
            "upload_state": Photo.UploadState.ready.rawValue,
            "byte_size": sealed.count,
        ])
    }

    /// Finishes anything this device started and did not send.
    ///
    /// Called at launch and when the app comes back to the foreground. Only
    /// photos this device took can be resumed — nobody else holds the plaintext
    /// — so the query is scoped to our own uid.
    static func resumePending(householdId: String) async {
        guard let uid else { return }
        let snap = try? await db.collection("photos")
            .whereField("household_id", isEqualTo: householdId)
            .whereField("subject_id", isNotEqualTo: "")
            .getDocuments()
        guard let snap else { return }

        for doc in snap.documents {
            let d = doc.data()
            guard d["upload_state"] as? String == Photo.UploadState.pending.rawValue,
                  d["created_by"] as? String == uid,
                  PhotoStore.has(householdId: householdId, photoId: doc.documentID)
            else { continue }
            try? await upload(photoId: doc.documentID, householdId: householdId)
        }
    }

    // MARK: - Reading

    /// The full image, from disk if it is here and from Storage if it is not.
    ///
    /// A miss is normal, not an error: the local file is a cache, and the
    /// encrypted object is the durable copy.
    static func fullImage(photoId: String, householdId: String) async throws -> Data {
        if let local = PhotoStore.read(householdId: householdId, photoId: photoId) {
            return local
        }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PhotoError(message: String(localized: "Couldn't unlock this household."))
        }

        let minted = try await FunctionsClient.postObject(
            "photoDownloadUrl", body: ["photoId": photoId])
        guard let urlString = minted["url"] as? String, let url = URL(string: urlString) else {
            throw PhotoError(message: String(localized: "Couldn't fetch that photo."))
        }

        let (sealed, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw PhotoError(message: String(localized: "Couldn't fetch that photo (\(status))."))
        }

        let jpeg = try PacelliCrypto.decrypt(sealed, key: key)
        try? PhotoStore.write(jpeg, householdId: householdId, photoId: photoId)
        return jpeg
    }

    /// Pulls the full size of recent photos so that tapping one is instant.
    /// Best-effort and silent — this is a convenience, not a correctness path.
    static func prefetch(_ photos: [Photo], householdId: String, limit: Int = 25) async {
        for photo in photos.prefix(limit)
        where photo.uploadState == .ready
            && !PhotoStore.has(householdId: householdId, photoId: photo.id) {
            _ = try? await fullImage(photoId: photo.id, householdId: householdId)
        }
    }

    // MARK: - Deleting

    /// Deletes the document; the Cloud Storage object goes with it via the
    /// `onPhotoDeleted` trigger. Nothing here needs to know Storage exists.
    static func delete(photoId: String, householdId: String) async throws {
        try await db.collection("photos").document(photoId).delete()
        PhotoStore.delete(householdId: householdId, photoId: photoId)
    }

    // MARK: - Category inference

    /// Works out where a photo belongs without asking.
    ///
    /// Tasks carry a category already. Checklist items do not, and neither do
    /// checklists, so the next best signal is what the household filed the last
    /// photo on this checklist under. Getting it wrong is cheap — the gallery
    /// re-files in one tap — and stopping to ask at the shutter is not.
    private static func inferCategory(
        for subject: Photo.Subject, subjectId: String, householdId: String
    ) async throws -> String? {
        switch subject {
        case .task:
            let doc = try await db.collection("tasks").document(subjectId).getDocument()
            return doc.data()?["category_id"] as? String

        case .subtask:
            let sub = try await db.collection("subtasks").document(subjectId).getDocument()
            guard let taskId = sub.data()?["task_id"] as? String else { return nil }
            let task = try await db.collection("tasks").document(taskId).getDocument()
            return task.data()?["category_id"] as? String

        case .checklistItem:
            let item = try await db.collection("checklist_items")
                .document(subjectId).getDocument()
            guard let checklistId = item.data()?["checklist_id"] as? String else { return nil }

            // Whatever the last photo on this checklist was filed under.
            let siblings = try await db.collection("photos")
                .whereField("household_id", isEqualTo: householdId)
                .whereField("subject_type", isEqualTo: Photo.Subject.checklistItem.rawValue)
                .getDocuments()

            let itemIds = try await db.collection("checklist_items")
                .whereField("household_id", isEqualTo: householdId)
                .whereField("checklist_id", isEqualTo: checklistId)
                .getDocuments()
                .documents.map(\.documentID)
            let inThisChecklist = Set(itemIds)

            let recent = siblings.documents
                .filter { inThisChecklist.contains($0.data()["subject_id"] as? String ?? "") }
                .compactMap { doc -> (Date, String)? in
                    guard let cat = doc.data()["category_id"] as? String,
                          let at = DartISO8601.date(from: doc.data()["created_at"] as? String)
                    else { return nil }
                    return (at, cat)
                }
                .max(by: { $0.0 < $1.0 })

            return recent?.1
        }
    }
}

/// SHA-256 without pulling CryptoKit into every call site.
enum Hashing {
    static func sha256Hex(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buf in
            _ = CC_SHA256(buf.baseAddress, CC_LONG(buf.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
