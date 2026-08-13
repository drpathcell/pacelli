# Security audit addendum — entitlement reach of the notification extension

**Date:** 2026-08-13 · **Against:** 1.4.0 (build 42, live)
**Closes:** the "Not verified here" section of `AUDIT_2026-08-11_phasec_addendum.md` — partially. Read the Still open section before treating this as done.

## The claim under test

Phase C moved the household key into a keychain access group so a second
process — `PacelliNotificationService` — could decrypt a notification title on
device. That is a real expansion of the key's blast radius, and it was
justified on one property:

> The ONLY entitlement this extension gets. It can read the household key and
> nothing else — no push, no Sign in with Apple, no network identity.
> — `NotificationService.entitlements`

Phase C could not verify it. The simulator does not enforce entitlements, so
decryption was proven and the boundary was not.

## What is verified now

**1. The entitlements the binaries request.**

| target | entitlements |
|---|---|
| `PacelliApp` | `aps-environment`, `keychain-access-groups`, `com.apple.developer.applesignin` |
| `PacelliNotificationService` | `keychain-access-groups` — and nothing else |

Both claim exactly one keychain group, `$(AppIdentifierPrefix)com.pacelli.shared`.
A second group would mean reach into items nobody audited; there isn't one.

**2. Apple's own ceiling on what those App IDs may request.** Queried through
the ASC API (`/v1/bundleIds/{id}/bundleIdCapabilities`):

```
com.pacelli.pacelli                       IN_APP_PURCHASE, PUSH_NOTIFICATIONS, APPLE_ID_AUTH
com.pacelli.pacelli.NotificationService   IN_APP_PURCHASE          <- Apple's default, on every App ID
```

This is the stronger of the two facts. The entitlements plist is a *request*;
the App ID is the *ceiling*. The extension could not register for push or use
Sign in with Apple even if a plist someday claimed them — the profile would
not sign.

**3. Neither can drift silently again.** `scripts/verify_entitlements.py`
holds the allow-list and runs as a required job in Native CI (`entitlements`,
ubuntu, no toolchain, seconds). Verified to fail in both directions before
being wired up: injecting `aps-environment` into the extension and a second
keychain group into the app produces exit 1 naming both.

Opt-in modes: `--app PATH.app` diffs the *signed* entitlements out of the
built binaries (CI builds with `CODE_SIGNING_ALLOWED=NO`, so this cannot run
there); `--asc` re-checks Apple's capabilities.

## Reviewed while here, no finding

- `SecureStore.read` falls back from the shared group to `group: nil`. In the
  extension `nil` resolves to the *extension's own* default group, not the
  app's — so the fallback cannot reach app-private items even by accident.
  Isolation by construction on this path.
- `migrateToAccessGroup` is genuinely wired: `KeyManager.loadHouseholdKey`
  calls it on every cache hit, so pre-Phase-C installs move their key into the
  shared group on first read rather than showing the generic body forever.
  Idempotent, and failure costs only the notification body.
- `delete` and `deleteAll` both cover the shared group. A burn that wiped only
  the app's private keychain would leave the key readable by the extension;
  it does not.

## Still open

**Runtime isolation is still not observed.** Entitlements are the mechanism
iOS enforces, and they are now pinned at both the request and the ceiling —
but nothing here watches the extension actually be *denied* a read on real
hardware. Closing that honestly needs a device build with a DEBUG-only probe
that attempts a cross-group read and reports the `OSStatus`.

Whether that is worth shipping probe code into the extension is a judgement
call, not an oversight. Recorded as open rather than quietly rounded up to
verified.

## Carried debt, now dispositioned

Two items have been re-listed as "Open, carried" by every audit since 1.1.0
with no intent to act on either. Both are now closed as **won't-do**, with the
reasoning and the reopening condition recorded in
`~/Documents/Claude-KB/decisions/2026-08-13-pacelli-carried-debt-disposition.md`:

- **Passphrase-encrypted export** — the plaintext is the feature. An export
  the user cannot open without Pacelli is a worse backup than none. The threat
  model that would justify it (an attacker reading the app's tmp directory)
  has already lost. *Reopens if an importer lands* — a tampered import is a
  code path into the household and needs integrity protection, which is a
  different fix.
- **Push rate limiting** — the only actor who can trigger it is an existing
  household member and the ceiling is household size. *Reopens if households
  routinely exceed ~10 members, or if any join path admits someone without an
  existing member's deliberate act.*

**Still genuinely open:** Face ID keychain gating (since 1.0) — the household
key comes out of the keychain on an unlocked phone with no further check. That
is the real gap and the intended headline of 1.5.0.

**Verdict: PASS.** No finding. The Phase C promise is now enforced rather than
asserted, and the one part still resting on Apple's enforcement rather than
our observation is named above.
