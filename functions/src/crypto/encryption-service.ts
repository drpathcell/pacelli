/**
 * AES-256-CBC end-to-end encryption service for Pacelli.
 *
 * TypeScript port of `lib/core/crypto/encryption_service.dart`.
 * Produces identical ciphertext format: base64(iv_16_bytes + ciphertext_bytes).
 *
 * Uses Node.js built-in `crypto` module — no external dependencies.
 */
import * as crypto from "crypto";

const ALGORITHM = "aes-256-cbc";
const IV_LENGTH = 16;
const KEY_LENGTH = 32; // 256 bits

// Key derivation constants — must match Dart exactly.
const HKDF_SALT_V2 = "pacelli_hkdf_salt_v2";
const HKDF_INFO_V2 = "pacelli_e2e_user_key_v2";
const HMAC_SALT_V1 = "pacelli_e2e_key_derivation_v1";

/**
 * Converts a 64-character hex string to a 32-byte Buffer.
 */
function keyFromHex(hexKey: string): Buffer {
  if (hexKey.length !== 64) {
    throw new Error(`Invalid key length: expected 64 hex chars, got ${hexKey.length}`);
  }
  return Buffer.from(hexKey, "hex");
}

/**
 * Encrypts plaintext using AES-256-CBC with a fresh random IV.
 * Returns base64(iv + ciphertext) — identical format to Dart.
 */
export function encrypt(plaintext: string, key: string): string {
  const keyBuf = keyFromHex(key);
  const iv = crypto.randomBytes(IV_LENGTH);

  const cipher = crypto.createCipheriv(ALGORITHM, keyBuf, iv);
  const encrypted = Buffer.concat([
    cipher.update(plaintext, "utf8"),
    cipher.final(),
  ]);

  // Prepend IV to ciphertext, then base64-encode the whole thing.
  const combined = Buffer.concat([iv, encrypted]);
  return combined.toString("base64");
}

/**
 * Decrypts a base64 string produced by `encrypt()`.
 * Splits first 16 bytes as IV, rest as ciphertext.
 */
export function decrypt(ciphertext: string, key: string): string {
  const keyBuf = keyFromHex(key);
  const combined = Buffer.from(ciphertext, "base64");

  if (combined.length < IV_LENGTH + 1) {
    throw new Error("Ciphertext too short to contain IV + data");
  }

  const iv = combined.subarray(0, IV_LENGTH);
  const encryptedBytes = combined.subarray(IV_LENGTH);

  const decipher = crypto.createDecipheriv(ALGORITHM, keyBuf, iv);
  const decrypted = Buffer.concat([
    decipher.update(encryptedBytes),
    decipher.final(),
  ]);

  return decrypted.toString("utf8");
}

/**
 * Encrypts a nullable field. Returns null/empty unchanged.
 */
export function encryptNullable(
  plaintext: string | null | undefined,
  key: string
): string | null {
  if (plaintext == null || plaintext === "") return plaintext ?? null;
  return encrypt(plaintext, key);
}

/**
 * Decrypts a nullable field. On failure returns '[encrypted]'.
 */
export function decryptNullable(
  ciphertext: string | null | undefined,
  key: string
): string | null {
  if (ciphertext == null || ciphertext === "") return ciphertext ?? null;
  try {
    return decrypt(ciphertext, key);
  } catch {
    return "[encrypted]";
  }
}

// ── Key generation ──

/**
 * Generates a new random 256-bit household key.
 * Returns a 64-character hex string — identical to Dart.
 */
export function generateHouseholdKey(): string {
  return crypto.randomBytes(KEY_LENGTH).toString("hex");
}

// ── Key derivation ──

/**
 * Legacy v1 key derivation (raw HMAC-SHA256).
 * Kept for migration only — matches Dart `_deriveUserKeyV1`.
 */
function deriveUserKeyV1(uid: string): string {
  const salt = Buffer.from(HMAC_SALT_V1, "utf8");
  const hmac = crypto.createHmac("sha256", salt);
  hmac.update(uid, "utf8");
  return hmac.digest("hex");
}

/**
 * Derives a 256-bit user key from Firebase UID using HKDF (RFC 5869).
 * Matches Dart `deriveUserKey` exactly.
 *
 * HKDF-Extract: PRK = HMAC-SHA256(salt, uid)
 * HKDF-Expand:  OKM = HMAC-SHA256(PRK, info || 0x01)
 */
export function deriveUserKey(uid: string): string {
  // HKDF-Extract
  const salt = Buffer.from(HKDF_SALT_V2, "utf8");
  const ikm = Buffer.from(uid, "utf8");
  const prk = crypto.createHmac("sha256", salt).update(ikm).digest();

  // HKDF-Expand
  const info = Buffer.from(HKDF_INFO_V2, "utf8");
  const expandInput = Buffer.concat([info, Buffer.from([0x01])]);
  const okm = crypto.createHmac("sha256", prk).update(expandInput).digest();

  return okm.toString("hex");
}

/**
 * Attempts v2 (HKDF) decryption first, falls back to v1 (HMAC).
 * Used for transparent key migration.
 */
export function decryptKeyWithMigration(encryptedKey: string, uid: string): {
  decryptedKey: string;
  wasV1: boolean;
} {
  // Try v2 first
  try {
    const v2Key = deriveUserKey(uid);
    const decryptedKey = decrypt(encryptedKey, v2Key);
    return { decryptedKey, wasV1: false };
  } catch {
    // Fall through to v1
  }

  // Fall back to v1
  const v1Key = deriveUserKeyV1(uid);
  const decryptedKey = decrypt(encryptedKey, v1Key);
  return { decryptedKey, wasV1: true };
}

/**
 * Encrypts a household key for a specific user.
 */
export function encryptKeyForUser(householdKey: string, uid: string): string {
  const userKey = deriveUserKey(uid);
  return encrypt(householdKey, userKey);
}

/**
 * Decrypts a household key using the user's derived key.
 */
export function decryptKeyForUser(encryptedKey: string, uid: string): string {
  const userKey = deriveUserKey(uid);
  return decrypt(encryptedKey, userKey);
}
