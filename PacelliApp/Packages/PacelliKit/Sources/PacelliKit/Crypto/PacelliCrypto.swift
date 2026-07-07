import CommonCrypto
import CryptoKit
import Foundation

/// Errors thrown by ``PacelliCrypto``.
public enum PacelliCryptoError: Error, Equatable {
    case invalidHexKey
    case invalidBase64
    /// Mirrors Dart: combined payload must be ≥ 17 bytes (16 IV + ≥1 data).
    case ciphertextTooShort
    case invalidUTF8Plaintext
    case cryptOperationFailed(Int32)
}

/// AES-256-CBC end-to-end encryption service for Pacelli.
///
/// **Byte-exact Swift port of `lib/core/crypto/encryption_service.dart`.**
/// Wire format: `base64(iv_16_bytes || ciphertext)`, AES-CBC, PKCS7 padding,
/// keys are 64-char lowercase hex strings (256-bit). Existing Firestore
/// ciphertexts produced by the Dart/TypeScript implementations MUST remain
/// decryptable — validated by `CryptoVectorTests` against the shared
/// cross-language vectors in `functions/tests/cross-language/`.
///
/// What is encrypted: task titles, descriptions, subtask titles, checklist
/// titles/items, plan titles/entries/labels, category names, household name,
/// display name. What is NOT: IDs, status, priority, timestamps, booleans,
/// sort orders, icons, colors (structural metadata needed for queries).
public enum PacelliCrypto {

    // MARK: - Field encryption

    /// Encrypts `plaintext` with AES-256-CBC. Returns `base64(IV || ct)`.
    /// A fresh random IV per call gives semantic security.
    public static func encrypt(_ plaintext: String, key hexKey: String) throws -> String {
        let keyBytes = try keyFromHex(hexKey)
        var iv = [UInt8](repeating: 0, count: 16)
        let rc = SecRandomCopyBytes(kSecRandomDefault, iv.count, &iv)
        precondition(rc == errSecSuccess, "SecRandomCopyBytes failed: \(rc)")
        let ct = try aesCBC(.encrypt, input: Array(plaintext.utf8), key: keyBytes, iv: iv)
        return Data(iv + ct).base64EncodedString()
    }

    /// Decrypts a `base64(IV || ct)` string produced by any Pacelli port.
    public static func decrypt(_ ciphertext: String, key hexKey: String) throws -> String {
        let keyBytes = try keyFromHex(hexKey)
        guard let combined = Data(base64Encoded: ciphertext) else {
            throw PacelliCryptoError.invalidBase64
        }
        guard combined.count >= 17 else { throw PacelliCryptoError.ciphertextTooShort }
        let iv = Array(combined.prefix(16))
        let ct = Array(combined.dropFirst(16))
        let pt = try aesCBC(.decrypt, input: ct, key: keyBytes, iv: iv)
        guard let s = String(bytes: pt, encoding: .utf8) else {
            throw PacelliCryptoError.invalidUTF8Plaintext
        }
        return s
    }

    /// Nil/empty short-circuit — never calls `encrypt` on empty input
    /// (preserves the Dart/PointyCastle-era contract).
    public static func encryptNullable(_ plaintext: String?, key: String) throws -> String? {
        guard let plaintext, !plaintext.isEmpty else { return plaintext }
        return try encrypt(plaintext, key: key)
    }

    /// Nil/empty short-circuit; on any decryption failure returns the safe
    /// placeholder `"[encrypted]"` instead of leaking ciphertext to the UI.
    public static func decryptNullable(_ ciphertext: String?, key: String) -> String? {
        guard let ciphertext, !ciphertext.isEmpty else { return ciphertext }
        return (try? decrypt(ciphertext, key: key)) ?? "[encrypted]"
    }

    // MARK: - Key management

    /// New random 256-bit household key as 64-char lowercase hex.
    public static func generateHouseholdKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let rc = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(rc == errSecSuccess, "SecRandomCopyBytes failed: \(rc)")
        return hexEncode(bytes)
    }

    /// Derives the v2 user key from a Firebase UID (RFC 5869 single block,
    /// implemented with explicit HMACs to mirror the Dart code line-for-line).
    ///
    /// - Extract: `PRK = HMAC-SHA256(key: "pacelli_hkdf_salt_v2", msg: uid)`
    /// - Expand:  `OKM = HMAC-SHA256(key: PRK, msg: "pacelli_e2e_user_key_v2" || 0x01)`
    public static func deriveUserKey(uid: String) -> String {
        let salt = SymmetricKey(data: Data("pacelli_hkdf_salt_v2".utf8))
        let prk = HMAC<SHA256>.authenticationCode(for: Data(uid.utf8), using: salt)
        let expandInput = Data("pacelli_e2e_user_key_v2".utf8) + Data([0x01])
        let okm = HMAC<SHA256>.authenticationCode(
            for: expandInput, using: SymmetricKey(data: Data(prk)))
        return hexEncode(Array(Data(okm)))
    }

    /// Legacy v1 derivation (raw HMAC) — kept for migration only.
    static func deriveUserKeyV1(uid: String) -> String {
        let key = SymmetricKey(data: Data("pacelli_e2e_key_derivation_v1".utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(uid.utf8), using: key)
        return hexEncode(Array(Data(mac)))
    }

    /// Tries the v2 (HKDF) key first, falls back to v1 (raw HMAC).
    public static func decryptKeyWithMigration(encryptedKey: String, uid: String) throws -> String {
        if let v2 = try? decrypt(encryptedKey, key: deriveUserKey(uid: uid)) { return v2 }
        return try decrypt(encryptedKey, key: deriveUserKeyV1(uid: uid))
    }

    /// Wraps the household key with a user key for per-user Firestore storage.
    public static func encryptKeyForUser(_ householdKey: String, userKey: String) throws -> String {
        try encrypt(householdKey, key: userKey)
    }

    /// Unwraps a stored household key with the user's derived key.
    public static func decryptKeyForUser(_ encryptedKey: String, userKey: String) throws -> String {
        try decrypt(encryptedKey, key: userKey)
    }

    // MARK: - Internals

    private enum AESOperation {
        case encrypt, decrypt
        var cc: CCOperation {
            switch self {
            case .encrypt: CCOperation(kCCEncrypt)
            case .decrypt: CCOperation(kCCDecrypt)
            }
        }
    }

    /// One-shot AES-CBC with PKCS7 padding via CommonCrypto
    /// (CryptoKit intentionally offers no CBC; CommonCrypto is the
    /// platform-blessed primitive and validates padding on decrypt).
    private static func aesCBC(
        _ operation: AESOperation, input: [UInt8], key: [UInt8], iv: [UInt8]
    ) throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var moved = 0
        let status = CCCrypt(
            operation.cc, CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
            key, key.count, iv, input, input.count, &out, out.count, &moved)
        guard status == kCCSuccess else {
            throw PacelliCryptoError.cryptOperationFailed(status)
        }
        return Array(out.prefix(moved))
    }

    /// Hex string → bytes. Mirrors Dart `_keyFromString` (2-char pairs).
    private static func keyFromHex(_ hex: String) throws -> [UInt8] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var idx = hex.startIndex
        while idx < hex.endIndex {
            guard let next = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex),
                  let byte = UInt8(hex[idx..<next], radix: 16)
            else { throw PacelliCryptoError.invalidHexKey }
            bytes.append(byte)
            idx = next
        }
        return bytes
    }

    private static func hexEncode(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
