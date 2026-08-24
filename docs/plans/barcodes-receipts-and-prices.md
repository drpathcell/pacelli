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

**Scope narrowed by Juan, 2026-08-24: Dunnes only, and no old receipts.**

So the corpus is one retailer's layout, gathered from ordinary shopping. That is
a scope statement rather than a problem, but it has to be written down next to
decision 8.2, because the two compound:

> the parser is built once, on this corpus, and the images are deleted after
> parsing — so **1.12.0 means "receipts work at Dunnes"**, and any other shop
> falls back to entering a total by hand until a receipt from it exists.

One standing task covers that without asking for a special trip: photograph the
receipt if you ever happen to shop somewhere else. No due date, no urgency.

**What to gather:**
- **20 shelf labels — one visit.** They are all on the shelves at once; this is
  two minutes, not twenty trips. Straight on, whole label, barcode and both
  prices visible.
- **Dunnes receipts — as they happen.** Flat, whole receipt including the TOTAL
  line, overlapping photos if it is long. No cropping and no correcting: the
  parser has to see what the camera saw.

**Measure one number:** on how many receipts does the sum of extracted line
items equal the printed total?

- **Comfortably above 90%** — build it as described.
- **Around 50–70%** — the feature is still worth having but it is an
  *assisted* flow, not an automatic one, and the UI has to be designed around
  correction from the start rather than having correction bolted on.
- **Below that** — reconsider. Manual entry of a total per shop still produces
  useful spend statistics without any of this machinery, and the barcode half
  stands on its own.

Do the same for shelf labels: how often is the correct price extracted and the
unit price rejected.

**The photos come off the phone with `scripts/pacelli.py photos` and
`photo-save <id> <path>`** — the loop is already proven working.

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

## 8. Decided (2026-08-24, Juan)

All five settled before any code. Recorded here so the plan stops being
provisional.

1. **The paired AI assistant sees purchase history**, along with everything else
   in the app. No separate gate. *(Consequence: the AI-visibility question does
   NOT need the 1.10.0 permissions model, which stays scoped to burn.)*

2. **Parse the receipt, then delete the image.** Once the line items are
   confirmed the photo has done its job. The numbers are kept; the card last
   four, the loyalty number and any name are not kept at all, rather than kept
   encrypted. Least data held.

   **Known cost, accepted:** old receipts cannot be re-read if the parser later
   improves — and there is no corpus to improve the parser *with*. The parser is
   built once, on the spike set (§6), which lives on Juan's Mac outside the app.
   After that it is what it is unless samples are deliberately kept. For a
   family app that is the right trade, but it is a trade, and it argues for
   spending real effort on the spike rather than shipping a parser and planning
   to tune it in the field. **There will be no field.**

3. **No readable copy of a receipt in the Files-visible folder.** A receipt is
   not a picture anyone browses, and a year of them sitting outside the app lock
   is a heavier disclosure than `AUDIT_2026-08-22_photos.md` signed off on for
   photos. Encrypted copy only — and since (2) deletes it after parsing, mostly
   moot, which is a good sign the two decisions agree.

4. **Open Food Facts contribution is opt-in, asked once.** One prompt the first
   time an unknown product is scanned, then remembered. Contributing sends
   *product* data to a public database, never household data — but in an app
   built on the premise that nothing leaves without you knowing, that is a
   choice to be made rather than a default to inherit.

5. **The shop is asked once, when a scanning session starts.** One tap at the
   door, then silence. This matters more than it looks: shelf-label prices
   captured during a session are the freshest prices the household has, and
   inferring the store from a receipt later would leave every un-receipted
   session's prices unattributed. Needs a per-household store list that grows —
   the chains actually used, plus free text, not a hardcoded list of Irish
   supermarkets.

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
