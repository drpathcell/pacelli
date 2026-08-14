/**
 * The mid-migration read path for `quantity`.
 *
 * `checklist_items.quantity` and `plan_checklist_items.quantity` were written
 * in the clear before 1.7.0, so both forms are live in the same collection and
 * a reader cannot be told which one it holds. `decryptNullable` is wrong for
 * them — it answers "[encrypted]" for anything that will not open, which would
 * hide a user's real pre-migration quantity behind a placeholder.
 *
 * The classification cases live in a fixture that the Swift suite reads too
 * (`PacelliKitTests/FieldMigrationTests.swift`). The two implementations of
 * `looksLikeEnvelope` must agree on every value or one side will rewrite what
 * the other calls ciphertext — and encrypting a ciphertext destroys the
 * original beyond recovery. A shared fixture makes that drift a build failure
 * rather than a comment nobody reads.
 */
import * as fs from "fs";
import * as path from "path";
import {
  encrypt,
  decryptMigrating,
  looksLikeEnvelope,
} from "../src/crypto/encryption-service";

interface MigratingCase {
  name: string;
  stored: string | null;
  kind: "decrypted" | "legacyPlaintext" | "undecryptable" | "absent";
  display: string | null;
  needsMigration: boolean;
  looksLikeEnvelope: boolean;
}

interface Fixture {
  testKey: string;
  foreignKey: string;
  cases: MigratingCase[];
}

const FIXTURE = path.join(
  __dirname,
  "cross-language",
  "migrating_field_vectors.json"
);

const fixture: Fixture = JSON.parse(fs.readFileSync(FIXTURE, "utf8"));

describe("decryptMigrating", () => {
  it("has a fixture to test against", () => {
    // A missing fixture must fail loudly rather than silently pass zero cases.
    expect(fs.existsSync(FIXTURE)).toBe(true);
    expect(fixture.cases.length).toBeGreaterThan(10);
  });

  describe.each(fixture.cases)("$name", (c) => {
    it(`reads as ${c.display === null ? "null" : JSON.stringify(c.display)}`, () => {
      expect(decryptMigrating(c.stored, fixture.testKey)).toBe(c.display);
    });

    it(`is ${c.looksLikeEnvelope ? "" : "not "}structurally an envelope`, () => {
      if (c.stored === null) return;
      expect(looksLikeEnvelope(c.stored)).toBe(c.looksLikeEnvelope);
    });
  });

  // The failure this whole three-way split exists to prevent.
  it("never hands back a foreign ciphertext as if it were plaintext", () => {
    const foreign = encrypt("2", fixture.foreignKey);
    const read = decryptMigrating(foreign, fixture.testKey);
    expect(read).toBe("[encrypted]");
    expect(read).not.toBe(foreign);
  });

  it("opens what it wrote", () => {
    for (const plaintext of ["2", "500g", "½ punnet", "x".repeat(500)]) {
      expect(
        decryptMigrating(encrypt(plaintext, fixture.testKey), fixture.testKey)
      ).toBe(plaintext);
    }
  });

  // Matches encryptNullable/decryptNullable, which also pass "" straight
  // through. The app spells the same state `nil` and writes NSNull, so an
  // empty string never actually reaches Firestore from either writer.
  it("passes null and empty through unchanged", () => {
    expect(decryptMigrating(null, fixture.testKey)).toBeNull();
    expect(decryptMigrating(undefined, fixture.testKey)).toBeNull();
    expect(decryptMigrating("", fixture.testKey)).toBe("");
  });
});

describe("looksLikeEnvelope", () => {
  it("rejects values too short to be IV + one block", () => {
    // 16 bytes of base64 — an IV with nothing after it.
    expect(looksLikeEnvelope("AAAAAAAAAAAAAAAAAAAAAA==")).toBe(false);
    expect(looksLikeEnvelope("")).toBe(false);
    expect(looksLikeEnvelope("2")).toBe(false);
  });

  it("rejects strings that are not base64 at all", () => {
    for (const raw of ["2 dozen", "500 g", "half a punnet", "½", "a/b c"]) {
      expect(looksLikeEnvelope(raw)).toBe(false);
    }
  });

  it("rejects base64 that does not round-trip", () => {
    // Buffer.from is lenient and would decode this happily; the round-trip
    // check is what rejects it.
    expect(looksLikeEnvelope("abc")).toBe(false);
  });

  it("accepts every real ciphertext", () => {
    for (let i = 0; i < 50; i++) {
      const stored = encrypt("x".repeat(i), fixture.testKey);
      expect(looksLikeEnvelope(stored)).toBe(true);
    }
  });
});
