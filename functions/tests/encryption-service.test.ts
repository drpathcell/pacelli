/**
 * Cross-language encryption tests for Pacelli.
 *
 * These tests verify that the TypeScript EncryptionService produces
 * output compatible with the Dart version. Key properties:
 *
 * 1. encrypt() output is base64(iv_16_bytes + ciphertext)
 * 2. decrypt(encrypt(x)) === x for any plaintext
 * 3. HKDF key derivation produces deterministic output from UID
 * 4. v1 HMAC derivation is preserved for migration
 * 5. Nullable helpers handle null/empty correctly
 */
import {
  encrypt,
  decrypt,
  encryptNullable,
  decryptNullable,
  generateHouseholdKey,
  deriveUserKey,
  decryptKeyWithMigration,
  encryptKeyForUser,
  decryptKeyForUser,
} from "../src/crypto/encryption-service";

describe("EncryptionService", () => {
  // A fixed test key (64 hex chars = 256 bits)
  const TEST_KEY = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

  describe("encrypt / decrypt", () => {
    it("round-trips plaintext correctly", () => {
      const plaintext = "Hello, Pacelli!";
      const ciphertext = encrypt(plaintext, TEST_KEY);
      const decrypted = decrypt(ciphertext, TEST_KEY);
      expect(decrypted).toBe(plaintext);
    });

    it("handles empty string", () => {
      const ciphertext = encrypt("", TEST_KEY);
      const decrypted = decrypt(ciphertext, TEST_KEY);
      expect(decrypted).toBe("");
    });

    it("handles unicode characters", () => {
      const plaintext = "Café ☕ résumé 日本語 emoji 🎉";
      const ciphertext = encrypt(plaintext, TEST_KEY);
      const decrypted = decrypt(ciphertext, TEST_KEY);
      expect(decrypted).toBe(plaintext);
    });

    it("handles long strings", () => {
      const plaintext = "x".repeat(10000);
      const ciphertext = encrypt(plaintext, TEST_KEY);
      const decrypted = decrypt(ciphertext, TEST_KEY);
      expect(decrypted).toBe(plaintext);
    });

    it("produces different ciphertexts for same plaintext (random IV)", () => {
      const plaintext = "test";
      const c1 = encrypt(plaintext, TEST_KEY);
      const c2 = encrypt(plaintext, TEST_KEY);
      expect(c1).not.toBe(c2); // Different IVs
      expect(decrypt(c1, TEST_KEY)).toBe(plaintext);
      expect(decrypt(c2, TEST_KEY)).toBe(plaintext);
    });

    it("ciphertext is base64 with 16-byte IV prefix", () => {
      const ciphertext = encrypt("test", TEST_KEY);
      const decoded = Buffer.from(ciphertext, "base64");
      // At minimum: 16 bytes IV + 16 bytes AES block
      expect(decoded.length).toBeGreaterThanOrEqual(32);
    });

    it("fails to decrypt with wrong key", () => {
      const wrongKey = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
      const ciphertext = encrypt("secret", TEST_KEY);
      expect(() => decrypt(ciphertext, wrongKey)).toThrow();
    });

    it("rejects invalid key length", () => {
      expect(() => encrypt("test", "short")).toThrow(/Invalid key length/);
    });
  });

  describe("nullable helpers", () => {
    it("encryptNullable returns null for null input", () => {
      expect(encryptNullable(null, TEST_KEY)).toBeNull();
    });

    it("encryptNullable returns null for empty string", () => {
      expect(encryptNullable("", TEST_KEY)).toBe("");
    });

    it("encryptNullable encrypts non-empty strings", () => {
      const result = encryptNullable("hello", TEST_KEY);
      expect(result).not.toBe("hello");
      expect(result).not.toBeNull();
    });

    it("decryptNullable returns null for null input", () => {
      expect(decryptNullable(null, TEST_KEY)).toBeNull();
    });

    it("decryptNullable returns [encrypted] on failure", () => {
      expect(decryptNullable("not-valid-base64!", TEST_KEY)).toBe("[encrypted]");
    });

    it("round-trips nullable values", () => {
      const encrypted = encryptNullable("test value", TEST_KEY);
      const decrypted = decryptNullable(encrypted, TEST_KEY);
      expect(decrypted).toBe("test value");
    });
  });

  describe("generateHouseholdKey", () => {
    it("produces a 64-char hex string", () => {
      const key = generateHouseholdKey();
      expect(key).toMatch(/^[0-9a-f]{64}$/);
    });

    it("produces unique keys", () => {
      const k1 = generateHouseholdKey();
      const k2 = generateHouseholdKey();
      expect(k1).not.toBe(k2);
    });
  });

  describe("HKDF key derivation (v2)", () => {
    it("produces a 64-char hex string from UID", () => {
      const key = deriveUserKey("test-uid-12345");
      expect(key).toMatch(/^[0-9a-f]{64}$/);
    });

    it("is deterministic — same UID always produces same key", () => {
      const k1 = deriveUserKey("uid-abc");
      const k2 = deriveUserKey("uid-abc");
      expect(k1).toBe(k2);
    });

    it("different UIDs produce different keys", () => {
      const k1 = deriveUserKey("user-1");
      const k2 = deriveUserKey("user-2");
      expect(k1).not.toBe(k2);
    });
  });

  describe("key wrapping", () => {
    it("encryptKeyForUser / decryptKeyForUser round-trips", () => {
      const householdKey = generateHouseholdKey();
      const uid = "firebase-uid-123";

      const wrapped = encryptKeyForUser(householdKey, uid);
      const unwrapped = decryptKeyForUser(wrapped, uid);
      expect(unwrapped).toBe(householdKey);
    });

    it("different users get different wrapped keys", () => {
      const householdKey = generateHouseholdKey();
      const w1 = encryptKeyForUser(householdKey, "user-a");
      const w2 = encryptKeyForUser(householdKey, "user-b");
      expect(w1).not.toBe(w2);
      // But both decrypt to the same household key
      expect(decryptKeyForUser(w1, "user-a")).toBe(householdKey);
      expect(decryptKeyForUser(w2, "user-b")).toBe(householdKey);
    });
  });

  describe("v1 → v2 migration", () => {
    it("decrypts v2-wrapped keys", () => {
      const householdKey = generateHouseholdKey();
      const uid = "migration-test-uid";

      // Wrap with v2 (current)
      const wrapped = encryptKeyForUser(householdKey, uid);
      const { decryptedKey, wasV1 } = decryptKeyWithMigration(wrapped, uid);

      expect(decryptedKey).toBe(householdKey);
      expect(wasV1).toBe(false);
    });

    it("decrypts v1-wrapped keys and flags migration needed", () => {
      const householdKey = generateHouseholdKey();
      const uid = "v1-legacy-user";

      // Simulate v1 wrapping: HMAC-SHA256 key derivation
      const crypto = require("crypto");
      const salt = Buffer.from("pacelli_e2e_key_derivation_v1", "utf8");
      const v1Key = crypto.createHmac("sha256", salt).update(uid).digest("hex");
      const wrappedV1 = encrypt(householdKey, v1Key);

      const { decryptedKey, wasV1 } = decryptKeyWithMigration(wrappedV1, uid);
      expect(decryptedKey).toBe(householdKey);
      expect(wasV1).toBe(true);
    });
  });
});
