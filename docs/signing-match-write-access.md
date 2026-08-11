# Releases were blocked on one credential — RESOLVED 2026-08-11

**Resolved.** A deploy key scoped to `pacelli-match-certs` now gives match
write access; both profiles are stored in the repo and build 41 — the first
build containing the notification extension — signed, uploaded and validated.

Kept as the record of how it failed, because the failure shape recurs.

**Symptom:** a tagged release fails at `match` with

```
No matching provisioning profiles found and cannot create a new one
because you enabled `readonly`.
```

**Cause, from the signing run's own log (2026-08-11):**

```
🔒  Successfully encrypted certificates repo
Pushing changes to remote git repo...
remote: Write access to repository not granted.
fatal: unable to access 'https://github.com/drpathcell/pacelli-match-certs.git/':
       The requested URL returned error: 403
Couldn't commit or push changes back to git...
```

match created the notification extension's provisioning profile **in the Apple
developer portal** — it is there and ACTIVE — but could not store it in the
certs repo. fastlane treats that push failure as non-fatal, so the signing job
finished **green having persisted nothing**. Release builds run `match` in
readonly mode, read from the repo, find no profile, and fail.

## The fix — one command left

A **deploy key** was chosen over a personal access token: it is scoped to
`pacelli-match-certs` alone and can do nothing else, whereas a PAT carries
account-level reach. Already done:

- ed25519 keypair generated at `~/.ssh/pacelli_match_deploy`
- public half registered on the certs repo with write access (key id 159961087)
- `Matchfile` switched to `git@github.com:...` — SSH, so the key applies
- both workflows load the key, pin `known_hosts`, and **prove it can reach the
  repo before fastlane runs**, so a silent 403 cannot happen again
- `MATCH_GIT_URL` removed from both workflows: if it is set it overrides the
  Matchfile and the credential-less HTTPS URL comes back

The private half was stored as the repo secret `MATCH_DEPLOY_KEY`:

```bash
gh secret set MATCH_DEPLOY_KEY < ~/.ssh/pacelli_match_deploy
```

Verified by cloning the certs repo and listing its contents — not by reading a
job's exit status, which is what hid this twice:

```
profiles/appstore/AppStore_com.pacelli.pacelli.mobileprovision
profiles/appstore/AppStore_com.pacelli.pacelli.NotificationService.mobileprovision
```

## Worth remembering

This is the second time today a signing job reported success while doing
nothing. The first was `sync_signing` hardcoding `app_identifier`, so the
extension was never synced at all; the second was this silent 403. **A fastlane
lane finishing green says the lane ran, not that it achieved anything** — check
the artefact (does the profile exist in the repo?), never the exit status.
