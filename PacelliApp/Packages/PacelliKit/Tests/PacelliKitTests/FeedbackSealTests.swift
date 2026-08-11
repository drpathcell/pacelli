import CryptoKit
import Foundation
import Testing

@testable import PacelliKit

/// The point of these is not that AES-GCM works — Apple's tested that. It is
/// that the ENVELOPE is right: that we can still open what we seal, that the
/// prefix distinguishes new from legacy, and that a tampered blob fails loudly
/// rather than yielding garbage.
@Suite("Feedback sealed envelope")
struct FeedbackSealTests {

    /// Fresh keypair per test — never the production key.
    private func keypair() -> (pub: String, priv: String) {
        let priv = Curve25519.KeyAgreement.PrivateKey()
        return (priv.publicKey.rawRepresentation.base64EncodedString(),
                priv.rawRepresentation.base64EncodedString())
    }

    @Test("round-trips a message")
    func roundTrip() throws {
        let k = keypair()
        let sealed = try FeedbackSeal.seal("the join code screen is confusing", to: k.pub)
        #expect(try FeedbackSeal.open(sealed, privateKeyBase64: k.priv)
            == "the join code screen is confusing")
    }

    @Test("round-trips JSON, emoji and newlines — real feedback is not ASCII")
    func roundTripsAwkwardText() throws {
        let k = keypair()
        let payload = #"{"message":"crashed 🙁\nwhen I tapped Save","email":"a@b.co"}"#
        let sealed = try FeedbackSeal.seal(payload, to: k.pub)
        #expect(try FeedbackSeal.open(sealed, privateKeyBase64: k.priv) == payload)
    }

    @Test("the same text seals differently every time")
    func ephemeralKeyIsFresh() throws {
        let k = keypair()
        let a = try FeedbackSeal.seal("same", to: k.pub)
        let b = try FeedbackSeal.seal("same", to: k.pub)
        #expect(a != b)
        // ...and both still open. A fresh key that broke decryption would be
        // worse than a reused one.
        #expect(try FeedbackSeal.open(a, privateKeyBase64: k.priv) == "same")
        #expect(try FeedbackSeal.open(b, privateKeyBase64: k.priv) == "same")
    }

    @Test("a different private key cannot open it")
    func wrongKeyFails() throws {
        let sender = keypair()
        let stranger = keypair()
        let sealed = try FeedbackSeal.seal("private", to: sender.pub)
        #expect(throws: (any Error).self) {
            try FeedbackSeal.open(sealed, privateKeyBase64: stranger.priv)
        }
    }

    @Test("a tampered ciphertext fails rather than decrypting to garbage")
    func tamperingIsDetected() throws {
        let k = keypair()
        let sealed = try FeedbackSeal.seal("original text", to: k.pub)
        var blob = Data(base64Encoded: String(sealed.dropFirst(FeedbackSeal.prefix.count)))!
        blob[blob.count - 1] ^= 0x01  // flip a bit in the GCM tag
        let tampered = FeedbackSeal.prefix + blob.base64EncodedString()
        #expect(throws: (any Error).self) {
            try FeedbackSeal.open(tampered, privateKeyBase64: k.priv)
        }
    }

    @Test("legacy household-key ciphertext is recognised, not mistaken for ours")
    func legacyIsDistinguishable() throws {
        // A real unreadable entry pulled from Firestore on 2026-08-11.
        let legacy = "4iQmTuAurfEei/Zy2Q7En9XpMI7U1UkeevHG7OwQbcRh6FKj8tMcfZp2G8K6NN7LJ3Y9CD7dz+nTvAEzRDZKpg=="
        #expect(!FeedbackSeal.isSealed(legacy))
        let k = keypair()
        #expect(FeedbackSeal.isSealed(try FeedbackSeal.seal("new", to: k.pub)))
        #expect(throws: (any Error).self) {
            try FeedbackSeal.open(legacy, privateKeyBase64: k.priv)
        }
    }

    @Test("rejects a malformed envelope instead of crashing")
    func malformedInputs() throws {
        let k = keypair()
        for bad in [FeedbackSeal.prefix + "!!!not base64!!!",
                    FeedbackSeal.prefix + Data([1, 2, 3]).base64EncodedString(),
                    FeedbackSeal.prefix] {
            #expect(throws: (any Error).self) {
                try FeedbackSeal.open(bad, privateKeyBase64: k.priv)
            }
        }
    }

    @Test("rejects a public key that is not a 32-byte X25519 key")
    func badPublicKey() throws {
        #expect(throws: (any Error).self) { try FeedbackSeal.seal("x", to: "not-base64!") }
        #expect(throws: (any Error).self) {
            try FeedbackSeal.seal("x", to: Data([0, 1, 2]).base64EncodedString())
        }
    }
}
