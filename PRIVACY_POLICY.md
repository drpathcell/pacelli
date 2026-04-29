# Pacelli — Privacy Policy

**Effective date:** 2026-04-28
**Contact:** juancarlos.celis92@gmail.com

Pacelli ("the App", "we") is a household management app that helps families
share tasks, plans, lists, a calendar, an inventory, a house manual, and an
in-app AI assistant. Privacy is a core feature, not an afterthought — most
content you create is end-to-end encrypted on your device before it ever
leaves it.

This policy tells you exactly what we collect, why, where it lives, and how
to delete it.

---

## 1. Who is the data controller?

Juan Carlos Celis Pinto, sole developer of Pacelli, is the data controller
under the GDPR. You can contact us at **juancarlos.celis92@gmail.com**.

We are based in Ireland and the App is offered worldwide.

---

## 2. The two storage modes

During onboarding you choose where your data lives:

- **Cloud (Firebase Cloud Firestore):** content is stored in Google Cloud
  servers (EU multi-region). Human-readable fields (titles, descriptions,
  names, message bodies, manual content, tags) are **encrypted with
  AES-256-CBC on your device** before upload, using a per-household key that
  Google never sees. Structural metadata (record IDs, status flags,
  timestamps, household IDs) is stored unencrypted so that the app can
  query and sort it.
- **Local (on-device SQLite):** content is stored only on your phone. It is
  not encrypted at rest because it never leaves your device — it is
  protected by your phone's own disk encryption.

You can switch modes at any time and wipe your cloud data with one tap (see
"Burn all data" below).

---

## 3. What we collect and why

### 3.1 Account data (Firebase Authentication)

When you sign in we receive from your chosen identity provider:

- A unique Firebase user ID (UID).
- Your email address.
- Your display name (if you used Google or Apple Sign-In; for Sign in with
  Apple, the name is shared only the first time, only with us, and only if
  you allow it).

Used to identify you across devices and to scope access to your household.
Stored as long as your account exists.

### 3.2 Household content (encrypted)

Tasks, subtasks, checklists, plans, calendar entries, inventory items,
house-manual entries, AI chat messages, attachments metadata, feedback
text. All human-readable fields are AES-256-CBC encrypted on-device with
your household key before they reach the server. Without that key the
ciphertext is meaningless to us, to Google, and to anyone with database
access.

### 3.3 Diagnostics and feedback (optional, encrypted)

If you submit feedback or if the app records a diagnostic event (an error
or warning), the message text and any context are encrypted with your
household key before being stored. We use this to improve the App; we
cannot read it without your household key.

### 3.4 Push notifications

If you enable notifications we send a Firebase Cloud Messaging device
token to Apple Push Notification service or to Google Firebase. We do not
include sensitive content in notification payloads.

### 3.5 Photos, camera, and Google Drive

If you attach a photo or use the barcode scanner, the App accesses your
camera or photo library. The image data is processed on-device. If you
choose to back attachments to Google Drive, the file is uploaded to
**your own Google Drive account** under a Pacelli folder; we never receive
a copy.

### 3.6 AI Assistant

If you connect a third-party AI provider (Anthropic Claude, Google Gemini,
or OpenAI ChatGPT), your API key is stored in your device's secure
keychain (iOS Keychain / Android Keystore) and only that provider receives
your prompt. We do not proxy or log AI requests.

### 3.7 What we do NOT collect

- We do not collect your contacts, location, microphone audio, advertising
  IDs, or browsing history.
- We do not sell or rent your data to anyone.
- We do not show ads.
- We do not use your content to train any AI model.

---

## 4. Encryption details

- Symmetric scheme: **AES-256-CBC**.
- Per-household symmetric key, generated on the first device that creates
  the household.
- That key is wrapped (encrypted) per member with a key derived from the
  member's Firebase UID via **HKDF-SHA-256**, and stored in Firestore in
  the `household_keys` collection. Only members of your household can
  unwrap it; we cannot.
- The unwrapped key is cached in your device's secure keychain
  (`flutter_secure_storage`).
- When a new member joins, an existing member's device re-wraps the
  household key for the new member's UID — no plaintext key ever crosses
  the network.

---

## 5. Sub-processors

We use the following sub-processors. Each is bound by their own contracts
and data-processing terms.

| Sub-processor       | Purpose                          | Region        |
|---------------------|----------------------------------|---------------|
| Google Firebase     | Authentication, Firestore database, Cloud Functions, Cloud Messaging | EU multi-region |
| Apple               | Sign in with Apple, push notifications | Worldwide |
| Google              | Google Sign-In, optional Google Drive attachments | Worldwide |
| Your chosen AI      | In-app AI Assistant (only if you connect one) | Provider's region |

---

## 6. Data retention and "Burn all data"

- Account and household data are retained as long as your account exists.
- The App ships a **Burn All Data** button (Settings → Burn all data) that
  deletes every document scoped to your household, terminates and clears
  the local Firestore cache, and signs you out. After this, only your
  Firebase Authentication account remains; deleting that is a single tap
  away in Settings.
- You can also export an encrypted JSON backup at any time.

---

## 7. Your rights (GDPR)

You have the right to: access, rectification, erasure, restriction,
portability, and to object to processing. Use the in-app export and burn
features for portability and erasure, or email us at
**juancarlos.celis92@gmail.com** for any other request — we will respond
within 30 days.

You also have the right to lodge a complaint with the Irish Data
Protection Commission (dataprotection.ie).

---

## 8. Children

Pacelli is not directed at children under 13. If you believe a child has
created an account, please contact us and we will delete it.

---

## 9. Changes to this policy

When we change this policy we will update the **Effective date** above and
post the new version at the same URL. Material changes will also surface
in-app on next launch.

---

*Last reviewed: 2026-04-28.*
