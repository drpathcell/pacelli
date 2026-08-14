import Foundation
import Testing

@testable import PacelliKit

/// The classifier that lets `quantity` be read while half the collection is
/// still plaintext.
///
/// The case that matters most here is the one that is easiest to get wrong:
/// a real ciphertext that will not open must NOT be treated as plaintext,
/// because the caller's response to "plaintext" is to encrypt it — and
/// encrypting a ciphertext destroys the original.
@Suite("Mid-migration field reads")
struct FieldMigrationTests {

    let key = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
    let otherKey = "ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100"

    @Test("ciphertext written with the household key opens")
    func decryptsOwnCiphertext() throws {
        let stored = try PacelliCrypto.encrypt("2", key: key)
        let field = PacelliCrypto.readMigrating(stored, key: key)
        #expect(field == .decrypted("2"))
        #expect(field.displayValue == "2")
        #expect(field.needsMigration == false)
    }

    @Test(
        "pre-migration plaintext is shown as-is and flagged for rewrite",
        arguments: ["2", "500g", "2 dozen", "1", "½ punnet", "x3"])
    func passesThroughLegacyPlaintext(_ raw: String) {
        let field = PacelliCrypto.readMigrating(raw, key: key)
        #expect(field == .legacyPlaintext(raw))
        #expect(field.displayValue == raw, "A user's quantity must never render as [encrypted].")
        #expect(field.needsMigration)
    }

    /// The dangerous case. A well-formed envelope that will not open is
    /// corruption or a wrong key — never something to re-encrypt.
    @Test("a valid envelope encrypted with a different key is never rewritten")
    func refusesToRewriteForeignCiphertext() throws {
        let stored = try PacelliCrypto.encrypt("2", key: otherKey)
        let field = PacelliCrypto.readMigrating(stored, key: key)
        #expect(field == .undecryptable)
        #expect(field.displayValue == "[encrypted]")
        #expect(
            field.needsMigration == false,
            """
            Rewriting this would encrypt the ciphertext, and the original
            plaintext would be gone for good.
            """)
    }

    @Test("nil and empty are absent, not plaintext")
    func handlesAbsence() {
        #expect(PacelliCrypto.readMigrating(nil, key: key) == .absent)
        #expect(PacelliCrypto.readMigrating("", key: key) == .absent)
        #expect(PacelliCrypto.readMigrating(nil, key: key).displayValue == nil)
        #expect(PacelliCrypto.readMigrating(nil, key: key).needsMigration == false)
    }

    @Test("round trip: migrate a legacy value once, and it stays migrated")
    func migrationIsStable() throws {
        let first = PacelliCrypto.readMigrating("2", key: key)
        #expect(first.needsMigration)

        let rewritten = try PacelliCrypto.encrypt(try #require(first.displayValue), key: key)
        let second = PacelliCrypto.readMigrating(rewritten, key: key)
        #expect(second == .decrypted("2"))
        #expect(
            second.needsMigration == false,
            "A migrated value that still reported needsMigration would rewrite forever.")
    }

    // MARK: - The structural envelope test

    @Test(
        "short human quantities are not mistaken for envelopes",
        arguments: ["2", "500g", "abcd", "aaaa", "12345678", "AAAAAAAAAAAAAAAAAAAAAA=="])
    func shortValuesAreNotEnvelopes(_ raw: String) {
        #expect(
            PacelliCrypto.looksLikeEnvelope(raw) == false,
            "\(raw) would be treated as unreadable ciphertext and never migrated.")
    }

    @Test("real ciphertext always passes the structural test")
    func realCiphertextLooksLikeAnEnvelope() throws {
        for plaintext in ["2", "500g", String(repeating: "x", count: 200)] {
            let stored = try PacelliCrypto.encrypt(plaintext, key: key)
            #expect(
                PacelliCrypto.looksLikeEnvelope(stored),
                "Ciphertext for \(plaintext.prefix(10)) failed the envelope test.")
        }
    }
}

// MARK: - Cross-language parity

/// The Swift and TypeScript classifiers must agree on every value.
///
/// Both `PacelliCrypto.readMigrating` and the API's `decryptMigrating` decide
/// whether a stored `quantity` is legacy plaintext, and the app acts on that
/// answer by rewriting the value as ciphertext. If the two implementations of
/// the structural envelope test ever disagree, one side rewrites what the other
/// calls ciphertext — and encrypting a ciphertext destroys the original beyond
/// recovery.
///
/// The two implementations used to be pinned to each other by a comment saying
/// "change both or neither", which cannot fail a build. This suite reads the
/// same fixture the TypeScript suite reads, so drift is a red test instead.
///
/// The ciphertexts in the fixture were produced by the TypeScript writer, so
/// passing also proves Swift opens what the API writes.
@Suite("Mid-migration parity with the TypeScript reader")
struct FieldMigrationParityTests {

    /// `<repo>/functions/tests/cross-language/`, relative to this file:
    /// …/PacelliApp/Packages/PacelliKit/Tests/PacelliKitTests/<this file>
    private static let fixtureURL: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }  // filename + 5 dirs → repo root
        return url
            .appendingPathComponent("functions/tests/cross-language")
            .appendingPathComponent("migrating_field_vectors.json")
    }()

    struct Case: Decodable, CustomStringConvertible {
        let name: String
        let stored: String?
        let kind: String
        let display: String?
        let needsMigration: Bool
        let looksLikeEnvelope: Bool

        var description: String { name }
    }

    struct Fixture: Decodable {
        let testKey: String
        let foreignKey: String
        let cases: [Case]
    }

    static let fixture: Fixture = {
        guard let data = try? Data(contentsOf: fixtureURL),
              let decoded = try? JSONDecoder().decode(Fixture.self, from: data)
        else {
            // Returning an empty fixture would make this suite silently vacuous,
            // which is the one outcome worse than a failure.
            fatalError(
                """
                Missing or unreadable \(fixtureURL.path).
                Regenerate: cd functions && npm run build \
                && node tests/cross-language/generate_migrating_vectors.js
                """)
        }
        return decoded
    }()

    @Test("the fixture is present and not vacuous")
    func fixtureLoaded() {
        #expect(Self.fixture.cases.count > 10)
        #expect(Self.fixture.testKey.count == 64)
    }

    @Test("classification matches TypeScript, case for case", arguments: fixture.cases)
    func matchesTypeScript(_ c: Case) throws {
        let field = PacelliCrypto.readMigrating(c.stored, key: Self.fixture.testKey)

        let kind: String
        switch field {
        case .decrypted: kind = "decrypted"
        case .legacyPlaintext: kind = "legacyPlaintext"
        case .undecryptable: kind = "undecryptable"
        case .absent: kind = "absent"
        }
        #expect(kind == c.kind, "\(c.name): Swift says \(kind), TypeScript says \(c.kind)")
        #expect(field.displayValue == c.display, "\(c.name): display value differs")
        #expect(
            field.needsMigration == c.needsMigration,
            """
            \(c.name): the two sides disagree about whether this value should be \
            rewritten as ciphertext. Rewriting a value TypeScript considers \
            ciphertext would double-encrypt it, and the original would be gone.
            """)
    }

    @Test("the structural envelope test matches TypeScript", arguments: fixture.cases)
    func envelopeTestMatchesTypeScript(_ c: Case) throws {
        guard let stored = c.stored else { return }
        #expect(
            PacelliCrypto.looksLikeEnvelope(stored) == c.looksLikeEnvelope,
            "\(c.name): looksLikeEnvelope diverged from the TypeScript implementation.")
    }
}
