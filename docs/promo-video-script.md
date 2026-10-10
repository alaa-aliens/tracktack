# TrackTack — 60-second promo script

**Format:** vertical 9:16 (Reels / TikTok / WhatsApp Status), with a 16:9 crop for the landing page
**Runtime:** 0:58–1:00
**Voiceover:** ~145 words, read at a calm 150 wpm — unhurried, not hypey
**Audience:** owners of small trade and retail businesses (plumbing and sanitary, hardware, building materials, fit-out contractors) running the books in notebooks and WhatsApp
**Goal of the video:** one promise — *stop guessing where your money is* — proven by five real screens in under a minute

---

## Shot list

| Time | Visual | Voiceover | On-screen text |
|---|---|---|---|
| 0:00–0:05 | No UI yet. Close, handheld: a spike of paper receipts on a shop counter, a notebook with columns crossed out, a thumb scrolling a long WhatsApp thread. Ambient shop sound. | "Three notebooks, a pile of receipts, and a WhatsApp thread you're scared to open." | — |
| 0:05–0:10 | Hard cut to black for a beat. Receipts drop out of frame. | "That's not a business. That's a guessing game." | — |
| 0:10–0:16 | Logo on ink background, lime mark. Snap-cut to the Overview screen: cash on hand, cash in vs out, month by month. | "TrackTack. Invoices, expenses, and cash — in one place." | **TrackTack** |
| 0:16–0:25 | Sales → new invoice. Screen-record the real thing: customer picked from the list, two line items added from Products & services, logo visible on the invoice preview, terms set to Net 7. Then the share sheet → **Send on WhatsApp**. | "Build an invoice in seconds. Your logo, your line items, your terms. Send it on WhatsApp before you leave the customer's shop." | *Invoice → WhatsApp* |
| 0:25–0:33 | **Record payment** on a partially paid invoice: balance due drops. Cut to Receivables aging — the Overdue column — and tap **Send reminder**. | "Record the payment when it lands. See exactly who still owes you, and how late they are — one tap sends the reminder." | *Who owes you. How late.* |
| 0:33–0:41 | Phone held at a hardware-shop counter. **Add receipt photo** → camera → category *Plumbing & hardware fittings* → amount in JOD → saved. The photo appears in the expense row. | "Snap the receipt at the hardware shop. Category, amount, photo — logged." | *Snap it. It's filed.* |
| 0:41–0:49 | Funding screen: cash on hand, then the **Held by** breakdown showing a partner covering costs, and the line about sending him the difference to square up. | "Know your cash on hand, and who's holding it — so nobody's covering costs out of their own pocket without getting squared up." | *Cash on hand — and who's holding it* |
| 0:49–0:55 | Plan screen. Pull focus onto three numbers in turn: sales needed per month to break even, runway, months to recover setup. | "Then the question that actually matters: what do you need to sell this month to break even — and when do you get your setup money back?" | *Break-even. Runway. Setup recovered.* |
| 0:55–1:00 | Phone on the counter, app open on Overview. Owner steps out of frame to serve a customer. Logo and URL. | "TrackTack. Your business, on your phone." | **TrackTack** / *Add to home screen — free to start* |

---

## Alternate hooks

Shoot all three; pick in the edit, or A/B them as thumbnails.

- **A (default, pain):** "Three notebooks, a pile of receipts, and a WhatsApp thread you're scared to open."
- **B (question):** "Quick — how much money does your business actually have right now?" *(beat)* "Not in the bank. Right now."
- **C (number):** "You invoiced four thousand this month. You collected one eight hundred. Nobody told you." — pairs with opening straight on Receivables aging.

Hook B tests best for a cold feed: it makes the viewer fail at something before the product appears.

---

## Production notes

**Screens are the product — record them, don't mock them.** Every frame in the table above is a real view of the app. Set up a demo business first so nothing is placeholder-grey: a handful of customers and suppliers, ~8 products and services, 10–12 invoices across three months with a believable mix of paid, partial and overdue, 20+ expenses spread across categories, two receipt photos, and funding entries from two partners so **Held by** has something to say. Use JOD, the app's default.

**Use the demo names already in the app** (Al-Jamal Ceramics & Porcelain, Louay Al-Sirisi Sanitary, Ziad Ababneh Building Materials). They read as real to the target customer in a way "Acme Co." never will — and they're the same names a viewer sees when they open the app, so the video and the first run match.

**Capture:** record the PWA installed to the home screen, not in a browser tab — no address bar. iPhone screen recording at 60 fps, then speed-ramp the typing: real-time for the tap that matters, 2–3× through form filling. Never let a cursor hunt. Film the two counter-top shots in a real shop with available light; the hands should look like working hands.

**Grade and type:** match the app's palette — ink `#101113`, lime `#CDF663`, paper `#EFF1EF`. Titles in IBM Plex Sans (the app's own face) so cards and captions feel continuous. Keep on-screen text to the short lines in the table; the voiceover carries the rest.

**Sound:** mid-tempo, dry, no build-and-drop. Keep real sound under the VO — counter noise at 0:00, the camera shutter at 0:36, the WhatsApp send tone at 0:24. Those three cues do more than any music sting.

**Captions:** burn them in. Most of this audience watches muted. Caption the voiceover verbatim rather than paraphrasing it.

**Cuts to pull from this edit:**
- **0:15 version** — the invoice beat (0:16–0:25) plus the closing card. One promise: invoice to WhatsApp before you leave the shop.
- **0:30 version** — invoice, receipt snap, break-even, close. Drop the Held-by and aging beats.
- **Six stills** for the landing page and app-store listing: Overview, invoice preview, receivables aging, expense with photo, Funding, Plan.

**Arabic cut:** the app ships Arabic display names and the IBM Plex Sans Arabic face, so an Arabic version is a re-record and a re-shoot of the screens with the UI in Arabic — not a subtitle pass over this footage, because the screens flip to RTL. Same shot list, same timings; the voiceover translates without losing the beat count.

---

## Claims check

Everything the voiceover asserts is in the shipped app: invoice building with line items, discounts, terms and your own logo; sharing by WhatsApp, email, print/PDF and image download; partial and full payment recording; receivables aging with WhatsApp reminders; categorised expenses with receipt photos; funding with cash on hand and a per-person *Held by* view; and the Plan view's break-even, runway and setup-recovery numbers.

Two things the script deliberately does **not** claim:

- **Offline use.** The service worker caches the app shell, so it opens without a connection, but data lives in Supabase and syncs online. Don't say "works offline."
- **Accounting or tax filing.** It tracks money; it doesn't file anything. Keep "bookkeeping" and "accountant" out of the copy.
