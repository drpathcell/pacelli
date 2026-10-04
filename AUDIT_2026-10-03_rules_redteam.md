# Firestore rules red-team audit - 2026-10-03

Tool: `firebase-security-rules-auditor` (firebase/agent-skills @ de359da, vendored in `.claude/skills/`), run by an independent agent over `firestore.rules` (538 lines) and `storage.rules`.
The top two findings were re-checked by hand against the rule text. **No rules were changed. Nothing was deployed.**

Score: 1/5 (critical). `storage.rules`: no findings (fully closed).

## Confirmed by hand
### C1 - Retargeting a join code lets you join another household (L264)
`allow update, delete: if isAuth() && isMember(resource.data.household_id);` checks only the OLD household.
1. The attacker founds or belongs to household A and creates code X for A (L259-263 pass).
2. The attacker updates X to `household_id = B`. A new `expires_at` passes too, because the 8-day window is enforced only on create.
3. The attacker creates `household_members/{me}` with `household_id = B` and `joined_via = X`. `holdsJoinCode(B, X)` is true, so `joinAuthorised` passes.

Precondition: knowing B's household ID (a UUID). Ex-members, removed members and anyone shown the ID qualify.
Fix: `allow update: if false;` (regenerate = delete + create), or freeze `household_id`, `created_by` and `expires_at` on update.

### C2 - Same pattern via invites (L275), made worse by unverified email and replay
- Members can rewrite an invite's `household_id` and `invited_email`. `invitedByEmail()` (L51-57) then authorises the join.
- `invitedByEmail()` does not check `status == 'pending'`, so accepted invites can be replayed. A removed member can rejoin by creating a member doc that reuses their old invite ID.
- No `email_verified` check (L56, L270).

Fixes:
- On member update (L275), add `request.resource.data.household_id == resource.data.household_id && request.resource.data.invited_email == resource.data.invited_email`.
- In `invitedByEmail`, add `&& get(...).data.status == 'pending' && request.auth.token.email_verified == true`.
- Check how the accept batch orders the status flip versus the member create: the member create must still see `pending`.

## Reported, not yet hand-verified
- **M1:** `household_id` can be changed on update in every content collection (L301-407, L490, photos L526). This allows cross-household injection and moving data out of a household. Fix: `&& request.resource.data.household_id == resource.data.household_id` on each update.
- **M2:** `weekly_digests` create/update (L497) checks only the new document, so another household's digest can be taken over if digest IDs are guessable. There is also no delete rule, so burn may leave digests behind.
- **Mo1:** Photos `created_by` and `household_id` are mutable on update. Check `functions/src/functions/photos.ts` derives the storage path server-side.
- **Mo2:** `feedback` create is untyped and unbounded (`context`, `id`, `household_id`).
- **Mo3:** `household_keys` doc ID is not pinned, which opens a pre-creation denial of service if IDs are deterministic.
- **Mo4:** The founding branch reopens once `households/B` is deleted while content remains (check burn ordering).
- **Mi1:** No size or type caps on households and profiles. Profiles are readable by any signed-in user.

## Next
Fix C1 + C2 + M1 behind emulator tests (each exploit sequence as a failing test first), then run the pacelli-security-audit skill, then deploy. This needs Juan's go-ahead (production rules, shared app).

---

## Resolution - 2026-10-04 (rules only, not yet deployed at time of writing)

Method: each exploit written as an emulator test in `firestore-tests/redteam-2026-10-03.test.js` and **run RED against the old rules first** (33 of 37 failed, the 4 controls passed), then the fix, then the full suite. Final: **12 suites, 176 tests, all green.** A cold independent re-review of the fixed rules followed and found X1 below, which was also run red before its fix.

| ID | Verdict | Fix (firestore.rules) |
|---|---|---|
| C1 join-code retarget / expiry stretch | [FAIL -> FIXED] CRITICAL | `household_join_codes` update `if false` (regenerate is create + delete) |
| C2 invite retarget / readdress / reset to pending | [FAIL -> FIXED] CRITICAL | member update freezes `household_id`, `invited_email`, `status` |
| C2 replay of an accepted invite | [FAIL -> FIXED] HIGH | `invitedByEmail`: `get().status == 'pending'` AND `getAfter().status == 'accepted'` (the join must consume the invite in the same write) |
| **X1 forged membership via unpinned member doc ID (NEW)** | [FAIL -> FIXED] **CRITICAL** | member create: `docId == uid + '_' + household_id`. `isMember()` trusts the doc NAME, so anyone (anonymous guest included) could create `{me}_{B}` with the body pointed at an unused household ID and become a member of B, then unwrap the household key from B's invites and join codes |
| M1 content `household_id` mutable | [FAIL -> FIXED] HIGH | `householdUnchanged()` on update, all 19 content collections |
| M2 weekly_digests takeover + no delete | [FAIL -> FIXED] HIGH | client create/update `if false` (admin SDK only), delete for members. The missing delete also broke last-person-out account deletion for any household with a digest |
| Mo1 photos `household_id` / `created_by` mutable | [FAIL -> FIXED] MEDIUM | both frozen on update |
| Mi1 profiles enumerable by any signed-in user | [FAIL -> FIXED] MEDIUM | `get` only, `list` denied. Get-by-uid stays open (uids are not enumerable) |
| Mo2 feedback any `household_id` | [ACCEPTED] | deliberate since 2026-08-11, message sealed to the Pacelli key |
| Mo3 household_keys doc ID not pinned | [PASS] | every client write uses a random ID (`addDocument` / `document()`), no pre-creation target |
| Mo4 founding branch reopens if `households/B` is deleted while members remain | [INFO] open | needs an insider to delete the household doc first. Fold into the owner-deletion work (delete members and content before the household doc) |
| E1 email_verified not checked on invites | [FAIL -> FIXED] HIGH (Juan, 2026-10-04) | `verifiedEmail()` on invite read, accept and join proof. Prod 2026-10-04: 19 users = 14 anonymous + 5 Apple (all verified), 0 email/password, 0 Google, so it affects nobody today. A future email/password user joins by code until the app sends verification mail |
| Join codes multi-use until expiry | [ACCEPTED] LOW | by design (a household shares one code). A removed member can rejoin with a still-live code: regenerate after removing someone |
| Size caps on households / profiles | [ACCEPTED] LOW | defence in depth, not a boundary |

Regression check (independent reviewer, file:line verified): every client write to the changed collections still passes. Content `setData` calls are creates with fresh UUIDs, every `updateData` sends only the changed fields, photos never touch `household_id`/`created_by`, profiles are only fetched by uid, the app never writes digests or updates codes, and invites are only created, deleted or accepted in the batch. No live-version bump needed (live 1.11.2 batches the invite accept).

Production scan for X1 (read-only, Firestore REST, 2026-10-04): **17 member docs, 17 well-formed, 0 forged.** The classifier was checked against synthetic ok / forged / legacy docs first.
