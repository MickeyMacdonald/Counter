# Counter — Project TODO

Last updated: 2026-04-07

---

## External (Website, Infrastructure, Distribution)

### High Priority
- [ ] **Custom domain setup** — Point `thecounterapp.ca` (Cloudflare) at GitHub Pages with CNAME record
- [ ] **Activate contact form** — FormSubmit.co requires a one-time email confirmation from `mickey@thecounterapp.ca` before messages come through
- [ ] **App Store / TestFlight listing** — Create the listing so download buttons have a real destination
- [ ] **Replace placeholder App Store links** — All "Download" buttons on the site currently fire JS alerts

### Medium Priority
- [ ] **Donation payment flow** — Decide on web approach: Stripe payment links, Buy Me a Coffee, or remove web buttons and direct to in-app only
- [ ] **Open Graph & SEO meta tags** — Add `<meta description>`, OG image, and OG title so link previews look professional when shared
- [ ] **App screenshots on features page** — Even 2–3 iPad mockups would make the features page significantly more compelling
- [ ] **Proper favicon** — Generate sized favicons from AppIcon.png (16x16, 32x32, apple-touch-icon)

### Lower Priority
- [ ] **Analytics** — Cloudflare Analytics (free, privacy-respecting) or Plausible to understand traffic
- [ ] **Privacy policy page** — Required for App Store submission; good to host on the website *(draft at `docs/legal/privacy-policy.md`, awaiting accuracy review)*
- [ ] **Terms of service page** — Needed alongside privacy policy for App Store review *(draft at `docs/legal/terms-of-service.md`, awaiting accuracy review)*
- [ ] **Email setup verification** — Confirm `mickey@thecounterapp.ca` is receiving mail via Cloudflare email routing

---

## App — Features & Improvements

### Onboarding & First Run
- [ ] **Guided onboarding walkthrough** — The 3-step setup exists but a visual tour of key features (clients, bookings, gallery) would reduce drop-off
- [ ] **Sample data opt-in** — Offer to load demo data so new users can explore before entering their own

### Client Management
- [ ] **Client search & filtering** — Search by name, tag, or status across the client list
- [ ] **Client merge/dedup** — Handle duplicate client entries (common when importing or re-entering)
- [ ] **Client import from Contacts** — Pull name/email/phone from the iPad Contacts app

### Booking & Scheduling
- [ ] **Calendar view** — Visual calendar (day/week/month) alongside the list-based booking view
- [ ] **Booking reminders / notifications** — Local notifications for upcoming bookings and prep checklists
- [ ] **Recurring bookings** — For ongoing clients (e.g., monthly touch-ups, regular hairdressing appointments)

### Gallery & Images
- [ ] **Clean up legacy ImageGroup migration** — `piece.imageGroups` is marked "kept temporarily during migration"; consolidate to session-based storage when safe
- [ ] **Gallery sharing** — Export or share curated gallery views as a link or PDF portfolio
- [ ] **Image compression / storage management** — Surface storage usage and offer cleanup for large libraries

### Financial
- [ ] **Dashboard charts** — Visual earnings-over-time, monthly breakdown, top clients by revenue
- [ ] **Tax summary export** — Summarize income by category for tax filing (CSV or PDF)
- [ ] **Multi-currency support** — Currently USD default; allow CAD and other currencies with proper formatting
- [ ] **Invoice generation** — Formal invoice PDFs for clients with business details, line items, and payment terms

### Communication
- [ ] **SMS templates** — Extend the email template system to support SMS/iMessage for quick confirmations
- [ ] **Automated follow-ups** — Suggest or schedule healed-photo check-ins after a configurable number of weeks

### Data & Sync
- [ ] **iCloud sync** — Sync data across multiple iPads (multi-device studios)
- [ ] **Data export** — Full data export (JSON/CSV) for backup or migration purposes
- [ ] **Data import** — Import clients/pieces from spreadsheets for artists switching from manual tracking

### Polish & Quality of Life
- [ ] **Legacy SessionType cleanup** — Remove "Drafting" → "initialDrafting" migration shim once all users have migrated
- [ ] **Accessibility audit** — VoiceOver labels, Dynamic Type support, contrast checks
- [ ] **iPad multitasking** — Ensure Split View and Slide Over work cleanly
- [ ] **Haptic feedback** — Subtle haptics on key actions (payment logged, booking confirmed, signature captured)
- [x] **Version bump** — Synced to "Alpha 0.8" (2026-04-13); see `docs/internal/VERSIONING.md` for the strategy going forward

---

## App Store Submission Checklist
- [ ] Privacy policy URL (hosted on website) — *draft exists at `docs/legal/privacy-policy.md`, needs review for accuracy*
- [ ] App Store screenshots (6.5" and 12.9" iPad)
- [ ] App description and keywords
- [ ] App icon exported at required sizes
- [ ] TestFlight beta testing round
- [ ] Age rating questionnaire
- [ ] Review any rejected/flagged items from Apple review
