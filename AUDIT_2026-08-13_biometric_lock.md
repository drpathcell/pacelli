# Security addendum — Face ID app lock (1.5.0, unreleased)

**Date:** 2026-08-13 · **Commits:** 77a0eca (implementation), a744e94 (harness)
**Closes:** "Face ID keychain gating" — open since 1.0, and closed differently from how it was written down.

## Why it is not keychain gating

The item was recorded for four releases as `kSecAccessControl` /
`.biometryCurrentSet` on `hk_<householdId>`. That is unavailable to us, and
1.4.0 is the reason.

The notification service extension reads that key to decrypt a push title. It
runs headless, in the background, with no user present, so
`SecItemCopyMatching` on a user-presence-guarded item returns
`errSecInteractionNotAllowed` — every time, not sometimes. Keychain gating
therefore costs every decrypted notification, permanently: the whole feature
1.4.0 shipped, traded for it.

So the gate is on the app. The key keeps
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

## What it buys, and what it does not

**Buys:** a person holding your unlocked phone cannot read the household — a
guest, a child, a repair counter. The realistic threat for a family app.

**Does not buy:** protection from Keychain extraction — forensics, jailbreak,
backup attack. The key is still readable by the app's own process without user
presence, *because the extension requires exactly that*. Anyone arriving here
looking for at-rest-under-duress protection: it is not here, and adding it
costs decrypted notifications.

## Verified on hardware

Real iPhone 17 Pro Max, iOS 26.6, development build, real Face ID — confirmed
by Juan 2026-08-13:

- Enabling does not challenge; **disabling does**. Someone holding the unlocked
  phone cannot simply switch the lock off in Settings.
- Return from background covers the content and fires Face ID **automatically**,
  with no tap.
- A **refused** face leaves nothing of the household readable behind the
  failure dialog.
- The **app-switcher card is covered** — the lock is drawn whenever the app is
  not frontmost, not only on return.

Also verified on simulator (state machine only, Features → Face ID): default
**off** on a clean install, so no existing user's launch changes.

## Design rules that are not obvious

- `LAPolicy.deviceOwnerAuthentication`, NOT `...WithBiometrics` — no enrolled
  face falls back to the passcode rather than being unable to unlock.
- The toggle is **hidden** where `canEvaluatePolicy` fails. Offering it on a
  passcode-less device locks the household away with no way back in.
- If biometry was available at enable-time and is not now (passcode removed,
  device restored), `unlock()` **yields**. A convenience lock must never become
  a data-loss event.
- A fresh `LAContext` per attempt; a reused one answers from a cached
  evaluation and every unlock after the first silently becomes a no-op.

`NSFaceIDUsageDescription` was inherited from the Flutter build and described
keychain gating that nothing implemented. Corrected, and the on-device prompt
was checked to confirm the new string shipped.

## Open

`scripts/check_lock_e2e.sh` is **not green**. Step 1 taps the switch at a fixed
percentage point and misses when the Settings list scrolls differently. It
fails loudly and names the cause rather than passing falsely, which is the
property worth keeping, but a layout-proof selector is the fix and is not done.
The hardware verification above was manual.

**Verdict: PASS.** The last open security item from the 1.0 audit is closed.
