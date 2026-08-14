/**
 * Field-level encryption helpers for Pacelli API handlers.
 *
 * Mirrors the _enc/_dec/_encN/_decN pattern in firebase_data_repository.dart.
 * Each handler receives the household key via AuthContext and uses these
 * helpers to encrypt before writing and decrypt after reading Firestore.
 */
import {
  encrypt,
  decrypt,
  encryptNullable,
  decryptNullable,
  decryptMigrating,
} from "../crypto/encryption-service";

/**
 * Creates a set of encryption/decryption helpers bound to a household key.
 * Use in every API handler:
 *
 * ```ts
 * const { enc, dec, encN, decN } = createFieldCrypto(ctx.householdKey);
 * const data = { title: enc(title), description: encN(description) };
 * ```
 */
export function createFieldCrypto(householdKey: string) {
  return {
    /** Encrypt a required string field */
    enc: (plaintext: string): string => encrypt(plaintext, householdKey),
    /** Decrypt a required string field */
    dec: (ciphertext: string): string => {
      try {
        return decrypt(ciphertext, householdKey);
      } catch {
        return "[encrypted]";
      }
    },
    /** Encrypt a nullable string field */
    encN: (plaintext: string | null | undefined): string | null =>
      encryptNullable(plaintext, householdKey),
    /** Decrypt a nullable string field */
    decN: (ciphertext: string | null | undefined): string | null =>
      decryptNullable(ciphertext, householdKey),
    /**
     * Decrypt a field that may still hold pre-migration plaintext.
     * Use for `quantity` only — everything else has always been ciphertext,
     * and using this where `decN` belongs would silently pass corruption
     * through to the client as if it were data.
     */
    decMig: (stored: string | null | undefined): string | null =>
      decryptMigrating(stored, householdKey),
  };
}
