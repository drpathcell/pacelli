import FirebaseFirestore
import Foundation
import PacelliKit

/// Reading photo documents and opening the encrypted fields on them.
///
/// The thumbnail is decrypted here, which is why a grid renders with no Storage
/// traffic at all: everything a list needs is inside the document it already
/// fetched.
enum PhotosRepository {

    private static var db: Firestore { Firestore.firestore() }

    private static func decoded(
        _ doc: QueryDocumentSnapshot, key: String?
    ) -> Photo? {
        var data = doc.data()
        data["id"] = doc.documentID
        if let key {
            // The stored thumbnail is base64 of `iv || ciphertext`. It goes
            // through the BYTE path — a thumbnail is JPEG, not text, and the
            // string overload would try to read it as UTF-8 and fail.
            if let thumb = data["thumb"] as? String,
               let sealed = Data(base64Encoded: thumb),
               let opened = try? PacelliCrypto.decrypt(sealed, key: key) {
                // Re-base64 so the model's map reader stays uniform; it holds
                // no key and does no crypto of its own.
                data["thumb"] = opened.base64EncodedString()
            } else {
                data["thumb"] = nil
            }
            data["caption"] = PacelliCrypto.decryptNullable(
                data["caption"] as? String, key: key)
            data["recognised_text"] = PacelliCrypto.decryptNullable(
                data["recognised_text"] as? String, key: key)
            data["labels"] = PacelliCrypto.decryptNullable(
                data["labels"] as? String, key: key)
        }
        return Photo(map: data)
    }

    /// Every photo on one item.
    static func fetch(subjectId: String, householdId: String) async throws -> [Photo] {
        let key = await KeyManager.shared.loadHouseholdKey(householdId)
        let snap = try await db.collection("photos")
            .whereField("household_id", isEqualTo: householdId)
            .whereField("subject_id", isEqualTo: subjectId)
            .getDocuments()
        return snap.documents
            .compactMap { decoded($0, key: key) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// How many photos each of several items has, in one query.
    ///
    /// A list screen needs a badge per row, and a query per row would be
    /// absurd. `household_id` alone is cheap and the household's photo count is
    /// small; filtering happens here.
    static func counts(
        forSubjectIds ids: Set<String>, householdId: String
    ) async throws -> [String: Int] {
        guard !ids.isEmpty else { return [:] }
        let snap = try await db.collection("photos")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()
        var counts: [String: Int] = [:]
        for doc in snap.documents {
            guard let sid = doc.data()["subject_id"] as? String, ids.contains(sid)
            else { continue }
            counts[sid, default: 0] += 1
        }
        return counts
    }

    /// The whole household, newest first — the gallery.
    static func fetchAll(householdId: String) async throws -> [Photo] {
        let key = await KeyManager.shared.loadHouseholdKey(householdId)
        let snap = try await db.collection("photos")
            .whereField("household_id", isEqualTo: householdId)
            .order(by: "created_at", descending: true)
            .getDocuments()
        return snap.documents.compactMap { decoded($0, key: key) }
    }

    /// Ids of every photo the household still has, for the local reconcile.
    static func liveIds(householdId: String) async throws -> Set<String> {
        let snap = try await db.collection("photos")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()
        return Set(snap.documents.map(\.documentID))
    }

    static func setCaption(_ caption: String?, photoId: String, householdId: String) async throws {
        let key = await KeyManager.shared.loadHouseholdKey(householdId)
        let value = (caption?.isEmpty == false)
            ? try PacelliCrypto.encryptNullable(caption, key: key ?? "")
            : nil
        try await db.collection("photos").document(photoId)
            .updateData(["caption": value as Any])
    }

    static func setCategory(_ categoryId: String?, photoId: String) async throws {
        try await db.collection("photos").document(photoId)
            .updateData(["category_id": categoryId as Any])
    }
}
