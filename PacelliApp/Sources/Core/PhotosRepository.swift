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

    /// Every photo on one item, live — a stream that yields again whenever the
    /// household's copy of that item changes.
    ///
    /// This is the app's FIRST Firestore snapshot listener. Every other read in
    /// Pacelli is a one-shot `getDocuments` into `@State` on appear, which is
    /// exactly why an open screen never learned that an upload had finished:
    /// `PhotoService.attach` writes the document BEFORE uploading the object
    /// and flips `upload_state` to `.ready` afterwards, so the "arriving" badge
    /// sat there until the view was torn down and rebuilt. The same blindness
    /// hid every photo the OTHER phone added while you were looking at the item.
    ///
    /// Two things about the shape, both learned the hard way elsewhere in this
    /// file:
    ///
    /// 1. The household key is loaded ONCE, before the listener is registered.
    ///    `decoded` needs it and the snapshot callback is synchronous, so
    ///    reaching into `KeyManager` from inside would mean hopping out to
    ///    await and coming back — by which time a newer snapshot can already
    ///    have overtaken the one being decoded, and the strip would flicker
    ///    backwards.
    /// 2. `onTermination` removes the registration. An `AsyncStream` consumed
    ///    by `.task` ends when the view goes away, so the listener's lifetime
    ///    is the view's without anyone having to remember `deinit`.
    ///
    /// Two equality filters and no `orderBy`, sorted here — deliberately the
    /// same query `fetch` already makes. Adding an `orderBy` would need a
    /// composite index, and a missing one of those is how `tasksList` returned
    /// HTTP 500 from the day the REST API shipped.
    static func observe(
        subjectId: String, householdId: String
    ) async -> AsyncStream<[Photo]> {
        let key = await KeyManager.shared.loadHouseholdKey(householdId)
        let query = db.collection("photos")
            .whereField("household_id", isEqualTo: householdId)
            .whereField("subject_id", isEqualTo: subjectId)

        return AsyncStream { continuation in
            let box = ListenerBox()
            box.registration = query.addSnapshotListener { snap, error in
                // A listener error is almost always a permission change or a
                // sign-out mid-flight. Yielding nothing leaves the last good
                // snapshot on screen, which beats blanking the strip.
                guard let snap, error == nil else { return }
                continuation.yield(
                    snap.documents
                        .compactMap { decoded($0, key: key) }
                        .sorted { $0.createdAt < $1.createdAt })
            }
            continuation.onTermination = { _ in box.remove() }
        }
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

// MARK: - Provenance

extension PhotosRepository {

    /// What a photo is a picture *of*, in the words the household used.
    ///
    /// The gallery's whole value is this line under each thumbnail: not a
    /// filename or a date, but "Oat milk, blue lid — Checklist · Kitchen". It
    /// costs three queries for the entire household, which is cheaper than one
    /// per photo and small enough not to matter.
    struct Provenance: Sendable {
        let title: String
        let kind: String
    }

    static func provenance(householdId: String) async -> [String: Provenance] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            return [:]
        }
        let db = Firestore.firestore()
        var out: [String: Provenance] = [:]

        func harvest(_ collection: String, kind: String) async {
            guard let snap = try? await db.collection(collection)
                .whereField("household_id", isEqualTo: householdId)
                .getDocuments()
            else { return }
            for doc in snap.documents {
                let title = PacelliCrypto.decryptNullable(
                    doc.data()["title"] as? String, key: key) ?? ""
                out[doc.documentID] = Provenance(title: title, kind: kind)
            }
        }

        await harvest("tasks", kind: String(localized: "Task"))
        await harvest("subtasks", kind: String(localized: "Subtask"))
        await harvest("checklist_items", kind: String(localized: "Checklist"))
        return out
    }
}

// MARK: - Listener lifetime

/// Carries a `ListenerRegistration` across an `@Sendable` boundary.
///
/// `AsyncStream`'s `onTermination` is `@Sendable` and Firestore's
/// `ListenerRegistration` is not `Sendable`, so the registration cannot simply
/// be captured — Swift 6 strict concurrency rejects it, and it is right to:
/// nothing in the type says which thread may call `remove()`.
///
/// `@unchecked` is the claim being made, so it is worth stating plainly.
/// Firestore delivers snapshots on the main queue by default, the box is
/// created and filled on the caller's turn before any snapshot can arrive, and
/// `remove()` is called exactly once from `onTermination`. That is the whole
/// contract; anything that widens it — a background callback queue, a second
/// removal path — invalidates the annotation rather than merely bending it.
private final class ListenerBox: @unchecked Sendable {
    var registration: ListenerRegistration?

    func remove() {
        registration?.remove()
        registration = nil
    }
}
