/**
 * Regenerates `migrating_field_vectors.json` — the shared classification
 * fixture for the mid-migration `quantity` field.
 *
 * Why a fixture and not two comments: `looksLikeEnvelope` exists in both
 * TypeScript and Swift, and the two must classify every value identically. If
 * they drift, one side rewrites a value the other calls ciphertext, and a
 * double encryption is unrecoverable. A comment saying "change both or
 * neither" cannot fail a build. This file can.
 *
 * Ciphertexts carry a random IV, so they cannot be derived on the fly and
 * compared — they are generated once, checked in, and read by both test
 * suites. Regenerate with:
 *
 *   cd functions && npm run build && node tests/cross-language/generate_migrating_vectors.js
 *
 * Regenerating is safe but pointless unless the envelope format changes; the
 * checked-in vectors are the record that today's Swift opens ciphertext today's
 * TypeScript wrote.
 */
const fs = require("fs");
const path = require("path");
const {
  encrypt,
  looksLikeEnvelope,
} = require("../../dist/crypto/encryption-service");

const TEST_KEY =
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
// A different valid household key. Ciphertext from this one is a well-formed
// envelope that the reader cannot open — the case that must never be rewritten.
const FOREIGN_KEY =
  "ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100";

/** kind: decrypted | legacyPlaintext | undecryptable | absent */
const cases = [];

function add(name, stored, kind, display, needsMigration) {
  cases.push({
    name,
    stored,
    kind,
    display,
    needsMigration,
    // Recorded from the TypeScript implementation; the Swift test asserts its
    // own implementation agrees value for value.
    looksLikeEnvelope: stored == null ? false : looksLikeEnvelope(stored),
  });
}

// ── Ciphertext this key can open ──
for (const plaintext of ["2", "500g", "2 dozen", "½ punnet", "x".repeat(200)]) {
  add(
    `ciphertext of ${JSON.stringify(plaintext.slice(0, 12))}`,
    encrypt(plaintext, TEST_KEY),
    "decrypted",
    plaintext,
    false
  );
}
// An encrypted empty string is NOT the same as an absent field: it is a real
// envelope that opens to "". Pinned so neither side starts calling it absent.
add("ciphertext of the empty string", encrypt("", TEST_KEY), "decrypted", "", false);

// ── Pre-migration plaintext: shown as-is, scheduled for rewrite ──
for (const raw of [
  "2",
  "1",
  "500g",
  "2 dozen",
  "½ punnet",
  "x3",
  "abcd",
  "12345678",
  "2 x 1.5L",
  "AAAAAAAAAAAAAAAAAAAAAA==", // valid base64, decodes to 16 bytes — too short
  "a lot", // spaces are not base64 at all
]) {
  add(`legacy plaintext ${JSON.stringify(raw)}`, raw, "legacyPlaintext", raw, true);
}

// ── A valid envelope this key cannot open: corruption or a foreign key ──
add(
  "ciphertext written with a different household key",
  encrypt("2", FOREIGN_KEY),
  "undecryptable",
  "[encrypted]",
  false
);
// The known and accepted false positive. A 44-char base64 string decodes to 32
// bytes, which is structurally indistinguishable from IV + one block, so it is
// classified undecryptable and never migrated. No real quantity looks like
// this, and the alternative — loosening the test — risks double encryption,
// which is unrecoverable. Pinned so the trade-off is visible, not discovered.
add(
  "base64-shaped junk long enough to pass the structural test",
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
  "undecryptable",
  "[encrypted]",
  false
);

// ── Absent ──
add("null", null, "absent", null, false);

const out = {
  comment:
    "Shared classification fixture for the mid-migration `quantity` field. " +
    "Read by functions/tests/field-migration.test.ts and by " +
    "PacelliKitTests/FieldMigrationTests.swift. Regenerate with " +
    "tests/cross-language/generate_migrating_vectors.js.",
  testKey: TEST_KEY,
  foreignKey: FOREIGN_KEY,
  cases,
};

const target = path.join(__dirname, "migrating_field_vectors.json");
fs.writeFileSync(target, JSON.stringify(out, null, 2) + "\n");
console.log(`Wrote ${cases.length} cases to ${target}`);
