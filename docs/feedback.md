# Feedback — how it works and how to read it

## What was wrong

From the Flutter days until **2026-08-11**, `FeedbackRepository.submit`
encrypted the message with `loadHouseholdKey(householdId)` — the sender's own
household key. That key is generated on their device and never leaves their
Keychain.

So every message ever sent was encrypted with a key only the sender held.
The code comment said *"entries are read by the developer, not the UI"*; the
developer could not read them either. Four messages (2026-03-16, two on
2026-08-01, one on 2026-08-11) sat in Firestore as permanently unreadable
ciphertext. They cannot be recovered — the keys never existed anywhere but on
those devices.

The send path always worked, which is why nothing looked broken. A test that
stopped at "Thank you!" would have passed green the entire time.

## How it works now

Feedback is sealed to a **Pacelli public key** baked into the app. The private
half never ships.

```text
"pfb1:" || base64( ephemeralPublicKey[32] || nonce[12] || ciphertext || tag[16] )
```

X25519 ECDH to a per-message ephemeral key → HKDF-SHA256 (salt = the ephemeral
public key, info = `pacelli-feedback-v1`) → AES-256-GCM.

- The app can seal but holds no private key: a stolen binary reveals nothing.
- A Firestore breach yields ciphertext, so the E2E promise still holds.
- Two identical messages produce unrelated ciphertexts.

`message`, the optional reply email, app version, OS, locale and guest status
all live **inside** the sealed blob. Only `type` and `rating` stay plaintext —
three-way enums, useful for triage, revealing essentially nothing.

| | |
|---|---|
| Implementation | `PacelliApp/Packages/PacelliKit/Sources/PacelliKit/Crypto/FeedbackSeal.swift` |
| Public key | embedded in `FeedbackRepository.publicKeyBase64` |
| Private key | `~/.config/jarvis/secrets/pacelli_feedback_x25519.key` (0600, outside every repo) |

### Where the private key lives

**Keychain is the source of truth**, item `pacelli-feedback-x25519` /
account `pacelli`, with `security` granted persistent access so scripts can
read it without a prompt. `read_feedback.py` tries the Keychain first and falls
back to `~/.config/jarvis/secrets/pacelli_feedback_x25519.key` (0600, outside
every repo) — the same arrangement as the rest of that directory, where
`sync_secrets.sh` treats the files as derived copies.

Proven by moving the file aside and reading feedback anyway, not assumed.

**If both copies are lost, all sealed feedback becomes unreadable forever.**
It is the one non-regenerable secret in the system: `secrets/` is gitignored
in the jarvis repo (correctly) and `~/.dr-mirror` does not cover it, so
Keychain — and whatever backs Keychain up — is the real safety net.

Without an "Always Allow" ACL entry, `security` opens a GUI prompt and waits
indefinitely; in a scheduled run that looks exactly like a hang. Hence the
10-second timeout on the Keychain lookup.

## Reading it

```bash
./scripts/read_feedback.py                 # newest 25, decrypted
./scripts/read_feedback.py --limit 100
./scripts/read_feedback.py --since 2026-08-01
./scripts/read_feedback.py --json          # for piping
```

Auth is gcloud Application Default Credentials — whoever is logged in. No
service-account key is stored anywhere. Entries predating the fix are listed
as `[unreadable]` rather than skipped: a reader that hid them would
under-report how much feedback exists.

## Keeping it honest

Two things can silently break this, and both are tested rather than assumed.

**Swift and Python must agree on HKDF.** CryptoKit's
`hkdfDerivedSymmetricKey` on one side, `cryptography`'s `HKDF` on the other.
If they drift, the app keeps sealing happily and nothing can open it — exactly
the original failure.

```bash
cd PacelliApp/Packages/PacelliKit && PACELLI_WRITE_FEEDBACK_VECTORS=1 swift test
python3 scripts/check_feedback_crypto.py
```

**A stranger must be able to send, and we must be able to read it.**

```bash
./scripts/check_feedback_e2e.sh
```

Fresh install + keychain reset → a genuinely new anonymous account → sends
through the UI with a nonce → asserts that exact message comes back in
plaintext, with the reply address and device context intact.

## Rules

`firestore.rules`:

- **create** — any signed-in user, `created_by` pinned to their own uid, exact
  field set, known enum values, message ≤ 100 000 chars. Deliberately NOT
  keyed to household membership: feedback is the one thing a stranger sends to
  us, and requiring `isMember()` made a fresh install's ability to report a bug
  depend on household state that may not have settled.
- **update** — never. A submitted report cannot be rewritten.
- **read / delete** — household members only. Not narrowed to `created_by`,
  because burn-all-data and `discardOwnEmptyHouseholds` both sweep every
  content collection with a `household_id ==` query and a narrower rule would
  deny those and break burn. Nothing is lost by that: a member who fetches an
  entry gets ciphertext they hold no key for.

The `pfb1:` prefix is **not** required on create. The version live on the App
Store still writes household-key ciphertext, and rejecting it would break
"send feedback" for every user on the current build. Add the check once the
sealed build has rolled out.

## Cloud Functions

`feedbackList` (deployed) lets a household list its own feedback. It can still
decrypt legacy entries — the household holds that key — but returns
`message: null, sealedForDeveloper: true` for sealed ones rather than handing
back `"[encrypted]"`, which would read as a decryption fault instead of what it
is: a message addressed to the developer, not to that household.
