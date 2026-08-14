import Foundation

/// Reading a field that is mid-migration from plaintext to ciphertext.
///
/// ## Why this exists
///
/// `checklist_items.quantity` and `plan_checklist_items.quantity` were written
/// in the clear by every port from the original Dart schema onwards. Encrypting
/// them going forward is easy; the hard part is the transition, because both
/// forms are live in the same collection at the same time and a reader cannot
/// be told which one it is holding.
///
/// ``PacelliCrypto/decryptNullable(_:key:)`` is no help here — on failure it
/// returns the safe placeholder `"[encrypted]"`, which is right for a field
/// that is *supposed* to be ciphertext and wrong for one that may legitimately
/// still be plaintext. Feeding it a pre-migration `"2"` would show the user
/// `[encrypted]` where their quantity used to be.
///
/// ## The three-way split
///
/// Guessing "did this decrypt?" is not enough, because the failure modes are
/// not equivalent. A value that is not ciphertext at all is legacy plaintext
/// and must be shown as-is and rewritten. A value that *is* a well-formed
/// Pacelli envelope but will not open is corruption or a wrong key, and must
/// NOT be rewritten — re-encrypting it would encrypt the ciphertext, destroying
/// the original beyond recovery. So the envelope is inspected structurally
/// before any decision is made:
///
/// - opens cleanly            → `.decrypted`, nothing to do
/// - not a valid envelope     → `.legacyPlaintext`, show raw + schedule rewrite
/// - valid envelope, won't open → `.undecryptable`, show placeholder, never write
///
/// The structural test is cheap and safe for this field: a Pacelli envelope is
/// `base64(16-byte IV || AES-CBC blocks)`, so it decodes to at least 32 bytes
/// with a whole number of 16-byte blocks after the IV. Real quantities — `"2"`,
/// `"500g"`, `"2 dozen"` — are far too short to clear that bar even when they
/// happen to be valid base64.
extension PacelliCrypto {

    /// The state of one mid-migration field.
    public enum MigratingField: Equatable, Sendable {
        /// Ciphertext that opened. The associated value is the plaintext.
        case decrypted(String)
        /// Not a Pacelli envelope — pre-migration plaintext, safe to rewrite.
        case legacyPlaintext(String)
        /// A well-formed envelope that will not open. Do not rewrite.
        case undecryptable
        /// The field was nil or empty.
        case absent

        /// What to show the user.
        public var displayValue: String? {
            switch self {
            case .decrypted(let s), .legacyPlaintext(let s): return s
            case .undecryptable: return "[encrypted]"
            case .absent: return nil
            }
        }

        /// True only for values that must be rewritten as ciphertext.
        public var needsMigration: Bool {
            if case .legacyPlaintext = self { return true }
            return false
        }
    }

    /// Classifies a stored field that may be either ciphertext or pre-migration
    /// plaintext. See ``MigratingField`` for why this is three-way and not a
    /// simple `try?`.
    public static func readMigrating(_ stored: String?, key: String) -> MigratingField {
        guard let stored, !stored.isEmpty else { return .absent }
        if let plaintext = try? decrypt(stored, key: key) {
            return .decrypted(plaintext)
        }
        return looksLikeEnvelope(stored) ? .undecryptable : .legacyPlaintext(stored)
    }

    /// Structural test for `base64(IV || AES-CBC blocks)`.
    ///
    /// Deliberately strict about length. The whole point is to keep a short
    /// human quantity from being mistaken for ciphertext, and the cost of a
    /// false positive here is a value that never gets migrated — annoying. The
    /// cost of a false negative is double encryption — unrecoverable.
    static func looksLikeEnvelope(_ s: String) -> Bool {
        guard let data = Data(base64Encoded: s) else { return false }
        // 16-byte IV + at least one whole 16-byte block.
        guard data.count >= 32 else { return false }
        return (data.count - 16) % 16 == 0
    }
}
