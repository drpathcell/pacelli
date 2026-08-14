import FirebaseFirestore
import Foundation
import PacelliKit

/// Rewrites pre-migration plaintext `quantity` values as ciphertext.
///
/// ## Why lazily, from a read
///
/// The household key never leaves the device — that is the whole point of the
/// encryption — so nothing on the server can perform this migration. It has to
/// run on a client that holds the key, and the only moment a client reliably
/// holds both the key and the affected documents is immediately after a fetch.
/// So the fetch reports what it found and this fires the rewrite behind it.
///
/// The consequence is honest and worth stating: an item nobody ever looks at
/// stays plaintext. Migration coverage tracks usage, not time. In practice a
/// checklist that is never opened is also a checklist whose contents nobody
/// cares about, and the alternative — shipping the household key somewhere it
/// could enumerate every document — trades a small leak for a much larger one.
enum QuantityMigration {

    /// Rewrites `items` as ciphertext. Returns immediately.
    ///
    /// Detached and unawaited on purpose. Someone opening their shopping list
    /// in a supermarket aisle should not wait on a backfill, and a backfill
    /// that fails should not fail their read — the next fetch simply tries
    /// again, because the read path re-derives the work from the data itself
    /// rather than from a stored cursor.
    static func backfill(
        collection: String, items: [(id: String, plaintext: String)], key: String
    ) {
        guard !items.isEmpty else { return }
        Task.detached(priority: .background) {
            let db = Firestore.firestore()
            // Firestore caps a batch at 500 writes; 400 leaves headroom and
            // keeps a single failure from costing the whole set.
            for start in stride(from: 0, to: items.count, by: 400) {
                let chunk = items[start..<min(start + 400, items.count)]
                let batch = db.batch()
                var staged = 0
                for entry in chunk {
                    guard let ciphertext =
                            try? PacelliCrypto.encrypt(entry.plaintext, key: key)
                    else { continue }
                    batch.updateData(
                        ["quantity": ciphertext],
                        forDocument: db.collection(collection).document(entry.id))
                    staged += 1
                }
                guard staged > 0 else { continue }
                // `updateData` on a document deleted between the read and now
                // fails the whole batch. Swallowed deliberately: the item is
                // gone, so there is nothing left to protect, and the next
                // fetch will not re-offer it.
                try? await batch.commit()
            }
        }
    }
}
