import CryptoKit
import Foundation

/// Errors thrown by ``FeedbackSeal``.
public enum FeedbackSealError: Error, Equatable {
    case invalidPublicKey
    case invalidPrivateKey
    case malformedEnvelope
    case wrongVersion(String)
}

/// One-way sealed envelope for user feedback.
///
/// Feedback is the one thing in Pacelli a user deliberately sends *to us*, so
/// it cannot use the household key: that key is generated on the sender's
/// device and never leaves their Keychain. Encrypting feedback with it — which
/// is what shipped from the Flutter days until 2026-08-11 — produces
/// ciphertext nobody alive can read. Four such messages sat unreadable in
/// Firestore before this was found.
///
/// So feedback is sealed to a Pacelli **public** key baked into the app. The
/// matching private key never ships and lives only on the maintainer's
/// machine, which means:
///
/// - the app can seal but can never unseal — a stolen binary reveals nothing;
/// - a Firestore breach yields ciphertext, so the E2E promise still holds;
/// - `scripts/read_feedback.py` reads it, and nothing else can.
///
/// ## Wire format
///
/// ```text
/// "pfb1:" || base64( ephemeralPublicKey[32] || nonce[12] || ciphertext || tag[16] )
/// ```
///
/// X25519 ECDH to an ephemeral key, HKDF-SHA256 to a 256-bit AES key, then
/// AES-256-GCM. The ephemeral key is fresh per message, so two identical
/// messages produce unrelated ciphertexts and nothing links one sender's
/// submissions to another's.
///
/// The `pfb1:` prefix is not decoration: the reader uses it to tell a sealed
/// envelope from the legacy household-key ciphertext and report the old ones
/// as unreadable rather than silently skipping them.
public enum FeedbackSeal {

    /// Version tag and wire prefix. Bump both together if the format changes.
    public static let prefix = "pfb1:"

    /// Bound into HKDF so a blob sealed for feedback cannot be replayed as any
    /// other Pacelli payload, even with the same key.
    private static let info = Data("pacelli-feedback-v1".utf8)

    /// Seal UTF-8 `plaintext` to `publicKeyBase64` (raw 32-byte X25519 key).
    public static func seal(_ plaintext: String, to publicKeyBase64: String) throws -> String {
        guard let keyData = Data(base64Encoded: publicKeyBase64),
            let recipient = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: keyData)
        else { throw FeedbackSealError.invalidPublicKey }

        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: recipient)
        // Salt is the ephemeral public key rather than a constant: it is unique
        // per message and already on the wire, so the derived key differs for
        // every submission without needing an extra field.
        let ephemeralPublic = ephemeral.publicKey.rawRepresentation
        let key = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: ephemeralPublic,
            sharedInfo: info, outputByteCount: 32)

        let sealedBox = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        // `combined` is nonce || ciphertext || tag. Non-nil for the default
        // 12-byte nonce, but this must not force-unwrap on a crypto path.
        guard let combined = sealedBox.combined else {
            throw FeedbackSealError.malformedEnvelope
        }
        return prefix + (ephemeralPublic + combined).base64EncodedString()
    }

    /// True when `value` looks like a sealed envelope rather than legacy
    /// household-key ciphertext.
    public static func isSealed(_ value: String) -> Bool { value.hasPrefix(prefix) }

    /// Unseal with the raw 32-byte X25519 private key.
    ///
    /// The app never calls this — it has no private key. It exists so the
    /// format is covered by round-trip tests rather than only by the Python
    /// reader, and so a broken seal fails in CI instead of in Firestore.
    public static func open(_ envelope: String, privateKeyBase64: String) throws -> String {
        guard envelope.hasPrefix(prefix) else {
            throw FeedbackSealError.wrongVersion(String(envelope.prefix(8)))
        }
        guard let keyData = Data(base64Encoded: privateKeyBase64),
            let recipient = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
        else { throw FeedbackSealError.invalidPrivateKey }

        guard let blob = Data(base64Encoded: String(envelope.dropFirst(prefix.count))),
            blob.count > 32 + 12 + 16
        else { throw FeedbackSealError.malformedEnvelope }

        let ephemeralPublic = blob.prefix(32)
        let combined = blob.dropFirst(32)
        guard
            let sender = try? Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: ephemeralPublic)
        else { throw FeedbackSealError.malformedEnvelope }

        let shared = try recipient.sharedSecretFromKeyAgreement(with: sender)
        let key = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: ephemeralPublic,
            sharedInfo: info, outputByteCount: 32)

        let box = try AES.GCM.SealedBox(combined: combined)
        let plaintext = try AES.GCM.open(box, using: key)
        guard let text = String(data: plaintext, encoding: .utf8) else {
            throw FeedbackSealError.malformedEnvelope
        }
        return text
    }
}
