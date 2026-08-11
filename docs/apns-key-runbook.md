# APNs auth key — DONE (2026-08-11)

Phase B's blocker is cleared. Kept as a record of what exists and why, and as
the recovery procedure if the key is ever lost or revoked.

## What exists

| | |
|---|---|
| Key name | `Pacelli APNs` |
| **Key ID** | `TJ273J69AU` |
| Team ID | `5PCNU95W9V` |
| Environment | **Sandbox & Production** (one key covers TestFlight and the App Store) |
| Key Restriction | **Team Scoped (All Topics)** |
| Firebase | uploaded to BOTH the development and production APNs auth key slots of `pacelli-35621` |

Apple's configure step warns: *"The APNs configuration for accessible
environment and key restriction type can't be changed once saved."* Sandbox &
Production + Team Scoped was chosen precisely because it is the combination
that never needs changing.

Not to be confused with `AuthKey_MMWTC97VR7.p8`, the App Store Connect API key,
which cannot send push. The SIWA key (`27AM6NPQZ6`) is a third, separate thing.

## Where the .p8 lives

- **Keychain** — `pacelli-apns-authkey` / account `TJ273J69AU` (source of truth)
- `~/.config/jarvis/secrets/AuthKey_TJ273J69AU.p8`, 0600, outside every repo
- Verified: the Keychain copy decodes to exactly the file on disk.

`security find-generic-password -w` returns **hex**, not text, when the value
contains newlines — a naive string comparison against the file reports a
mismatch on a perfectly good key. Decode with `binascii.unhexlify` before
comparing.

Apple removes its server copy after the single download. If both local copies
are lost the key must be revoked and replaced.

## If it ever has to be redone

1. https://developer.apple.com/account/resources/authkeys/list → **+**
2. Name it, tick **Apple Push Notifications service (APNs)**.
3. **Configure** (required — Continue stays disabled until this is done; this
   step is newer than most guides): Environment **Sandbox & Production**,
   Key Restriction **Team Scoped (All Topics)** → Save.
4. Continue → Register → **Download** (once only). Note the Key ID.
5. Move it straight out of `~/Downloads` to
   `~/.config/jarvis/secrets/`, `chmod 600`, and add it to Keychain.
6. https://console.firebase.google.com/project/pacelli-35621/settings/cloudmessaging
   → Apple app configuration → upload to **both** the development and
   production auth key slots, with the Key ID and Team ID `5PCNU95W9V`.

## Still to build (Phase B/C)

Push transport is unblocked but not written: FCM token registration on the
client, the Cloud Function that copies already-encrypted title ciphertext into
the APNs payload, and the Notification Service Extension that decrypts it on
device. The extension needs a Keychain access group, so it gets a security
audit addendum before it ships.
