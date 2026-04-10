# Pacelli — App Store Connect Metadata

**App version:** 1.0.0  
**Platform:** iOS + macOS  
**Submission date:** 2026-04-10

---

## 1. App Name (30 chars max)

```
Pacelli
```

---

## 2. Subtitle (30 chars max)

```
Your household, organised
```

---

## 3. Description (4000 chars max)

Pacelli is a household management app that keeps everything your family needs—tasks, plans, inventory, and knowledge—in one secure, private place.

**Tasks & Checklists**
Manage household tasks with full control: create categories, set priorities, assign to family members, and add due dates. Break tasks into subtasks. Keep separate checklists for shopping, packing, or anything else. Check items off in real time across all devices.

**Plans for Multi-Day Projects**
Structure bigger household projects with Plans. Create a plan (e.g. "Kitchen Renovation"), add day-by-day entries, and build checklists for each phase. Calendar integration shows your plans alongside daily tasks, so nothing gets overlooked.

**Calendar View**
See everything at a glance: tasks, checklists, plans, and inventory expiry dates all on your household calendar. Tap any date to view that day's full view, or navigate forward to plan ahead.

**Inventory Management**
Track what's in your home. Add items with quantities, expiry dates, barcodes, categories, and storage locations. Scan real barcodes with your phone's camera, or use virtual QR codes for labelled containers. Get alerts when items are expiring soon or running low. Auto-create tasks for restocking and expiry reminders.

**House Manual**
Build a private wiki for your household knowledge. Write Markdown-formatted entries about anything: how to use appliances, emergency procedures, seasonal maintenance, house rules, or family recipes. Tag and search entries. Only your household members can see it.

**AI Chat (Optional)**
Connect Claude, Gemini, or ChatGPT via your own API key. Chat with AI directly in the app to brainstorm, draft lists, get advice, or automate household planning. Your chats stay private—never shared with Apple or Pacelli.

**Fully End-to-End Encrypted**
Your household data is encrypted on your device before it ever leaves. All titles, descriptions, and sensitive content are scrambled with AES-256-CBC encryption using keys unique to your household. Even if Pacelli's servers were breached, encrypted data would be useless. Google Sign-In is your only authentication method; Pacelli never sees your password.

**Choose Your Backend**
Set up Pacelli with encrypted cloud storage via Firebase, or keep all data local on your device with offline-first SQLite. Switch anytime. Cloud backup is optional; your choice.

**Multiple Languages**
English, Spanish, Italian supported from day one. Switch languages anytime in settings.

**Themes**
Pick your colour scheme: Sage Green, Purple, or Ocean Blue. Light and dark modes.

**Burn All Data**
When you're ready to leave or factory reset, wipe all household data permanently with one tap. Complete deletion—no traces in any cloud backup.

Pacelli is free to use. No ads, no tracking, no surprise paywalls. Your household data belongs to you.

---

## 4. Keywords (100 chars max, comma-separated)

```
household tasks, family planner, task management, shared grocery list, household checklists, family organization, inventory tracker, home management, collaborative tasks, family calendar
```

**Research notes:**  
These keywords prioritize search value in household management, family organisation, and collaborative task spaces. Secondary terms (shared, collaborative, family) reflect Pacelli's multi-user focus. Avoid generic "productivity" terms that face high competition; "household" and "family" are more specific entry points.

---

## 5. Promotional Text (170 chars max)

```
Organise your household together. Tasks, checklists, plans, inventory, and a private wiki—all encrypted and synced across your family's devices.
```

*(Can be updated without App Review; rotate messaging each quarter)*

---

## 6. Support URL

```
https://pacelli.example.com/support
```

**Note:** Replace with actual GitHub Pages or documentation site URL.

---

## 7. Privacy Policy URL

```
https://pacelli.example.com/privacy.html
```

**Note:** Replace with actual privacy policy page. Must cover:
- Encryption practices (AES-256-CBC, key derivation, storage location)
- Data handling for Firebase backend (PII encrypted at rest)
- Optional AI provider integrations (Claude, Gemini, ChatGPT—data goes directly to those providers' APIs, not through Pacelli servers)
- Firestore membership security (household isolation, no cross-household access)
- Data export/import practices
- User data deletion and burn-all-data feature
- Google Sign-In privacy

---

## 8. Age Rating Questionnaire

**Answer "None" or "No" to all of the following:**

| Question | Answer | Note |
|----------|--------|------|
| Does your app contain cartoon or fantasy violence? | None | Household management app; no violence. |
| Does your app contain realistic violence? | None | No violence. |
| Does your app contain sexual content, profanity, or mature themes? | None | Family-friendly household organisation tool. |
| Does your app contain gambling or simulated gambling? | None | No gambling mechanics. |
| Does your app contain alcohol, tobacco, or drug use references? | None | No substance references. |
| Does your app contain frequent/intense profanity? | None | No profanity. |
| Does your app collect personal information from children? | No | App is for household members (adults + older children). Optional Google Sign-In only; no targeted child data collection. Data encryption ensures privacy. |
| Does your app contain graphic sexual content? | None | No sexual content. |
| Does your app contain prolonged graphic violence? | None | No violence. |
| Does your app contain extreme violence, gore, or torture? | None | No violence. |

**Recommended rating:** **4+**

---

## 9. What's New (v1.0.0 Release Notes)

```
🏠 Pacelli 1.0.0 is here

Welcome to Pacelli—your household's command centre.

New in this release:
• Task management with priorities, categories, subtasks, and assignees
• Checklists for any household need—shopping, packing, cleaning
• Plans for multi-day projects with day-by-day entries and checklists
• Calendar view showing tasks, plans, and inventory expiry dates
• Inventory tracker with barcode scanning, locations, categories, and expiry alerts
• House Manual: a private Markdown wiki for household knowledge
• AI Chat: talk to Claude, Gemini, or ChatGPT directly in the app
• End-to-end encryption: your data stays private, even from us
• Choose your storage: encrypted Firebase cloud or local SQLite
• Burn all data: delete everything in one tap when you're ready
• Multi-user household support with encrypted key sharing
• English, Spanish, Italian
• Multiple themes (Sage, Purple, Ocean Blue)

Try the demo household included in onboarding to explore all features risk-free.

Questions? Visit our support page or tap Settings → Help.

Happy organising. 🎯
```

---

## 10. Screenshots (iPhone 6.9" required; 1290 × 2796 px at 3x scale)

### Screenshot Strategy

1. **Lead with the hook** (Screenshot 1): Show the calendar view with a packed day—tasks, plans, and inventory visible. Headline: "Everything in one place."
2. **Show key features** (Screenshots 2–5): Task creation, checklist, inventory with barcode scanner, House Manual entry.
3. **Highlight security** (Screenshot 6): Settings showing encryption status and AI provider connection. Headline: "Your data is yours alone."
4. **End on multi-user** (Screenshot 7): Multiple avatars in the household header showing 3 family members. Headline: "Organise together, privately."

### Recommended Screenshot Order & Captions

| # | Screen | Caption | Why |
|---|--------|---------|-----|
| 1 | Calendar view (populated day, tasks + plans + inventory visible) | "Everything in one place. Tasks, plans, and inventory expiry dates on your household calendar." | Hook—shows depth and integration. |
| 2 | Task detail screen (filled task with subtasks, assignee, due date, category) | "Manage household tasks together. Assign, prioritize, break into subtasks." | Core feature; demonstrates collaboration. |
| 3 | Checklist editor (shopping list with checked and unchecked items) | "Checklists for anything. Shopping, packing, chores—check off in real time." | Relatable household use case. |
| 4 | Inventory item detail with barcode scanner visible | "Scan real barcodes or use virtual QR codes. Track quantities, expiry dates, locations." | Demonstrates modern, practical feature. |
| 5 | House Manual entry view (Markdown formatted, pins visible) | "House Manual: your private family wiki. Write guides, rules, recipes, or emergency procedures." | Unique, premium feature. |
| 6 | Settings → AI Assistant (provider selected, API key masked) | "AI Chat. Connect Claude, Gemini, or ChatGPT with your own API key. Your chats stay private." | Differentiator; privacy emphasis. |
| 7 | Household members view (3 avatars shown with "Invite pending" state) | "Organise your household together. Invite family, assign tasks, encrypt everything end-to-end." | Social proof; security assurance. |

### Design Notes for Screenshots

- **Use the Sage Green theme** throughout (matches branding in Pacelli CLAUDE.md).
- **Ensure minimum font size is 13px** (enforced by app theme, but verify in screenshots).
- **Show real data**, not placeholder text:
  - Task example: "Plan Easter brunch" with 3 subtasks.
  - Checklist example: "🛒 Shop" with 6–8 items (eggs, flour, chocolate, butter, etc.).
  - Inventory example: A shelf of common items (olive oil, pasta, tinned tomatoes, rice).
  - House Manual example: "Emergency Shut-Off Procedures" with a few lines of formatted text.
- **Highlight interactivity**: Show toggle states (completed checklist items), assigned avatars, category colours, barcode scanner UI.
- **No UI chrome** (hide status bar and home indicator if possible on iPhone screenshots).
- **Landscape and portrait**: Capture in portrait (6.9" iPhone), but verify no critical content is cut off in landscape if app supports it (Pacelli does).

---

## 11. Submission Checklist

- [ ] App Name, Subtitle, Bundle ID verified
- [ ] Category: Productivity (Primary), Lifestyle (Secondary)
- [ ] Price: Free (no in-app purchases)
- [ ] Availability: All countries, all devices
- [ ] Description proofread (no spelling, no sales hyperbole)
- [ ] Keywords researched and validated
- [ ] Promotional text short & punchy
- [ ] Support & Privacy URLs live and accessible
- [ ] Age rating questionnaire answered (4+)
- [ ] Release notes written & approved
- [ ] 7 screenshots captured, compressed, and ready to upload
- [ ] App icon (1024 × 1024 px) prepared
- [ ] Privacy Policy page published with all required sections
- [ ] Support page published with FAQ / contact method
- [ ] App reviewed for App Review Guidelines compliance (no private APIs, no restricted data collection)

---

## 12. Key Messaging

**Primary positioning:** A privacy-first household management platform for families who want control, transparency, and end-to-end encryption.

**Secondary positioning:** The all-in-one household app that replaces scattered notes, shared Google Sheets, and unclear task assignments.

**Unique selling points:**
1. **End-to-end encryption by default**—not optional, not hidden, always on.
2. **House Manual**—a private family wiki (unique vs. standard task managers).
3. **Barcode inventory scanning**—practical and visible.
4. **Multi-backend flexibility**—choose Firebase cloud or local SQLite.
5. **Built-in AI chat**—talk to Claude, Gemini, or ChatGPT directly without leaving the app.
6. **Burn all data**—permanent deletion on demand, no traces.

---

## 13. Compliance Notes

- **GDPR/CCPA:** Privacy Policy must clarify that encrypted data is not "personal data" Pacelli can access, and users have complete deletion rights via Burn All Data.
- **Child Safety (COPPA):** App is intended for households with adults. No children under 13 should be invited without parental consent (not enforced in app, but noted in Privacy Policy).
- **AI Disclosure:** If Apple requires disclosure of AI-generated content in description, clarify that AI Chat is optional and user-initiated (not used to generate app marketing materials).
- **Third-party integrations:** Firebase (Google), Google Sign-In, optional Claude/Gemini/ChatGPT providers. All third-party policies referenced in Privacy Policy.

---

## 14. Future Messaging Campaigns (Not for Initial Submission)

- **Q2 2026:** "Organise your Easter plans with Pacelli" (seasonal inventory + plans angle).
- **Q3 2026:** "Never forget an expiry date again" (inventory reminders).
- **Q4 2026:** "Build your house manual this year" (New Year resolution angle).
- **2027:** "Pacelli for remote families" (multi-device, multi-location households).

---

**End of App Store Metadata**

**Ready to submit:** This document is copy-paste ready for App Store Connect. Replace placeholder URLs, verify screenshots, and confirm Privacy Policy before upload.
