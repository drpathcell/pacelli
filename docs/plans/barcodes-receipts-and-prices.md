# Barcodes, receipts, and knowing what things cost

Plan only — nothing here is built. Written 2026-08-24.

Juan's ask, in his words: *be at the supermarket and read barcodes to clear the
shopping list, and at the same time know the price of the item I just scanned.
Also take a picture of the receipt and have it logged, so we can produce
statistics for the household.*

Three things. Two are straightforward. One of them, as stated, cannot be built —
and the fix turns out to be the most interesting part of the design.

---

## 1. The part that does not work, and why

**There is no way to look up the price of a grocery item by barcode.**

A barcode (EAN-13) identifies a *product*, globally. It says nothing about
price, because price is not a property of the product — it is a property of
*this product, in this shop, this week*. Tesco Ireland, Dunnes, SuperValu, Lidl
and Aldi publish no API. What exists is a layer of third-party scraping
services selling reformatted retailer data; they are paid, they break whenever a
site changes, their legal footing is somebody else's problem being sold as
yours, and pointing a family app at one would put a fragile paid dependency on
the critical path of standing in a shop.

So: no barcode-to-price lookup. Not as a limitation to work around — as a fact
to design with.

**Two things replace it, and both are better.**

### 1a. Read the shelf label, not the barcode

The price *is* available, printed, thirty centimetres from the barcode: on the
shelf-edge label. `DataScannerViewController` recognises **text and barcodes in
the same live camera session**. Point it at the shelf label and one frame can
yield the EAN *and* the price, on device, with no API, no third party and no
network.

This is better than a lookup would have been. It is today's price, in this
shop, including whatever offer is running — which is the number that actually
matters, and the number no API would have given you correctly anyway.

The work is in the heuristics, and they are testable: a shelf label prints the
price twice (`€2.49` and `€1.66/kg`), so the parser has to prefer the larger
glyph and reject the one followed by a unit. Labels differ by retailer. This
needs a spike against real labels before it is promised — see §6.

### 1b. Remember what you paid

The receipt half of Juan's idea is not a separate feature. It is the other end
of the same loop:

> **the receipt teaches the app prices → the scan spends that knowledge**

Scan a jar of coffee and the app can say *"€4.95 — you paid €4.49 at Dunnes
three weeks ago."* That comparison is worth more than a shelf price on its own,
it needs no external data at all, and it gets better every time the household
shops. It is also the thing that makes the statistics real rather than
decorative.

---

## 2. The actual hard problem: three names for one thing

Everything in this feature is the same difficulty wearing different clothes.
One jar of coffee has three identities that never match:

| Where | What it looks like |
|---|---|
| The barcode | `5000000000000` |
| Juan's shopping list | `Coffee` |
| The Tesco receipt | `TSC GRND COFF 227G` |

Nothing links them automatically. Fuzzy-matching `TSC GRND COFF 227G` to
`Coffee` is not a solved problem and pretending otherwise is how this feature
becomes a thing nobody trusts.

**The design principle: the household teaches the mapping, once per product,
and never again.**

- Add `Coffee` to the list.
- At the shop, scan it. Unknown EAN → the app shows the product name from Open
  Food Facts and asks which list item this is. One tap. **The EAN is now bound
  to this household's word `Coffee`, forever.**
- The receipt is parsed. `TSC GRND COFF 227G  4.95` does not match anything
  known — so the app *proposes* a match and asks. One tap. **The receipt string
  is now bound too.**
- Next month all three are silent. Scan, tick, done. The receipt logs itself.

Every proposed match is confirmed by a human the first time and never asked
again. The app is allowed to guess; it is not allowed to guess silently. This
is the same rule as the E2E work: a green that was never able to be red is
worth nothing, and a match nobody confirmed is a statistic nobody should
believe.

---

## 3. Architecture

### Collections

| Collection | Encrypted? | Why |
|---|---|---|
| `products/{ean}` | **No** | Public Open Food Facts data — a name and a brand, identical for every user on earth. Encrypting it would mean re-fetching it per household for no gain. Readable by any authenticated user, writable only by the Cloud Function. |
| `household_products/{uuid}` | **Yes** | `ean` ↔ this household's word for it, plus the price history. This is the private part: *that this household buys this* is the sensitive fact, not that the product exists. |
| `receipts/{uuid}` | **Yes** | Rides on the 1.8.0 photo layer unchanged — encrypted object in Storage, encrypted thumbnail in the document, readable copy in Files. |
| `purchases/{uuid}` | **Yes** | One row per receipt line: household product, price paid, store, date. The substrate every statistic is computed from. |
| `checklist_items` | existing | Gains an optional `ean`. |

`products/{ean}` being public is a deliberate call and worth stating plainly: it
holds only what Open Food Facts already publishes to the world. Nothing about a
household touches it. The moment a barcode is associated with *a household*,
that association lives in `household_products` and is encrypted like everything
else.

### Barcode lookup goes through a Cloud Function, not the phone

Querying Open Food Facts directly from the app would send *what this family is
buying* to a third party, tagged by home IP address, from inside an app whose
entire premise is that nobody can read your household data. That is a
contradiction, not a detail.

Routing through a Cloud Function means:
- The user's IP never reaches Open Food Facts.
- One barcode is fetched **once, ever**, for all users — the `products` cache
  makes a second lookup free.
- The rate limit (**15 requests/min/IP for product reads**) applies to one
  server address rather than being invisible per-user; the cache is what keeps
  it survivable.
- The mandatory `User-Agent: AppName/Version (ContactEmail)` lives in one place.

Licensing: Open Food Facts data is ODbL (database) and DbCL (contents), images
CC-BY-SA. Attribution is required and there is a usage form to complete before
shipping. Cheap, but not optional, and it needs doing before the App Store
build, not after.

### Statistics are computed on the device. There is no other option.

The server cannot read `purchases` — that is the whole point of the app. So no
Cloud Function can aggregate spend, no scheduled job can produce a monthly
summary, and there is no server-side report. Every statistic is computed
client-side over decrypted rows.

That is fine at family scale (a few thousand rows a year) and it should be
designed for deliberately rather than discovered later: fetch, decrypt,
aggregate in memory, cache the result locally. It also means the statistics
screen is the first thing in Pacelli that will care about how *many* documents
there are, which is a new consideration for this codebase.

---

## 4. What it feels like to use

**In the shop.** Open the list, tap scan. The camera stays open — this is a
scanning *session*, not one shot. Each recognised item ticks off the list with
a haptic and a line at the bottom: `Coffee ✓ €4.95 · you paid €4.49 at Dunnes,
3 weeks ago`. Scan the same thing twice and the quantity goes to 2 rather than
ticking twice. Something not on the list gets offered as an addition rather
than being dropped.

**Signal in supermarkets is bad, so none of this may require it.** Barcode
recognition is on-device. Product names for anything the household has bought
before come from the local cache. Ticking an item is a Firestore write, and
Firestore queues offline writes — the same property the photo layer already
leans on, where `upload_state: pending` *is* the retry queue. An unknown EAN
with no signal degrades to "scanned, name pending", which is honest and still
ticks the item.

**At home.** Photograph the receipt. The app shows what it read, with the
matched items ticked and the unmatched ones needing a tap. Confirm. The
household's price history is that much richer.

---

## 5. Receipt parsing, and the check that keeps it honest

OCR is the easy half — `VNRecognizeTextRequest` is already in the app for photo
search. *Parsing* is the hard half: thermal print, curled paper, faded ink,
every retailer laying out lines differently.

The approach is geometric rather than linguistic. Vision returns bounding
boxes; on a receipt, prices are a right-aligned column and descriptions are
left-aligned. Find the price column, find the total, and pair the rest by row.

**And then check it.** The parsed line items must sum to the printed total. If
they do not, the app says so and asks for help — it does not present a
confident wrong answer.

That check is the whole quality bar for this feature, and it is the same
principle as `check_quantity_at_rest.py`, which refuses to report "no plaintext
found" unless it can first prove it could have seen plaintext. A receipt parser
that cannot verify its own arithmetic is a machine for generating plausible
household statistics that are quietly wrong — which is worse than no statistics,
because someone will make decisions with them.

---

## 6. The experiment to run before building anything

**Photograph twenty real receipts** from the shops actually used — Tesco,
Dunnes, SuperValu, Lidl, Aldi — and try to parse them offline in a throwaway
script. Measure one number: on how many does the sum of extracted line items
equal the printed total?

- **Comfortably above 90%** — build it as described.
- **Around 50–70%** — the feature is still worth having but it is an
  *assisted* flow, not an automatic one, and the UI has to be designed around
  correction from the start rather than having correction bolted on.
- **Below that** — reconsider. Manual entry of a total per shop still produces
  useful spend statistics without any of this machinery, and the barcode half
  stands on its own.

Do the same for shelf labels: twenty photographs, how often is the correct price
extracted and the unit price rejected.

This costs an evening with a camera and a Python script, and it decides the
shape of three releases. It should happen before a line of Swift is written.

---

## 7. Sequencing

This is three or four releases. Compressing it into one produces a feature
where every part half-works.

| | Contents | Depends on |
|---|---|---|
| **1.10.0** | Burn permissions. Already decided — unchanged by any of this. | 1.9.0 live, rules deployed |
| **spike** | The twenty-receipt and twenty-label experiment. Not a release. | nothing |
| **1.11.0** | **Scan to tick.** Barcode scanning, `products` cache behind a Cloud Function, EAN ↔ list item binding, offline session. **No prices at all.** | the spike |
| **1.12.0** | **Receipts.** Photo → OCR → parse → confirm → `purchases`. Prices arrive here, and the price memory with them. | 1.11.0's bindings |
| **1.13.0** | **Shelf-label prices and statistics.** Live price capture, "you paid X last time", spend over time. | 1.12.0's data |

1.11.0 is worth shipping on its own even if everything after it stalls:
standing in a shop ticking a list by pointing a phone at things is the majority
of the value, and it carries no external dependency, no OCR risk and no price
data.

---

## 8. Things to decide

1. **Does the paired AI assistant see purchase history?** It currently sees
   household data by default. A grocery list is one thing; a year of what a
   family bought, when, and for how much is a different order of disclosure.
   This may want to be the second thing gated by the permissions model being
   built for burn in 1.10.0 — the shape is already there.

2. **What gets stripped from a receipt image?** A receipt carries the store,
   the date and time, the card's last four digits, often a loyalty number, and
   sometimes a name. The 1.8.0 photo layer strips location metadata from
   photos; a receipt's sensitive content is in the *pixels*, which is a
   different problem and needs its own answer.

3. **Is the readable copy of a receipt written to the Files-visible folder**
   like other photos? `AUDIT_2026-08-22_photos.md` accepted that folder sitting
   outside the app lock as a considered trade for photos. A year of receipts is
   a heavier thing to leave outside it, and the trade deserves re-taking rather
   than inheriting.

4. **Is Open Food Facts contributed back to?** Scanning products it does not
   know is exactly how its coverage improves, and Irish own-brand coverage is
   likely to be the weak spot. Worth deciding deliberately, not drifting into.

5. **Does the shopping list get a `store` at all?** Price history is meaningless
   without knowing where — but asking "which shop?" every time is friction. The
   receipt names the shop; a scanning session could ask once, or guess from the
   last receipt.

---

## 9. What this reuses

Very little of this is new machinery, which is the strongest argument for the
plan:

- **Vision** — already in `PhotoIndexer` for text and classification. Barcode
  and shelf-label reading is the same framework.
- **The photo layer** — receipts are photos. Encryption, Storage, signed URLs,
  the thumbnail-in-the-document trick, deletion-as-a-consequence: all of it
  works unchanged.
- **Snapshot listeners** — added in 1.9.0. A scanning session on one phone
  ticking items another phone is watching is exactly what they are for, and
  now it works.
- **The offline write queue** — proven by photos, needed again in a shop with
  no signal.
- **`FunctionsClient`** — the app's HTTP client, added in 1.7.0 for AI linking.
  The barcode proxy is a second caller, not a new thing.

The genuinely new parts are the receipt parser, the shelf-label heuristics, and
the statistics screen. Everything else is composition.
