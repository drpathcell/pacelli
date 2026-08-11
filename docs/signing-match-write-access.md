# Releases are blocked on one credential

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

## The fix (only Juan can do this)

`MATCH_GIT_URL` is a plain HTTPS URL with no credentials. CI's built-in
`GITHUB_TOKEN` only grants write access to the `pacelli` repo, not to
`pacelli-match-certs`.

1. Create a fine-grained personal access token with **Contents: read & write**
   on `drpathcell/pacelli-match-certs` only.
2. Update the repo secret `MATCH_GIT_URL` to embed it:

   ```
   https://x-access-token:<TOKEN>@github.com/drpathcell/pacelli-match-certs.git
   ```

3. Re-run the **Signing (match)** workflow (Actions → Signing (match) → Run
   workflow). It will store both profiles.
4. Then tag the release normally.

Do not paste the token anywhere else; the secret is the only place it belongs.

## Until then

- `main` carries the full Phase B + Phase C work, built and proven on the
  simulator.
- **Tagged releases will fail** — the Matchfile now lists the extension's
  identifier, and its profile is not in the repo. Nothing auto-tags, so this
  blocks only a deliberate release.
- Already-shipped versions are unaffected: 1.3.0 is live, and 1.3.1 is in
  review on build 40, which was uploaded before any of this.

## Worth remembering

This is the second time today a signing job reported success while doing
nothing. The first was `sync_signing` hardcoding `app_identifier`, so the
extension was never synced at all; the second was this silent 403. **A fastlane
lane finishing green says the lane ran, not that it achieved anything** — check
the artefact (does the profile exist in the repo?), never the exit status.
