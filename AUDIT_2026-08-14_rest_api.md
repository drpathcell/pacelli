# REST API audit — the surface an AI would write through

**Date:** 2026-08-14 · **Scope:** 71 deployed Cloud Functions (`functions/src/`), `openapi/pacelli-api.yaml`, `mcp-server/`
**Why:** before granting an AI write access to the household, per Juan's 1.6.0 request.
**Verdict: the API was unusable for its intended purpose. Two defects fixed, one open, one large scoping problem.**

## Context

The API predates the native rewrite — it was built for the Flutter app
(`6d4bfeb`) and has never been through any native-era audit. Cloud Functions use
the Admin SDK, so **every Firestore rule is bypassed**; none of the 1.1.1/1.2.0
rules hardening protects these paths. Whatever correctness exists has to be in
the handlers themselves.

Server-side decryption is legitimate here and not a finding: `deriveUserKey(uid)`
takes only the uid, and `AUDIT_2026-08-01_native.md` records that
"operator-level access was never in the threat model."

---

## F1 — CRITICAL, FIXED. Nothing the API created was visible in the app.

**All 25 create sites, across 6 handler files, omitted the `id` field.**

The app parses from document *fields* and never injects the document path:

```swift
guard let item = ChecklistItem(map: data) else { continue }
```

Seven models require `map["id"]`. So an API-created task, subtask, category,
checklist, checklist item, plan or plan entry was **silently skipped** — no
error, no empty state, just absent. The API returns 200 either way, so neither
side could detect it.

An AI given write access would have produced clean 200s and nothing the user
could see. This is the single most important finding: the feature would have
looked like it worked.

Proven per-entity, not inferred — `ApiWireContractTests` feeds the API's actual
field shapes into the app's parsers; all six failed before the fix.

## F2 — HIGH, FIXED. Checklist quantity was encrypted by one writer only.

The API encrypted `quantity` (`encN`); the app writes and reads it raw. So an
API-created item showed a base64 blob in the Qty field, and an app-created item
came back from the API as `null` because decrypting plaintext fails.

The API now matches the app. The app won because it is the live writer with
existing plaintext data on real devices. **Encrypting quantity properly remains
open** — it is a schema migration, not a patch.

## F3 — HIGH, OPEN. Every plan endpoint writes to a dead collection.

- App (`PlansRepository.swift`): `scratch_plans`
- API (`functions/src/functions/plans.ts`): `plans`
- `firestore.rules`: defines `scratch_plans` and `plan_entries` — **no `plans` block at all**

So ~20 plan endpoints write into a collection the app never reads and no client
could read even if it tried (default deny). Admin SDK means the writes succeed
silently. Not fixed in this pass because it is a behavioural change to 20 live
endpoints and deserves its own step.

## F4 — MEDIUM, BY DESIGN. Half the surface has no app UI.

Collections the API writes that the app never reads:
`inventory_items`, `inventory_categories`, `inventory_locations`,
`inventory_logs`, `inventory_attachments`, `task_attachments`,
`plan_attachments`, `plans`, `diagnostics`, `weekly_digests`.

Roughly 30 of 71 functions. Not broken — unobservable. An AI told to "add
paprika to the inventory" would succeed and the user would never see it, because
there is no inventory UI. **The AI tool surface must be curated to what the app
actually shows.**

## F5 — GAP. Two app features have no API at all.

- `manual_entries` — the household manual
- `checklist_templates` — added 2026-08-14

Both are things an AI should plausibly touch. Neither is reachable.

---

## Verified clean

- **Authorisation: 29 of 29 by-id handlers verify `household_id` against
  `ctx.householdId`.** One initial flag (`generateWeeklyDigest`) was a false
  positive in my scan — it takes no id and scopes every query to the caller's
  household.
- **No handler reads `household_id` from the request body** — no cross-household
  access despite the Admin SDK.
- **No membership, household or key write surface.** The 1.2.0 `joined_via`
  proof requirement therefore cannot be bypassed via the API. The only key write
  is a legitimate v1→v2 rewrap of the caller's own wrapped key.
- **Delete cascades are correct** — `deleteChecklist` batch-deletes its items,
  household-scoped, matching the app.
- **Timestamps were never a problem.** `DartISO8601` parses JavaScript's
  `toISOString()` shape (3-digit fraction + `Z`), which the existing date suite
  never covered. Now pinned.
- **Feedback handles the developer seal correctly** — returns
  `sealedForDeveloper: true` rather than faking a decryption it cannot do.
- Rate limited per uid: 100 reads/min, 30 writes/min, 500/hr.
- Deployed functions and source exports match exactly: 71 and 71, no orphans.

## Regression guards added

Neither writer can see the other, so both sides are pinned:

| guard | side | asserts |
|---|---|---|
| `ApiWireContractTests` | Swift | the app can parse the API's document shapes |
| `scripts/verify_api_wire.py` | TypeScript | every create writes `id`; quantity is not encrypted |

`verify_api_wire.py` was checked to go red: deleting one `id: ref.id` fails it
and names the file and line.

## Before an AI gets write access

1. **Deploy the F1/F2 fix.** Until then the API is still writing invisible
   documents in production.
2. **Decide F3** — point plans at `scratch_plans`, or exclude plans from the AI
   surface.
3. **Curate the tool surface to F4** — expose only what the app renders.
4. **Fill F5** if the AI should reach the manual and templates.
5. **Solve credentials.** Firebase ID tokens last one hour. "Any AI the user
   gives access" needs something durable, scoped and revocable. This is the
   actual unsolved design problem — decryption never was.
