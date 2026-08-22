import Foundation
import Testing

@testable import PacelliKit

/// The byte path added in 1.8.0 for photos.
///
/// The point of these is not that AES works — the cross-language vectors
/// already prove that. It is that the string path and the byte path are the
/// SAME path. `encrypt(String:)` is now a thin wrapper, and the day someone
/// "optimises" one of them apart from the other, every existing ciphertext in
/// every household stops opening. These tests are what makes that loud.
@Suite("Blob encryption (photos)")
struct BlobCryptoTests {

    /// A real household key shape: 64 lowercase hex characters.
    private let key = "4f3c2b1a09e8d7c6b5a4938271605f4e3d2c1b0a99887766554433221100ffee"

    @Test("bytes survive a round trip")
    func roundTrip() throws {
        let original = Data((0..<4096).map { UInt8($0 % 251) })
        let sealed = try PacelliCrypto.encrypt(original, key: key)
        #expect(sealed.count > original.count)   // IV + padding
        #expect(try PacelliCrypto.decrypt(sealed, key: key) == original)
    }

    /// A photo is not text. Bytes that are not valid UTF-8 must survive, which
    /// is exactly what the string path could never carry.
    @Test("bytes that are not valid UTF-8 survive")
    func nonUTF8() throws {
        let original = Data([0xFF, 0xFE, 0x00, 0x80, 0xC0, 0xC1, 0xF5, 0xFF])
        let sealed = try PacelliCrypto.encrypt(original, key: key)
        #expect(try PacelliCrypto.decrypt(sealed, key: key) == original)
    }

    /// JPEG magic bytes in, JPEG magic bytes out — the shape a photo actually
    /// has, at roughly the size the importer produces.
    @Test("a photo-sized payload survives")
    func photoSized() throws {
        var jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0])
        jpeg.append(Data((0..<400_000).map { UInt8(($0 &* 7) % 256) }))
        jpeg.append(Data([0xFF, 0xD9]))
        let sealed = try PacelliCrypto.encrypt(jpeg, key: key)
        let opened = try PacelliCrypto.decrypt(sealed, key: key)
        #expect(opened == jpeg)
        #expect(opened.prefix(2) == Data([0xFF, 0xD8]))
    }

    /// The string API must be observably identical to base64 of the byte API.
    /// If this ever fails, one of the two has been changed on its own.
    @Test("the string path is the byte path, base64-wrapped")
    func stringPathIsByteePath() throws {
        let text = "Boiler serial 41A-99. Kitchen. €12,50 — 30°C"
        let viaString = try PacelliCrypto.encrypt(text, key: key)
        let combined = try #require(Data(base64Encoded: viaString))

        // Decrypting the string form's bytes through the BYTE path must give
        // back the original UTF-8.
        let opened = try PacelliCrypto.decrypt(combined, key: key)
        #expect(String(data: opened, encoding: .utf8) == text)

        // And the reverse: bytes sealed by the byte path, base64'd, open
        // through the string path.
        let viaBytes = try PacelliCrypto.encrypt(Data(text.utf8), key: key)
        #expect(try PacelliCrypto.decrypt(viaBytes.base64EncodedString(), key: key) == text)
    }

    @Test("every call uses a fresh IV")
    func freshIV() throws {
        let payload = Data("the same bytes twice".utf8)
        let a = try PacelliCrypto.encrypt(payload, key: key)
        let b = try PacelliCrypto.encrypt(payload, key: key)
        #expect(a != b, "identical ciphertext means a reused IV")
        #expect(a.prefix(16) != b.prefix(16))
        #expect(try PacelliCrypto.decrypt(a, key: key) == payload)
        #expect(try PacelliCrypto.decrypt(b, key: key) == payload)
    }

    /// A truncated download is not a decryptable object, and must not be
    /// mistaken for one.
    @Test("a payload shorter than IV plus one byte is refused")
    func tooShort() {
        for count in 0...16 {
            let stub = Data(repeating: 0x41, count: count)
            #expect(throws: PacelliCryptoError.ciphertextTooShort) {
                try PacelliCrypto.decrypt(stub, key: key)
            }
        }
    }

    @Test("empty input still produces an openable object")
    func emptyInput() throws {
        let sealed = try PacelliCrypto.encrypt(Data(), key: key)
        #expect(sealed.count == 32)  // 16 IV + one PKCS7 padding block
        #expect(try PacelliCrypto.decrypt(sealed, key: key) == Data())
    }

    @Test("the wrong household key cannot open it")
    func wrongKey() throws {
        let other = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
        let sealed = try PacelliCrypto.encrypt(Data("private".utf8), key: key)
        // CBC with PKCS7 usually fails to unpad; when it does not, the bytes
        // are still wrong. Both are acceptable — silently returning the
        // plaintext is not.
        let opened = try? PacelliCrypto.decrypt(sealed, key: other)
        #expect(opened != Data("private".utf8))
    }
}
