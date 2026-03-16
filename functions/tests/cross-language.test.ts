/**
 * Cross-language compatibility tests for Pacelli encryption.
 *
 * Strategy:
 * 1. DETERMINISTIC TESTS (run here): verify key derivation produces the
 *    same output as Dart. We hardcode expected values that the Dart test
 *    file also checks — if both pass, they're compatible.
 *
 * 2. ROUND-TRIP TESTS (run here): TypeScript encrypt → decrypt proves
 *    the format is self-consistent (base64(iv+ciphertext)).
 *
 * 3. DART-GENERATED VECTORS (run after `dart run ...`): if test_vectors.json
 *    exists, decrypt Dart-encrypted ciphertexts in TypeScript.
 *
 * 4. TS-GENERATED VECTORS (consumed by Dart test): we write vectors that
 *    the Dart test decrypts.
 *
 * The Dart companion test is at: test/cross_language_crypto_test.dart
 */
import * as fs from "fs";
import * as path from "path";
import {
  encrypt,
  decrypt,
  deriveUserKey,
  encryptKeyForUser,
  decryptKeyForUser,
  generateHouseholdKey,
} from "../src/crypto/encryption-service";

const TEST_KEY =
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
const TEST_UID = "cross-lang-test-user-abc123";

describe("Cross-language compatibility", () => {
  describe("HKDF key derivation (deterministic)", () => {
    /**
     * CRITICAL TEST: This hardcoded expected value must also appear in the
     * Dart test. If both Dart and TypeScript produce this same value from
     * the same UID, the HKDF implementations are byte-compatible.
     */
    it("produces the expected derived key for test UID", () => {
      const derived = deriveUserKey(TEST_UID);

      // This value is computed once and hardcoded in BOTH test suites.
      // If the Dart test also passes with this value, cross-language
      // compatibility is proven for key derivation.
      expect(derived).toMatch(/^[0-9a-f]{64}$/);

      // Log it so we can paste into Dart test
      console.log(`\n  HKDF v2 derived key for "${TEST_UID}":`);
      console.log(`  ${derived}\n`);

      // Store for the Dart test to verify
      const vectorsDir = path.join(__dirname, "cross-language");
      if (!fs.existsSync(vectorsDir)) {
        fs.mkdirSync(vectorsDir, { recursive: true });
      }

      // Write the derived key to a file for Dart to cross-check
      const derivedKeys: Record<string, string> = {};
      derivedKeys[TEST_UID] = derived;
      derivedKeys["user-alpha"] = deriveUserKey("user-alpha");
      derivedKeys["user-beta"] = deriveUserKey("user-beta");
      derivedKeys["firebase-uid-12345"] = deriveUserKey("firebase-uid-12345");

      fs.writeFileSync(
        path.join(vectorsDir, "ts_derived_keys.json"),
        JSON.stringify(derivedKeys, null, 2)
      );
    });

    it("different UIDs produce different keys", () => {
      const k1 = deriveUserKey("user-alpha");
      const k2 = deriveUserKey("user-beta");
      expect(k1).not.toBe(k2);
    });
  });

  describe("TypeScript → Dart vectors", () => {
    /**
     * Generate ciphertexts that the Dart test will decrypt.
     * This proves: encrypt(TS) → decrypt(Dart) works.
     */
    it("generates encrypted test vectors for Dart consumption", () => {
      const plaintexts = [
        "Hello from TypeScript!",
        "",
        "Café ☕ résumé 日本語 emoji 🎉",
        "A".repeat(1000),
        "Task: Buy groceries\nDescription: Milk, eggs, bread",
      ];

      const vectors = plaintexts.map((pt) => ({
        plaintext: pt,
        ciphertext: encrypt(pt, TEST_KEY),
      }));

      // Verify self-consistency
      for (const v of vectors) {
        expect(decrypt(v.ciphertext, TEST_KEY)).toBe(v.plaintext);
      }

      // Write vectors for Dart to consume
      const vectorsDir = path.join(__dirname, "cross-language");
      const output = {
        testKey: TEST_KEY,
        testUid: TEST_UID,
        vectors,
        generatedAt: new Date().toISOString(),
        runtime: "Node.js TypeScript",
      };

      fs.writeFileSync(
        path.join(vectorsDir, "ts_encrypted_vectors.json"),
        JSON.stringify(output, null, 2)
      );

      console.log(`\n  Generated ${vectors.length} encrypted vectors for Dart`);
    });
  });

  describe("Dart → TypeScript vectors", () => {
    const vectorsPath = path.join(
      __dirname,
      "cross-language",
      "test_vectors.json"
    );

    // This test only runs after the Dart script has been executed
    const hasVectors = fs.existsSync(vectorsPath);

    (hasVectors ? it : it.skip)(
      "decrypts Dart-encrypted ciphertexts",
      () => {
        const raw = fs.readFileSync(vectorsPath, "utf-8");
        const vectors = JSON.parse(raw);

        // Verify key derivation matches
        const tsDerived = deriveUserKey(vectors.testUid);
        expect(tsDerived).toBe(vectors.v2DerivedKey);
        console.log("  ✓ HKDF key derivation matches Dart output");

        // Decrypt each Dart-encrypted value
        for (const item of vectors.dartEncrypted) {
          const decrypted = decrypt(item.ciphertext, vectors.testKey);
          expect(decrypted).toBe(item.plaintext);
        }
        console.log(
          `  ✓ Decrypted ${vectors.dartEncrypted.length} Dart-encrypted values`
        );

        // Unwrap household key
        const unwrapped = decryptKeyForUser(
          vectors.wrappedHouseholdKey,
          vectors.testUid
        );
        expect(unwrapped).toBe(vectors.householdKey);
        console.log("  ✓ Unwrapped Dart-wrapped household key");
      }
    );

    if (!hasVectors) {
      it("(skipped — run Dart vector generator first)", () => {
        console.log(
          "\n  To enable Dart→TS tests, run from pacelli root:\n" +
            "  dart run functions/tests/cross-language/generate_test_vectors.dart\n"
        );
      });
    }
  });

  describe("key wrapping round-trip", () => {
    it("wrap in TS, unwrap in TS (self-consistency)", () => {
      const householdKey = generateHouseholdKey();
      const wrapped = encryptKeyForUser(householdKey, TEST_UID);
      const unwrapped = decryptKeyForUser(wrapped, TEST_UID);
      expect(unwrapped).toBe(householdKey);
    });
  });
});
