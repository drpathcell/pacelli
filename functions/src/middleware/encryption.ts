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
  };
}
