# Security audit - 2026-09-23 - burn permissions, guest sweep, catalogue images

Scope: every security-relevant change since `AUDIT_2026-08-22_photos.md`
(commit c8f6c75), which is 1.9.0 through 1.11.1: 32 commits, ~2,700 lines.
Read against `firestore.rules`, `functions/src`, `PacelliApp/Sources` and
PacelliKit. Method: code reading, the rules suite, the functions suite and
`swift test`. No emulator run of the app, no device run.

Result: **one HIGH, four MEDIUM, three LOW, all fixed the same day.** Rules and
functions deployed; app changes ship as 1.11.2 (build 52).

## Findings

### [FAIL -> FIXED] HIGH - any member could make itself owner
`firestore.rules` households `delete` was `isMember`, and `create` only
required `created_by == caller`. Delete the household document, create it
again naming yourself: every member row survives, `isMember()` still passes,
and now `isHouseholdOwner()` does too. From there: rewrite `burn_permission`,
remove every other member, call `burnHousehold` as owner. A paired AI
assistant is a member like any other and could do all of it.

Fix: delete is allowed to the owner, or to a member once the owner's own
member row no longer exists. The second branch is the Guideline 5.1.1(v)
path: live `BurnService` deletes the household document when the last person
out is not the founder, so the rule had to keep that working against 1.11.1
before any app change. It does, which is why the rules went out first.

Test: `firestore-tests/household-refound.test.js`, 6 tests, run RED against
the old rule (3 failed: the assistant, the plain member, and the end-to-end
refound) and GREEN after. Suite 131/131.

Residual, accepted: once the owner has deleted their account, a remaining
member can still delete-and-refound and become owner of the others. There is
no owner to usurp at that point, and the INFO item below argues it may even be
the succession the app currently lacks. Not a promotion path against a
present owner.

### [FAIL -> FIXED] MEDIUM - the guest sweep could purge a household another guest was using
`sweepAbandonedGuests` refused to delete a household with "other human
members", where human meant an account with an email, phone or provider. A
household founded by an idle guest and shared with an ACTIVE guest passed
that check and was purged with the founder, including the active guest's
membership, key and content.

Fix: `protectsHousehold(user, now, minIdleMs)` in `maintenance.ts`: a person
always protects, a guest protects while inside the idle window, an assistant
or a vanished account never does. Five tests; negative control run (forcing
the guest branch to `false` reddens exactly "an ACTIVE guest protects it").

### [FAIL -> FIXED] MEDIUM - last person out left the assistant holding the keys
`BurnService.leaveHousehold` counted assistant rows as "other members", so the
last person's account deletion left every task, photo and wrapped key in
place with a live assistant attached, and the sweep never reclaims a
household that still has a member row.

Fix: only non-assistant rows count as people. When the last person leaves,
each assistant is revoked through `aiLinkRevoke` (session and key killed
before the row, and any member may call it) and then the household is wiped
as before. A revoke failure fails the deletion rather than leaving a live
assistant on an erased household. Ships in 1.11.2.

### [FAIL -> FIXED] MEDIUM - a member-written number could crash the app
`ChecklistItemDetailView` used `Int(pct.rounded())` and `Int(e.amount)`.
`Int(_:)` traps on NaN, infinity and anything outside its range. The server
checked `isFinite` only, and `checklist_items.source` is member-writable
directly in Firestore, so `1e300` from any member closed the app for
everyone opening that item.

Fix: `clampedInt` in the view (finite, clamped to +-1e9) and server-side
bounds (`amount` within +-1e6, `dailyPercent` 0...10000). Ships in 1.11.2.

### [ACCEPTED, COPY FIXED] MEDIUM - the burn setting does not stop direct deletes
Every content collection allows `delete` to any member, so the setting gates
the Delete data button and `burnHousehold`, not a member deleting rows one by
one. This was decided on 2026-08-25 (rules cannot tell a burn from tidying
up). What was wrong was the copy: "the only person who can erase the
household's shared data" promised a lock. The explanations and the footer
now say what the setting controls and that it is not a lock.

### [FIXED] LOW - catalogue images
- The SKU was written to Cloud Logging on every attach. Removed; the SKU is
  the product, which is the list.
- The plaintext cache was keyed on SKU only, so `{sku}_1` was served for
  `{sku}_2`. Keyed on index now.
- The plaintext `catalog/dunnes/{sku}` cache and the plaintext `content_hash`
  remain: both reveal which products SOME household added, not which. Accepted;
  the alternative is a per-household fetch from the retailer, which tells the
  retailer more.

### [FIXED] LOW - `resolveHouseholdId` used `limit(1)`
A caller in two households got whichever row came back first. Every API
caller today is an assistant, which is in exactly one, but a burn resolved
against the wrong household is not something to leave to ordering. Now
deterministic (lowest id) and logged when ambiguous.

### INFO, not changed
- `burn_allowed_uids` is not checked against membership on the server; the
  client filters. A stale uid grants nothing, it simply never matches.
- If the owner deletes their account, `created_by` names a deleted user and
  under the default policy nobody can burn or change the policy. Succession
  is a product decision.
- `SettingsView` says nobody operating the servers can open photos. The API
  decrypts them for assistants and encrypts catalogue copies. True of Apple
  and Google, not of the functions. Wording for Juan.

## Passes
- Burn policy read from the stored household document, never the request
  (`burn.ts`). Nothing deleted until the check passes. Batches of 400.
- `burnPolicyUnchanged()` compares both `burn_permission` and the whole
  `burn_allowed_uids` list. `created_by` frozen. Member role pinned on create,
  frozen on update.
- `sweepAbandonedGuests`: scheduled only, no HTTP surface, `lastRefreshTime`
  first, skips email/phone/provider/`ai_`/disabled, capped at 100 per run.
- New exports `burnHousehold` and `burnPolicy` both behind `apiHandler`.
- `imageUrl` accepted only for `https://images.cdn.dunnesstoresgrocery.com`
  with a path regex, redirects refused, 2 MB cap, JPEG header required. The
  app never opens the URL.
- Decryption failure shows `[encrypted]`, never ciphertext; a failed `source`
  parses as no source.
- No `print` or logger of keys or decrypted content in the changed files.
- PacelliKit `swift test` 82/82, five consecutive runs. The known CBC
  wrong-key flake (`FieldMigrationTests`) did not fire in those five.

## Wire format, for the envelope work that follows
Fields and photos share one unauthenticated format: AES-256-CBC, PKCS7, fresh
16-byte IV, laid out `IV || ciphertext`, no MAC. Fields are base64 of that;
photo objects are the raw bytes; thumbnails are base64 of the raw bytes in
the document. TS decrypt does not check the output is valid UTF-8; Swift
does. The authenticated envelope must therefore cover photo bytes
(`PhotoService`, `PhotosRepository`, `photos.ts`, `catalog-images.ts`) and
key wrapping (`KeyManager.swift`, `key-manager.ts`) as well as every field
repository. Full file:line inventory in the session note.

## Skill drift
`pacelli-security-audit` still describes the rewrite at Phase 4 of 7 and
lists burn, notifications and export as not built. It pointed this audit at
the wrong places; updated after this audit.
