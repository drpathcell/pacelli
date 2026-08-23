# Pacelli security audit — 1.8.0 addendum: the photo layer

**Scope:** what 1.8.0 adds. Commits `3077598`, `4ea2940`, `ee4810b`, plus the
Node 22 runtime move and the export change. Not a full re-audit — the
2026-08-01 baseline and its addenda still stand.

**Verdict: PASS, with one MEDIUM accepted by design and two LOW open.**

Phase 1 re-run as a gate: **PacelliKit 74 tests / 12 suites green**, including
every cross-language vector. That matters more than usual this time, because
the string encryption path was *rewritten* to sit on top of a new byte path.
The vectors are what prove that refactor is byte-identical.

---

## What is new

The largest single change to the app's data model since the rewrite. A photo is
three things at once: a plaintext JPEG on a member's device, an encrypted object
in a Cloud Storage bucket that did not exist yesterday, and a Firestore document
holding an encrypted thumbnail and the encrypted text Vision read on-device.

## [PASS] Crypto — one construction, two entry points

`PacelliCrypto.encrypt(_: Data)` and `encrypt(_: String)` are now the same code:
the string form is `Data(utf8)` in, base64 out. Same in TypeScript
(`encryptBytes` / `encrypt`). There is no second AES anywhere.

| Check | Result |
|---|---|
| Fresh 16-byte IV per call, `SecRandomCopyBytes` | PASS |
| Raw `IV ‖ ct` for blobs; base64 only for the string path | PASS |
| 17-byte floor enforced on the byte path | PASS (`BlobCryptoTests`, 0…16 all throw) |
| Non-UTF-8 bytes survive | PASS |
| Wrong key cannot open it | PASS |
| Every pre-existing cross-language vector | PASS, unchanged |

Observed at runtime: a 15597-byte JPEG becomes **15616 bytes at rest** — 16 IV
plus PKCS7 padding to the block. If a stored object ever begins `ffd8`, it was
never encrypted, and `check_photo_e2e.sh` fails on exactly that.

## [PASS] The bucket is unreachable

`storage.rules` denies **every path to every client**. No member, no assistant,
no stranger has any standing credential for `pacelli-35621-photos`.

Access is a v4 signed URL, minted by `photoUploadUrl` / `photoDownloadUrl` after
`authenticateRequest` and a check that the photo document belongs to the
caller's household. Fifteen minutes, one object, one verb.

This replaced a rules-based design that could not be made to work — see
`Claude-KB/decisions/2026-08-22-pacelli-photo-authorisation.md`. The result is
stricter than the plan: URLs expire, and "member" has one definition rather
than two.

Note the content type is still enforced, but by the *signature* rather than a
rule: the URL is minted for `application/octet-stream`, and GCS rejects a PUT
whose Content-Type does not match.

## [PASS] Deletion reaches all three stores

`onPhotoDeleted` removes the object when the document goes. Burn walks
`householdContentCollections`, which now lists `photos`, so the blobs go with
the documents without burn knowing Cloud Storage exists.
`PhotoStore.deleteEverything()` handles the local plaintext in
`clearLocalState`, before the keychain is cleared.

**Proven by replay**, which is the only proof worth having here: mint a download
URL, delete the document, replay the still-valid URL. A surviving object would
be an orphan nobody would ever notice.

## [PASS] Location data comes off

`ImagePrep` goes through `CGImageSourceCreateThumbnailAtIndex`, which returns a
bare `CGImage` carrying no metadata at all, then re-encodes with only a
compression setting. GPS removal is therefore a property of the pipeline rather
than a list of EXIF tags somebody has to keep current. HEIC normalises to JPEG
and the 2048px downscale happen in the same pass.

## [MEDIUM — accepted] Readable photos sit outside the app lock

`Documents/Photos/{householdId}/{photoId}.jpg` is plaintext, and
`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` put it in the iOS
Files app under Pacelli.

That is the feature: Juan asked for photos stored locally so the household
controls them, and a folder you cannot open is not control. But it has a
consequence worth stating plainly — **the app lock does not cover it**. Someone
holding an unlocked phone can read the household's photos through Files without
ever opening Pacelli, even with "Require Face ID" on.

Everything else Pacelli stores locally is either ciphertext or in the keychain,
so this is a genuine change in posture rather than an oversight.

*Accepted*, because the alternative removes the thing that was asked for. The
Privacy & encryption screen says the folder exists and is openable in Files.
**Recommended for 1.9.0:** one more sentence there saying the app lock does not
extend to it, so the trade is the user's to make knowingly.

The files are excluded from iCloud backup (`isExcludedFromBackup`), so the
plaintext still never leaves the device.

## [PASS — by decision] An assistant can see the pictures

`photosGet` with `includeImage` downloads the object, decrypts it with the
household key server-side, and returns base64. Juan's explicit call.

Worth being exact about what it does and does not change. It does **not** cross
a new boundary: `createFieldCrypto` has decrypted task titles, checklist items
and manual entries in this same process on this same key since the API shipped.
It does mean an assistant session is enough to read every photo in the
household — which is what "the AI should be able to see the images" means, and
why revocation (`aiLinkRevoke`, killing the session before deleting the row)
matters more than it did yesterday.

Nothing is logged and no plaintext is written anywhere in the function.

## [PASS] Firestore rules for `photos`

```
allow read:   isMember(resource.data.household_id)
allow create: isMember(request.resource.data.household_id)
              && request.resource.data.created_by == request.auth.uid
allow update, delete: isMember(resource.data.household_id)
```

Consistent with every other collection. A member can delete another member's
photo, which is the same latitude members already have over tasks and
checklists.

## [PASS] Recognition stays on the device

`PhotoIndexer` runs `VNRecognizeTextRequest` and `VNClassifyImageRequest`
locally; the output is encrypted with the household key before it is written.
No image and no derived text is sent anywhere to be read. Search over it is
client-side, because the server cannot read the fields.

## [LOW] The pairing-code pasteboard item is still unbounded

Carried from `AUDIT_2026-08-21_ai_link.md`, unchanged. `expirationDate` on
`setItems(_:options:)` in 1.9.0.

## [LOW] The assistant label is still plaintext

Carried, unchanged.

## Runtime and dependencies

- **Node 20 → 22** across all 81 functions, `firebase.json`, `package.json`
  engines and both CI workflows. Node 20 decommissions 2026-10-30. The whole
  photo pipeline was re-run against the new runtime end to end afterwards.
- `FirebaseStorage` was added as an SPM dependency and then removed. The app
  never touches the bucket directly, so the SDK was attack surface and binary
  weight for a relationship the design does not have.
- The export now produces a zip containing readable JPEGs when a household has
  photos. It was already plaintext by design and warned about; the warning text
  now names the photos explicitly, and the tmp sweep covers the zip and the
  working folder as well as the JSON.

## Verification for this addendum

| Gate | Result |
|---|---|
| PacelliKit `swift test` | 74/74 |
| `functions` jest | 76/76 |
| `check_photo_e2e.sh` (plaintext on device, ciphertext at rest, assistant sees it, deletion cascades) | PASS |
| `check_photo_storage.py` (signed URLs, stranger refused, object dies with document) | PASS |
| `check_ai_link_e2e.sh` (unchanged, after the FunctionsClient refactor) | PASS, all three negative controls |
| Native CI | 5/5 |
| Re-run of the whole photo path on Node 22 | PASS |

## Carried to 1.9.0

1. ~~A sentence on the Privacy screen: the app lock does not cover the Files
   folder.~~ **Done in 1.8.0 (build 47).** A rebuild was forced by the
   `PhotoIndexer` continuation crash below, so this went in with it rather than
   waiting a release.
2. `expirationDate` on the pairing-code pasteboard item.
3. Encrypt the assistant label.
4. `household_members` update/delete restricted to admins-or-self, gated on the
   burn E2E — carried from the 1.7.0 audit and now more relevant, since a
   member can be an LLM that can also read every photo.


## [FIXED in build 47] `PhotoIndexer` trapped on every Vision failure path

Found on 2026-08-23 while capturing the 1.8.0 screenshots — the app died the
moment the capture flow left the photo screen, and the crash report named
`CheckedContinuation.resume` with nothing pointing at Vision.

`recogniseText` and `classify` both wrapped `VNImageRequestHandler.perform` in
`withCheckedContinuation`, resuming from the request's completion handler and
again from the `catch`. Vision is not either/or: when a request fails it calls
that request's completion handler with the error **and** rethrows. Both halves
ran, the continuation was resumed twice, and Swift trapped the process —
`EXC_BREAKPOINT`, no exception name, no Vision symbol above the trap.

Severity is the whole feature: indexing runs on every photo attached, so any
Vision failure killed the app seconds after the user added a picture. It was
live in build 46, which is what 1.8.0 would have shipped.

The continuation is gone rather than guarded. `perform` is synchronous and
leaves its output on the request, so the results are read after it returns and
a throw yields an empty index. A shape that cannot be resumed twice beats a
flag that says not to.

**Why the harness was green.** `flow_photo_01_attach` ended on the line that
asserts the thumbnail — while indexing was still running — and
`flow_photo_02_gallery` opens with `stopApp`. A process that died between the
two left no trace in either. The flow now waits out indexing and makes the app
prove it is still alive before it ends.
