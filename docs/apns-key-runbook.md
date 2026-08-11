# APNs auth key — the 5 minutes only Juan can do

Phase B (push: telling the *other* person something happened) needs an APNs
auth key. This is the one step in the whole pipeline that cannot be scripted.

**Why it isn't automated.** Verified 2026-08-11, not assumed:

- The App Store Connect API has no auth-key endpoint (`/v1/authKeys`,
  `/v1/apiKeys`, `/v1/pushCertificates` all 404) and its `/v1/certificates`
  endpoint rejects every push type — it accepts only
  `APPLE_PAY*, DEVELOPER_ID*, DEVELOPMENT, DISTRIBUTION, IDENTITY_ACCESS,
  IOS_DEVELOPMENT, IOS_DISTRIBUTION, MAC_*, PASS_TYPE_ID*`.
- The Firebase CLI (15.8.0) has no FCM/APNs credential command. Uploading the
  key is Console-only.
- Driving developer.apple.com in Chrome stops at the Apple ID sign-in: there is
  no Apple session in Chrome (`appstoreconnect.apple.com` → `authResult=FAILED`),
  and signing in needs the password plus a 2FA code from a trusted device.

**`AuthKey_MMWTC97VR7.p8` will NOT work for this.** That is the App Store
Connect API key. APNs keys are a separate kind, issued from a different page.

## Values you'll need

| Field | Value |
|---|---|
| Team ID | `5PCNU95W9V` |
| Bundle ID | `com.pacelli.pacelli` |
| Firebase project | `pacelli-35621` (Pacelli) |
| Apple ID | `juancarlos.celis@outlook.com` (account holder) |

## Step 1 — create the key (developer.apple.com)

1. https://developer.apple.com/account/resources/authkeys/list → **+**
2. Name it `Pacelli APNs`.
3. Tick **Apple Push Notifications service (APNs)**.
4. Continue → Register → **Download**.
   The `.p8` downloads **once and only once**. If it is lost the key must be
   revoked and a new one made.
5. Note the **Key ID** shown on the page (10 characters, in the filename too:
   `AuthKey_<KEYID>.p8`).

Put the file somewhere safe and out of git — e.g. `~/.config/jarvis/secrets/`.
It must not land in `~/Developer/pacelli`.

## Step 2 — upload it to Firebase

1. https://console.firebase.google.com/project/pacelli-35621/settings/cloudmessaging
2. Under **Apple app configuration** → the `com.pacelli.pacelli` app →
   **APNs Authentication Key** → **Upload**.
3. Give it the `.p8`, the **Key ID** from step 1, and Team ID `5PCNU95W9V`.

## Step 3 — tell Claude

Say "APNs key is in Firebase" and Phase B gets built and verified:
FCM token registration on the client, the Cloud Function that copies the
already-encrypted title ciphertext into the APNs payload, and the
Notification Service Extension that decrypts it on the device.

Phase C (the extension) needs a Keychain access group, so it gets a security
audit addendum before it ships — that is deliberate, not a delay.
