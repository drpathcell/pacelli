import Foundation
import Testing

@testable import PacelliKit

/// Cross-language vectors for the feedback envelope.
///
/// Swift seals it; `scripts/read_feedback.py` has to open it. Both sides
/// derive their AES key with HKDF-SHA256 — CryptoKit's
/// `hkdfDerivedSymmetricKey` on one side, `cryptography`'s `HKDF` on the other
/// — and "these two surely agree" is exactly the kind of assumption that
/// produces feedback nobody can read. So Swift writes vectors here and
/// `scripts/check_feedback_crypto.py` opens them in CI.
///
/// Regenerate after any change to the format:
///
///     PACELLI_WRITE_FEEDBACK_VECTORS=1 swift test --filter "Feedback vectors"
///     python3 scripts/check_feedback_crypto.py
@Suite("Feedback vectors (cross-language)")
struct FeedbackSealVectorTests {

    /// Same walk `CryptoVectorTests` uses: filename + 5 dirs → repo root.
    private static let dir: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("functions/tests/cross-language")
    }()

    private struct TestKey: Decodable {
        let public_key_b64: String
        let private_key_b64: String
    }

    private func testKey() throws -> TestKey {
        let url = Self.dir.appendingPathComponent("feedback_seal_testkey.json")
        return try JSONDecoder().decode(TestKey.self, from: Data(contentsOf: url))
    }

    /// The payloads worth pinning: a plain one, one with the awkward
    /// characters real feedback actually contains, and an empty message.
    private static let plaintexts = [
        #"{"message":"the join code screen is confusing","email":null,"app_version":"1.3.0 (39)","os":"iOS 26.2","locale":"en_IE","is_guest":true}"#,
        #"{"message":"crashed 🙁 when I tapped Save\nevery time","email":"someone@example.com","app_version":"1.3.0 (39)","os":"iOS 26.2","locale":"it_IT","is_guest":false}"#,
        #"{"message":"","email":null,"app_version":"1.3.0 (39)","os":"iOS 26.2","locale":"es_ES","is_guest":true}"#,
    ]

    @Test("seals and re-opens with the shared test key")
    func roundTripWithSharedKey() throws {
        let key = try testKey()
        for text in Self.plaintexts {
            let sealed = try FeedbackSeal.seal(text, to: key.public_key_b64)
            #expect(try FeedbackSeal.open(sealed, privateKeyBase64: key.private_key_b64) == text)
        }
    }

    @Test("writes vectors for the Python side when asked")
    func writeVectors() throws {
        guard ProcessInfo.processInfo.environment["PACELLI_WRITE_FEEDBACK_VECTORS"] != nil
        else { return }  // opt-in: normal runs must not rewrite checked-in files

        let key = try testKey()
        let vectors = try Self.plaintexts.map { text in
            ["plaintext": text, "sealed": try FeedbackSeal.seal(text, to: key.public_key_b64)]
        }
        let doc: [String: Any] = [
            "_comment": "Produced by Swift (CryptoKit). scripts/check_feedback_crypto.py must "
                + "open every one. Regenerate with PACELLI_WRITE_FEEDBACK_VECTORS=1 swift test.",
            "format": FeedbackSeal.prefix,
            "vectors": vectors,
        ]
        try JSONSerialization
            .data(withJSONObject: doc, options: [.prettyPrinted, .sortedKeys])
            .write(to: Self.dir.appendingPathComponent("feedback_seal_vectors.json"))
    }

    /// If the checked-in vectors ever stop opening in Swift, the format changed
    /// under us and the Python reader is about to break too.
    @Test("checked-in vectors still open")
    func checkedInVectorsOpen() throws {
        let url = Self.dir.appendingPathComponent("feedback_seal_vectors.json")
        guard let data = try? Data(contentsOf: url) else { return }  // not generated yet
        let key = try testKey()
        let doc = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let vectors = doc["vectors"] as! [[String: String]]
        #expect(!vectors.isEmpty)
        for v in vectors {
            #expect(try FeedbackSeal.open(v["sealed"]!, privateKeyBase64: key.private_key_b64)
                == v["plaintext"]!)
        }
    }
}
