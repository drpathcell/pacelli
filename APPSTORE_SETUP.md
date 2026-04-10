# App Store Release Setup — Action Checklist

Everything here requires your credentials. Do these once, then CI handles it forever.

---

## 1. Apple Setup

### 1a. App Store Connect API Key (replaces password auth)
1. Go to [App Store Connect → Users & Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/api)
2. Generate a new key with **App Manager** role
3. Download the `.p8` file (once only — save it)
4. Note: **Key ID** and **Issuer ID**
5. Base64-encode the `.p8`:
   ```bash
   base64 -i AuthKey_XXXXXXXX.p8 | tr -d '\n'
   ```
6. Add to GitHub Secrets:
   - `ASC_KEY_ID` — Key ID (e.g. `ABC123DEFG`)
   - `ASC_ISSUER_ID` — Issuer ID (UUID format)
   - `ASC_KEY_CONTENT` — base64-encoded .p8 content

### 1b. Create the app in App Store Connect
1. [My Apps → +](https://appstoreconnect.apple.com/apps) → New App
2. Platform: iOS, Name: **Pacelli**, Bundle ID: `com.pacelli.pacelli`
3. SKU: `pacelli-001`
4. Primary language: English (UK) or English (US)

### 1c. Create a private Git repo for match certificates
Match stores encrypted certs + profiles in a private repo.
1. Create a new **private** GitHub repo (e.g. `github.com/YOUR_ORG/pacelli-certs`)
2. Add to GitHub Secrets:
   - `MATCH_GIT_URL` — e.g. `https://github.com/YOUR_ORG/pacelli-certs.git`
   - `MATCH_PASSWORD` — strong passphrase (encrypt the repo contents)
   - `MATCH_KEYCHAIN_PASSWORD` — any string (used for CI keychain)
   - `APPLE_ID` — your Apple ID email
   - `ITC_TEAM_ID` — App Store Connect team ID (from App Store Connect URL or `fastlane env`)

### 1d. Run match locally to generate certs + profiles (one-time)
```bash
cd ~/Developer/pacelli
bundle install
bundle exec fastlane match appstore    # generates + stores App Store distribution cert
bundle exec fastlane match development # generates + stores development cert
```
This populates your private certs repo. CI uses it read-only from then on.

---

## 2. Android Setup

### 2a. Generate the release keystore (one-time — NEVER lose this file)
```bash
keytool -genkey -v \
  -keystore ~/pacelli-release.keystore \
  -alias pacelli \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```
**Back this up to a password manager.** Losing it = can never update the app on Play Store.

### 2b. Base64-encode the keystore for CI
```bash
base64 -i ~/pacelli-release.keystore | tr -d '\n'
```

### 2c. Add to GitHub Secrets:
- `ANDROID_KEYSTORE_BASE64` — base64 keystore from step above
- `ANDROID_STORE_PASSWORD` — password you chose for the keystore
- `ANDROID_KEY_PASSWORD` — password for the key alias
- `ANDROID_KEY_ALIAS` — `pacelli` (or whatever you set)

### 2d. Create app on Google Play Console
1. [Google Play Console → Create app](https://play.google.com/console)
2. App name: **Pacelli**, Default language: English
3. App or Game: **App**, Free or Paid: **Free** (change later if needed)

### 2e. Create a Google Play API service account
1. Google Play Console → Setup → API access → [Google Cloud Console](https://console.cloud.google.com)
2. Create a service account with **Release Manager** role
3. Download JSON key
4. Back in Play Console, grant the service account access
5. Add to GitHub Secrets:
   - `GOOGLE_PLAY_JSON_KEY` — contents of the JSON key file

---

## 3. Trigger a Release

Once all secrets are set, tag a commit:
```bash
git tag v1.0.0+1
git push origin v1.0.0+1
```

This triggers `.github/workflows/release.yml` which:
- Builds a signed iOS IPA → uploads to TestFlight
- Builds a signed Android AAB → uploads to Play Store internal track

---

## 4. GitHub Secrets Summary

| Secret | Source |
|--------|--------|
| `ASC_KEY_ID` | App Store Connect API key |
| `ASC_ISSUER_ID` | App Store Connect API key |
| `ASC_KEY_CONTENT` | Base64-encoded .p8 |
| `MATCH_GIT_URL` | Private certs repo URL |
| `MATCH_PASSWORD` | Your passphrase for match |
| `MATCH_KEYCHAIN_PASSWORD` | Any string |
| `APPLE_ID` | Your Apple ID |
| `ITC_TEAM_ID` | App Store Connect team ID |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded .keystore |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | Key alias (e.g. `pacelli`) |
| `GOOGLE_PLAY_JSON_KEY` | Google service account JSON |
