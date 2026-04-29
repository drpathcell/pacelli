# Pacelli — App Store Launch Checklist

Everything I (Claude) already did is in **§ A**. Everything **you** need to
do — clicking buttons in Apple/Firebase/App Store Connect, taking
screenshots, hosting the privacy policy — is in **§ B**, in order.

---

## § A — Done (no action needed)

| # | Change | File |
|---|---|---|
| 1 | Encryption export compliance flag | `ios/Runner/Info.plist` (`ITSAppUsesNonExemptEncryption=false`) |
| 2 | Sign in with Apple capability | `ios/Runner/Runner.entitlements` |
| 3 | `sign_in_with_apple: ^6.1.4` added | `pubspec.yaml` |
| 4 | `AppleSignInService` (nonce + Firebase OAuth exchange) | `lib/features/auth/data/apple_sign_in_service.dart` |
| 5 | Reusable `AppleSignInButton` (iOS/macOS only) | `lib/features/auth/presentation/widgets/apple_sign_in_button.dart` |
| 6 | SIWA wired into login + signup screens | `login_screen.dart`, `signup_screen.dart` |
| 7 | ARB keys EN / ES / IT | `app_en.arb`, `app_es.arb`, `app_it.arb` |
| 8 | Privacy policy draft | `PRIVACY_POLICY.md` |
| 9 | `flutter pub get` ✅ + `pod install` ✅ + `flutter analyze` clean for new files | — |

---

## § B — Your turn, in this exact order

Estimated total time: **2–3 hours active**, plus 24–48 h waiting for App
Review at the end.

---

### Step 1 — Enable Sign in with Apple in the Apple Developer portal *(5 min)*

You added the entitlement; now Apple needs to know.

1. Open https://developer.apple.com/account/resources/identifiers/list
2. Find / click **com.pacelli.pacelli** in the list of identifiers.
3. Scroll to **Sign In with Apple** → tick the box → **Save**.
4. (Optional) Click **Configure** if you want to use SIWA on web/Android
   later. For now, default is fine.

> If `com.pacelli.pacelli` isn't there yet, click **+ → App IDs**,
> Bundle ID `com.pacelli.pacelli`, description "Pacelli", tick **Sign In
> with Apple** + **Push Notifications**, **Continue → Register**.

---

### Step 2 — Enable Apple as a Firebase Auth provider *(3 min)*

1. Open https://console.firebase.google.com/ → select your Pacelli project.
2. **Build → Authentication → Sign-in method** tab.
3. Click **Add new provider → Apple**.
4. Toggle **Enable**. The default fields work fine for native iOS-only
   SIWA; you don't need to fill Service ID / OAuth code flow unless you
   later add SIWA on Android or web.
5. **Save**.

---

### Step 3 — Host the privacy policy *(10 min)*

App Store Connect requires a public URL. Cheapest options:

- **Cloudflare Pages** (you already use it for jungleandsun.ie). New
  project → upload `PRIVACY_POLICY.md` rendered to HTML, get a
  `pacelli-privacy.pages.dev` URL.
- **GitHub Pages.** Push `PRIVACY_POLICY.md` to a public repo, enable
  Pages on `main` branch, done.
- **Subpath on jungleandsun.ie**, e.g. `jungleandsun.ie/pacelli-privacy`.

Whatever URL you end up with — you'll paste it into App Store Connect in
Step 6.

> Tip: also publish a **Support URL** (can be a one-line page with your
> email or a contact form). App Store Connect makes both mandatory.

---

### Step 4 — Generate app icons + screenshots *(45 min)*

#### Icons (you already have a 1024×1024 master)

Confirm it has **no transparency, no rounded corners, no text** (Apple
adds the rounded mask itself). If yours has any of those, regenerate via:

```bash
brew install imagemagick
# Strip alpha from your master:
magick ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png \
       -background white -alpha remove -alpha off /tmp/icon-1024.png
```

#### Screenshots (the tedious part)

**Required sizes** (App Store Connect rejects without these):

| Device class | Size | Mandatory? |
|---|---|---|
| iPhone 6.7" (15 / 14 Pro Max) | 1290 × 2796 | **Yes** |
| iPhone 6.5" | 1242 × 2688 | Optional but recommended |
| iPad 12.9" (6th gen) | 2048 × 2732 | **Yes if iPad supported** |

You currently support iPad (`UISupportedInterfaceOrientations~ipad` in
Info.plist). Either drop iPad support in `Info.plist` or supply iPad
screenshots — your call. Easiest is to **drop iPad for v1**: delete that
key. I can do that for you if you want.

Fastest workflow:

```bash
# Boot the iPhone 15 Pro Max simulator (gives 1290×2796 natively)
xcrun simctl boot "iPhone 15 Pro Max"
open -a Simulator

# Run Pacelli on it
flutter run -d "iPhone 15 Pro Max"

# Cmd+S in the Simulator → screenshot saves to Desktop
```

Take **5–10 screenshots** showing: home, tasks, calendar, AI chat,
inventory, settings/burn data. App Store Connect accepts up to 10.

> Pro tip: the `screenshot` Flutter package + a small `integration_test`
> can produce all screenshots reproducibly in one command. Worth it for
> v2; skip for v1.

---

### Step 5 — Build and upload the IPA *(15 min + ~20 min Apple processing)*

```bash
cd ~/Developer/pacelli

# Bump build number for every upload (App Store Connect rejects duplicates)
# pubspec.yaml: change "version: 1.0.0+1"  →  "1.0.0+2"  on every build

flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/symbols
```

The signed IPA lands at **`build/ios/ipa/pacelli.ipa`**.

Upload it. Pick one:

```bash
# Option A — Transporter.app (free, App Store, GUI)
open -a Transporter build/ios/ipa/pacelli.ipa
# → drag the IPA, click Deliver

# Option B — altool from CLI (after creating an app-specific password at
# appleid.apple.com → Sign-in and Security → App-Specific Passwords)
xcrun altool --upload-app -f build/ios/ipa/pacelli.ipa -t ios \
  -u juancarlos.celis@outlook.com \
  -p "abcd-efgh-ijkl-mnop"  # ← app-specific password
```

After upload, App Store Connect takes ~10–20 min to "process" the build.
Watch **TestFlight tab → iOS** for it to appear.

---

### Step 6 — Create the App in App Store Connect *(20 min)*

1. https://appstoreconnect.apple.com → **My Apps → +** → **New App**.
2. Fill:
   - Platform: **iOS**
   - Name: **Pacelli**
   - Primary language: **English (U.K.)** or whichever you prefer
   - Bundle ID: pick **com.pacelli.pacelli** from the dropdown (it appears
     because Step 1 registered it)
   - SKU: `pacelli-ios-v1` (any unique string)
   - User access: Full Access
3. Click **Create**.

Now you're in the app's dashboard. Fill these tabs:

#### App Information

- Subtitle (max 30 chars), e.g. "A peaceful household"
- Privacy Policy URL → paste from Step 3
- Category: **Lifestyle** (primary), **Productivity** (secondary)
- Content Rights: tick "Does not contain, show, or access third-party content"
- Age Rating: walk the questionnaire — Pacelli is almost certainly **4+**

#### Pricing and Availability

- Price tier: **Free** (or whatever you decide)
- Available in: All countries, or restrict if you want

#### App Privacy

This is the **Nutrition Label**. Click **Get Started**, then declare:

| Data type | Linked to user? | Used for tracking? | Purposes |
|---|---|---|---|
| Email Address | Yes | No | App Functionality |
| Name | Yes | No | App Functionality |
| User ID (Firebase UID) | Yes | No | App Functionality |
| Other User Content (encrypted) | Yes | No | App Functionality |
| Photos (if user attaches) | Yes | No | App Functionality |
| Diagnostic Data | Yes | No | App Functionality, Analytics |
| Crash Data | No | No | App Functionality |

Everything is "Used to track you across other companies' apps?" → **No**.

#### Version 1.0 → Prepare for Submission

- **Screenshots:** drag in your 6.7" set (and iPad 12.9" if you kept iPad).
- **Promotional text** (170 chars, can be changed without a new build):
  e.g. "A peaceful, end-to-end encrypted household manager. Tasks, plans,
  calendar, inventory and a private AI assistant — for your family only."
- **Description** (4000 chars). Pull from your `lib/l10n/app_en.arb`
  marketing strings, or write fresh. Mention encryption — App Review
  reads this.
- **Keywords** (100 chars total, comma-separated):
  `household,family,tasks,planner,calendar,inventory,encrypted,private,checklist,home`
- **Support URL:** see Step 3.
- **Marketing URL:** optional.
- **Build:** **+ → select the build that processed in Step 5**.
- **App Review Information:**
  - Sign-in required: **Yes**
  - Provide a **demo account** (email + password) — create a throwaway
    Firebase user just for Apple reviewers. This is mandatory for any app
    with login.
  - Notes for reviewer: "Pacelli is end-to-end encrypted. Sign in with
    the demo account, complete onboarding (pick 'Cloud' storage), and
    create a household named 'Demo' to access all features."
- **Version Release:** "Automatically release this version" or manual.

Click **Save** → **Add for Review** → **Submit for Review**.

---

### Step 7 — TestFlight first (strongly recommended) *(parallel with Step 6)*

Before submitting for App Store review, prove the build runs on a real
device:

1. App Store Connect → your app → **TestFlight** tab → **Internal Testing**.
2. Click **+** to create an internal group, add your own
   `juancarlos.celis@outlook.com`.
3. Toggle the build **ON** for that group. Internal testing requires no
   review — instant.
4. On your iPhone, install **TestFlight** from the App Store, sign in
   with the same Apple ID, install Pacelli, smoke-test SIWA + Google +
   email login + create household + burn data.
5. Only then submit for App Store review (Step 6 last action).

---

### Step 8 — Wait *(24–48 h typically)*

- Apple emails you the outcome.
- If rejected, the rejection notes tell you exactly what to fix. The most
  common rejections for a Firebase + encryption + family app are:
  1. SIWA missing or visually less prominent than Google → fixed.
  2. Privacy policy URL broken or doesn't cover all collected data → use
     Step 3's draft.
  3. Demo account credentials missing or wrong.
  4. Crash on launch on the reviewer's device → reproduce, fix, resubmit.

---

## § C — Suggestions you didn't ask about

1. **Set up Fastlane now.** `cd ios && fastlane init`, pick option 2
   (Automatic). Then `fastlane match` to sync your code-signing certs to
   a private GitHub repo, and `fastlane pilot upload` for one-command
   TestFlight pushes. Saves 15 min per release forever.
2. **Drop iPad support for v1** unless you really want to ship iPad
   screenshots. Edit `ios/Runner/Info.plist`: remove the
   `UISupportedInterfaceOrientations~ipad` array. App Store Connect will
   stop asking for iPad screenshots.
3. **Run `/pacelli-security-audit`** before submitting — it cross-checks
   that your privacy policy claims match the actual encryption code.
4. **Keep the dSYM/symbols directory** (`build/symbols/`) in version
   control or backed up. Without it, Crashlytics shows obfuscated stack
   traces and you can't read crash reports.
5. **Marketing version vs build number:** `1.0.0+1`, `1.0.0+2`, … is
   fine. When you ship `1.0.1`, reset to `1.0.1+1`. App Store Connect
   only enforces uniqueness within a marketing version.

---

*Generated 2026-04-28 by Claude.*
