# Counter — Project TODO

Last updated: 2026-04-14

> **Reading order:** This file is the granular task list. The version-grained roadmap lives in [`docs/internal/VERSION_HISTORY.md`](docs/internal/VERSION_HISTORY.md). The rules that govern channel transitions live in [`docs/internal/VERSIONING.md`](docs/internal/VERSIONING.md). Items below are tagged with their target version using `[v0.8.x]` / `[v0.9.0]` / `[v1.0]` markers.

---

## Data Safety & Migration  ← top priority

> **Strategic decision (2026-04-14):** Data continuity is the dominant theme of `0.9.x-beta`. Counter holds real client data, including health notes, intake answers, and signed agreements. A single bricked launch on a real artist's iPad is a trust event we cannot recover from. Everything in this section ships before booking notifications, before client search, before any 1.0 cosmetic work.
>
> See [`docs/internal/VERSION_HISTORY.md`](docs/internal/VERSION_HISTORY.md) for the version-grained narrative behind these items.

### `[v0.8.x]` Foundation — schema versioning + recovery mode

- [x] **`CounterSchemaV1`** — wrap the current 18-model schema in a `VersionedSchema`, even though it hasn't structurally changed yet. This is the seam every future migration plugs into. *(`Counter/Migrations/CounterSchemaV1.swift`)*
- [x] **`CounterMigrationPlan`** — a `SchemaMigrationPlan` with `V1` as the only stage, ready to accept `V2` later. *(`Counter/Migrations/CounterMigrationPlan.swift`)*
- [x] **Recovery Mode launch path** — `CounterApp.swift` no longer calls `fatalError` when the `ModelContainer` can't open. Route the user to a minimal screen that can read the recovery folder, view backup metadata, and trigger a reset. *(`Counter/App/RecoveryModeView.swift`; `LaunchState` enum in `CounterApp.swift`)*
- [ ] **Force-trigger test** — deliberately break the store on a test build, verify the launch routes to recovery mode and the user can restore from a backup without losing data.
- [ ] **Add new files to Xcode target** — `CounterSchemaV1.swift`, `CounterMigrationPlan.swift`, `RecoveryModeView.swift` need to be added to the `Counter` app target in Xcode (Windows-side edits don't update `project.pbxproj`).
- [ ] **Register `CustomDiscount` model** — `CustomDiscount.swift` exists under `Counter/Models/` but was never registered in the schema. Adding it is itself a schema change, so it must land as the first `V1 → V2` migration, not as a silent edit to V1.

### `[v0.9.0]` Pillar 1 — Migration Safety

- [ ] **Convert `Drafting → initialDrafting` shim** to a formal `MigrationStage.custom` from `CounterSchemaV1` → `CounterSchemaV2`. The hand-rolled `Codable` adapter in `TattooSession.swift` gets retired.
- [ ] **Convert `piece.imageGroups` shim** to a formal migration that consolidates into session-based storage and removes the dual relationship.
- [ ] **Pre-migration auto-backup** — every `MigrationStage` runs only after a backup of the current state has been written.
- [ ] **Forward migration of backups** — `RecoveryService.versionMismatch` becomes a real forward-migration path. V1 backups can be loaded by V2 code.

### `[v0.9.0]` Pillar 2 — Backup Hardening

- [ ] **Embed all image binaries** in backup files. Filesystem cost is acceptable for beta (will be revisited in 1.1.x).
- [ ] **SHA-256 checksum** on every backup file, validated on restore.
- [ ] **Pre-restore snapshot** — automatic backup of current state before any destructive restore, slotted into `pre-restore-{timestamp}` for one-tap rollback.
- [ ] **Record-count sanity check** — a backup with zero records can't silently destroy a populated store.
- [ ] **Image copy failures propagate** — restore aborts loudly instead of silently producing missing files.

### `[v0.9.0]` Pillar 3 — Test Coverage

- [ ] **Round-trip tests** for every model: empty store, full store, relationship cycles, large image counts.
- [ ] **Migration tests** — V1 → V2 backup loaded by V2 code, V2 backup loaded by V2 code.
- [ ] **Failure tests** — corrupted JSON, truncated files, missing checksum, wrong version, missing images.
- [ ] **Recovery mode path tests** — deliberately break the store, verify the launch routes to recovery.

---

## Beta Gates (non-data)

> The remaining items required for the Alpha → Beta channel jump per [`VERSIONING.md`](docs/internal/VERSIONING.md). Secondary to data safety but still required to ship `0.9.0-beta`.

### `[v0.8.x]` Legal & version sync

- [ ] **Privacy policy lawyer review** — walk `docs/legal/privacy-policy.md` with a Canadian privacy lawyer; resolve every `[VERIFY]` tag.
- [ ] **Terms of Service lawyer review** — same treatment for `docs/legal/terms-of-service.md`; resolve every `[VERIFY]` and `[DECIDE]` tag.
- [ ] **Reconcile version surfaces** — in-app About / `README.md` / `Info.plist` / website hero must agree.
- [ ] **`CFBundleVersion` scheme** — adopt the scheme from `VERSIONING.md` or explicitly reject it in writing.

### `[v0.9.0]` Distribution & feature minimums

- [ ] **Privacy policy + ToS hosted at real public URLs** — remove `noindex` from `docs/privacy.html` and `docs/terms.html`, add to public footer.
- [ ] **TestFlight listing** in App Store Connect.
- [ ] **Booking notifications (minimum viable)** — local notifications for upcoming bookings and prep checklists. May be descoped further if data work needs the room.
- [ ] **Client search (minimum viable)** — search by name across the client list. Tag/status filtering deferred to 1.1.

---

## App Store Submission Checklist

- [ ] Privacy policy URL (hosted on website) — *draft exists at `docs/legal/privacy-policy.md`, awaiting lawyer review*
- [ ] Terms of Service URL (hosted on website) — *draft exists at `docs/legal/terms-of-service.md`, awaiting lawyer review*
- [ ] App Store screenshots (12.9" iPad)
- [ ] App description and keywords
- [ ] App icon exported at required sizes
- [ ] TestFlight beta testing round
- [ ] Age rating questionnaire
- [ ] Review any rejected/flagged items from Apple review

---

## External (Website, Infrastructure, Distribution)

### `[v0.8.x]` High Priority
- [ ] **Custom domain setup** — Point `thecounterapp.ca` (Cloudflare) at GitHub Pages with CNAME record
- [ ] **Activate contact form** — FormSubmit.co requires a one-time email confirmation from `mickey@thecounterapp.ca` before messages come through
- [ ] **App Store / TestFlight listing** — Create the listing so download buttons have a real destination
- [ ] **Replace placeholder App Store links** — All "Download" buttons on the site currently fire JS alerts

### `[v0.9.0]` Medium Priority
- [ ] **Donation payment flow** — Decide on web approach: Stripe payment links, Buy Me a Coffee, or remove web buttons and direct to in-app only
- [ ] **Open Graph & SEO meta tags** — Add `<meta description>`, OG image, and OG title so link previews look professional when shared
- [ ] **App screenshots on features page** — Even 2–3 iPad mockups would make the features page significantly more compelling
- [ ] **Proper favicon** — Generate sized favicons from AppIcon.png (16x16, 32x32, apple-touch-icon)

### `[v1.0]` Lower Priority
- [ ] **Analytics** — Cloudflare Analytics (free, privacy-respecting) or Plausible to understand traffic
- [ ] **Email setup verification** — Confirm `mickey@thecounterapp.ca` is receiving mail via Cloudflare email routing

---

## Post-1.0 Features

> Items deferred from the 1.0 critical path. Listed for visibility, not commitment. The version map in `VERSION_HISTORY.md` slots these into 1.1 / 1.2 / 1.3 themes.

### `[v1.1]` Polish & visualization
- [ ] **Calendar view** — Visual calendar (day/week/month) alongside the list-based booking view
- [ ] **Dashboard charts** — Visual earnings-over-time, monthly breakdown, top clients by revenue
- [ ] **Sample data opt-in** — Offer to load demo data so new users can explore before entering their own
- [ ] **Guided onboarding walkthrough** — The 3-step setup exists but a visual tour of key features (clients, bookings, gallery) would reduce drop-off
- [ ] **Backup retirement decision** — revisit "embed all images" tradeoff now that migration is proven; possibly switch to deduplicated/incremental backups
- [ ] **Accessibility audit** — VoiceOver labels, Dynamic Type support, contrast checks
- [ ] **iPad multitasking** — Ensure Split View and Slide Over work cleanly
- [ ] **Haptic feedback** — Subtle haptics on key actions (payment logged, booking confirmed, signature captured)

### `[v1.2]` Communication & data portability
- [ ] **SMS templates** — Extend the email template system to support SMS/iMessage for quick confirmations
- [ ] **Automated follow-ups** — Suggest or schedule healed-photo check-ins after a configurable number of weeks
- [ ] **Data export** — Full data export (JSON/CSV) for backup or migration purposes
- [ ] **Data import** — Import clients/pieces from spreadsheets for artists switching from manual tracking
- [ ] **Client merge/dedup** — Handle duplicate client entries (common when importing or re-entering)
- [ ] **Client import from Contacts** — Pull name/email/phone from the iPad Contacts app
- [ ] **Gallery sharing** — Export or share curated gallery views as a link or PDF portfolio
- [ ] **Image compression / storage management** — Surface storage usage and offer cleanup for large libraries

### `[v1.3]` Multi-device & financial depth
- [ ] **iCloud sync** — Sync data across multiple iPads (multi-device studios). *Pre-requisite: migration safety (0.9) is proven and stable. Sync without migration safety would propagate corruption across devices.*
- [ ] **Invoice generation** — Formal invoice PDFs for clients with business details, line items, and payment terms
- [ ] **Tax summary export** — Summarize income by category for tax filing (CSV or PDF)
- [ ] **Multi-currency support** — Currently USD default; allow CAD and other currencies with proper formatting
- [ ] **Recurring bookings** — For ongoing clients (e.g., monthly touch-ups, regular hairdressing appointments)

---

## Completed

- [x] **Version bump** — Synced to "Alpha 0.8" (2026-04-13); see `docs/internal/VERSIONING.md` for the strategy going forward
- [x] **Privacy Policy draft** — `docs/legal/privacy-policy.md` + `docs/privacy.html` (2026-04-13, awaiting lawyer review)
- [x] **Terms of Service draft** — `docs/legal/terms-of-service.md` + `docs/terms.html` (2026-04-13, awaiting lawyer review)
- [x] **Versioning Strategy** — `docs/internal/VERSIONING.md` (2026-04-13)
- [x] **Version History & Roadmap** — `docs/internal/VERSION_HISTORY.md` (2026-04-14)
- [x] **Schema versioning + recovery launch path** — `CounterSchemaV1`, `CounterMigrationPlan`, `RecoveryModeView`, and `LaunchState` routing in `CounterApp.swift` (2026-04-14)
