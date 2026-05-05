# Firestore rules tests

Locks the security rules the Pacelli client depends on — chiefly the
`household_members` self-delete path that the burn-all-data orphan sweep
relies on.

## One-time setup

```bash
cd firestore-tests
npm install
```

## Run

```bash
npm test
```

This spins up a local Firestore emulator on the fly via
`firebase emulators:exec`, runs the Jest suite against `../firestore.rules`,
then tears the emulator down.

## What's covered

- A user CAN delete their own member doc, even when `household_id` is
  null/missing (orphan state from pre-migration data).
- A user CANNOT delete another user's member doc when not co-resident.
- A co-member CAN delete another member's doc in the same household
  (used by burn cascade in `_wipeHouseholdData`).
- An unauthenticated request CANNOT delete any member doc.
- Read access scoped to owner + household co-residents.

## Why this exists

App Store Guideline 5.1.1(v) requires in-app account deletion. Pacelli's
burn flow performs this via `wipeAllData` → orphan-sweep on
`household_members` keyed by `user_id`. If the rule that allows
self-delete is ever tightened to require `isMember(household_id)`, users
with stale orphan member docs would silently fail to fully wipe — which
is both a privacy issue and an App Store rejection vector. This test
catches that regression.
