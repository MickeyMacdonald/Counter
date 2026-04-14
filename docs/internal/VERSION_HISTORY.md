---
title: Counter Version History & Roadmap
status: INTERNAL — reconstructed from git history
last_updated: 2026-04-14
companion_doc: VERSIONING.md
---

> **Strategic decision (2026-04-14):** Data continuity is the dominant theme of `0.9.x-beta`. The `0.9 → 1.0` arc is then mostly cosmetic — UI cleanup against the Client / Session / Piece architecture, refined for the beta-tester use case. **Migration safety lands before features.** The forward-looking sections below have been rewritten to reflect this.


# Counter Version History & Roadmap

> **What this is:** A reconstructed, version-by-version map of what landed in Counter (looking backwards via `git log`) and a high-level forward roadmap framed in **versions**, not tickets. For the rules that govern these version numbers, see [`VERSIONING.md`](./VERSIONING.md). For the granular task list, see [`TODO.md`](../../TODO.md).
>
> **A caveat on history:** Only versions **0.4, 0.5, and 0.6** are explicitly tagged in commit messages. Versions **0.1–0.3, 0.7, and 0.8** are reconstructed from commit dates, scope, and the fact that the in-app `About` screen advanced from `Pre-Alpha 0.2` (per the now-superseded TODO) through to `Alpha 0.8` today. Treat pre-0.4 and post-0.6 boundaries as best-guess approximations, not authoritative tags. Going forward, versions should be tagged in git so this document stops needing reconstruction.

---

## Looking backwards

### 0.1 – 0.3 · Foundation (pre-git → 2026-03-15)
> *Rolled into the initial commit `7ae149b` on 2026-03-15. Treat as one collapsed phase — the scaffolding before version control.*

- **18 SwiftData models** including `Client`, `Piece`, `Booking`, `TattooSession`, `Payment`, `Agreement`, `UserProfile`, `AvailabilitySlot`, `AvailabilityOverride`, `CustomSessionType`, `FlashPriceTier`, `ImageGroup`, `PieceImage`, `InspirationImage`, `CommunicationLog`, `CustomEmailTemplate`
- **Core services:** `BusinessLockManager` (biometric lock), `EmailService` + `EmailTemplateService`, `ExportService`, `PDFReportService`, `PhotoImportService`, `ImageStorageService`, `SeedDataService`
- **Booking flows:** add/edit/detail/calendar/day-list views
- **Client flows:** list, detail, edit, gallery, row
- **Pieces & gallery:** detail/edit/list/row, full-screen viewer, image gallery, inspiration gallery, flash gallery, stage manager, time log, gallery groupings by client, placement, rating, stage
- **Financial dashboard** with payment history, payment log, per-piece financial detail
- **Agreements & signatures:** edit, detail, signature capture
- **Business lock** UI with biometric gating
- **Settings** scaffolding for availability, email templates, profile, booking, and a unified `SettingsView`
- **Initial `ToDoView`** as a personal task surface inside the app

> **State at end of phase:** Counter could already do most of what its README advertises. The MVP shape was in place before the first git commit.

---

### 0.4 · Tab system, donations, reports, session rates (2026-03-15 → 2026-03-16)
> Commits `2873498` (CounterPA 0.4) and `e0e6f9b` (CounterV0.4)

- **`WorksTabView` + `SessionsTabView`** — top-level tab restructuring around a Works/Sessions/Gallery model
- **`AvailableFlashGalleryView`** — flash that's available to book, separate from the artist-private flash portfolio
- **Donations infrastructure:** `DonationStore` service + `SettingsDonationView` (the in-app tier flow that the website donate page now mirrors)
- **`SettingsReportsView`** — entry point for PDF report generation
- **`SettingsSessionRatesView`** + `SessionRateConfig` model — session-type pricing configuration
- **`PDFReportService` expansion** (+155 lines) — more report formats
- **Big `SettingsView` split** (−533 lines) as setting subviews moved into their own files
- **`GalleryTabView` reorganization** — a recurring theme in 0.4–0.6

---

### 0.5 · Navigation polish, settings deepening, ToDo overhaul (2026-03-16)
> Commits `28a4d42` (V0.5-Sidebar Edits) and `386cfd1` (CounterPA0.5)

- **Sidebar edits** in `ContentView` — the navigation chrome that becomes the spine of 0.6's coordinator
- **`SettingsView` grew** (+339 lines) as more configuration surfaces landed
- **`SessionsTabView` modifications** — refinement following the 0.4 introduction
- **`ToDoView` rewritten** (+232 / −232) — a from-scratch pass on the in-app task surface

> **Honest read:** 0.5 is mostly polish on top of 0.4. It's a small release.

---

### 0.6 · Navigation coordinator, session split, gallery groups (2026-03-16)
> Commits `2e247e0` (CounterPA0.6) and `bc52a64` (Monday Session 0.6)

- **`AppNavigationCoordinator`** — central navigation state, replacing the ad-hoc bindings of 0.5
- **Sessions split:** `SessionDetailView` + `SessionsListView` finally separated from the tab container
- **`BookingDetailView` massively expanded** (+648 lines) — booking became a real first-class screen
- **`CustomGalleryGroup` model** + **`GalleryByCustomGroupView`** — user-defined gallery groupings
- **`GalleryBySizeView`** — another grouping axis
- **Smaller piece/booking model field additions**

> **State at end of phase:** Counter is functionally complete on the "looking at your work" side. The next phase pivots to public presence and reliability.

---

### 0.7 · Public presence, recovery system, smart pills, analytics (2026-04-07)
> *Inferred phase. Spans the gap between 2026-03-16 and 2026-04-07, then a flurry of work on April 7. Probably the moment Counter started feeling like a real product instead of a personal tool.*

- **GitHub Pages site** — `index.html`, `contact.html`, `donate.html`, `style.css`, brand icon (`28428e0`)
- **README** added at the project root (`a1c19a5`)
- **Donate page** synced to match in-app tier layout (`e0b34bf`, `1aa941d`)
- **Project rename** from `CountePreAlpha` → `CounterPreAlpha` and Xcode-project consolidation (`624ec64`)
- **`RecoveryBackup` model + `RecoveryService`** — the in-app backup/restore engine, a 1,177-line drop in a single commit (`37af92e`)
- **`SettingsRecoveryView`** — UI for the recovery system (`3148f66`)
- **Custom Email Fields rework with smart pills** — net simplification (+363 / −583), the email template system became token-driven (`594338e`)
- **Analytics adjustments + graph views** (`ff132bd`)
- **Client mode tweak** (`1a4e0c0`)
- **Settings additions** + **`SettingsFinancialView`** with the financial settings model (`07e7a72`, `0e2f02b`)
- **First `TODO.md`** committed (`6a87a30`) — the project officially has a tracked roadmap

> **State at end of phase:** Counter has a public face, a backup system, and a configurable financial layer. This is the version where the app stopped being "an iPad project" and started being "a product with a website."

---

### 0.8 · File hierarchy, naming refactor, polish, draft legal (2026-04-08 → 2026-04-14)
> *Current version. Tagged `Alpha 0.8` in `SettingsAboutView.swift` as of 2026-04-14.*

- **Settings repair, orphan deletion, naming convention refactor** (+615 / −1033) — net code reduction, a real cleanup pass (`9021f5f`)
- **Settings tweaks** following the refactor (`b540008`)
- **Built-In views split** out of `SettingsView` (+1009) — the recurring "shrink the monolith" pattern (`b3816ee`)
- **Aesthetic tweaks and reorganisation** across 70 files (`d4894c1`)
- **Finishing new file hierarchy** (`b1e7d1d`) and **testing files** (`081acad`)
- **Tab and navigation tweaks** (`af98ca1`)
- **Seed data rework + recovery tweaks** (+1383 / −1679, another net reduction) (`1422c05`)
- **Beta TODO + drafting policy/terms** — version label sync, draft Privacy Policy, draft Terms of Service, draft Versioning Strategy, HTML mirrors of the legal drafts (`20fe2ed`)

> **State right now:** Counter is the right *shape* for 1.0. The remaining work is gates, not features.

---

## Looking forwards

The forward map is intentionally **version-grained**, not ticket-grained. Each version below has a single coherent theme. Detailed work items live in [`TODO.md`](../../TODO.md); the rules that govern channel transitions live in [`VERSIONING.md`](./VERSIONING.md).

### `0.8.x` · Foundation: VersionedSchema + Recovery Mode
> Patch line on the current Alpha. Lays the data-safety foundation that everything after depends on. Schema *structure* doesn't change; the *infrastructure around* the schema does.

**The work:**

- **`CounterSchemaV1`** — wrap the current 18-model schema in a `VersionedSchema`, even though it hasn't structurally changed yet. This is the seam every future migration plugs into.
- **`CounterMigrationPlan`** — a `SchemaMigrationPlan` with `V1` as the only stage, ready to accept `V2` later.
- **Recovery Mode launch path** — `CounterApp.swift` no longer calls `fatalError` when the `ModelContainer` can't open. Instead, the app routes the user to a minimal screen that can read the recovery folder, view backup metadata, and trigger a restore.
- **Lawyer review** of the Privacy Policy and Terms of Service drafts; resolve every `[VERIFY]` and `[DECIDE]` tag.
- **Reconcile drift** between in-app About / `README.md` / `TODO.md` / `Info.plist`.

> **Exit gate:** A schema change to V2 made on a test branch can no longer brick the app on launch. The recovery mode path has been triggered at least once on a real device with a deliberately broken store.

---

### `0.9.0-beta` · Data Continuity & Restore
> Channel jump: Alpha → Beta. **The dominant theme of this release is "the Client / Session / Piece architecture survives any future schema change with zero data loss."** First TestFlight is conditional on this being real, not theoretical.

**The work — three pillars:**

**1. Migration Safety (the rule from `VERSIONING.md`)**
- Convert the existing `Drafting → initialDrafting` Codable shim into a formal `MigrationStage.custom` from `CounterSchemaV1` → `CounterSchemaV2`
- Convert the `piece.imageGroups` legacy field into a formal migration that consolidates into session-based storage and removes the dual relationship
- Automatic backup taken **before** any migration stage runs
- The `RecoveryService.versionMismatch` hard-reject becomes a real forward-migration path: V1 backups can be loaded by V2 code

**2. Backup Hardening**
- **Embed all image binaries in backup files** (full filesystem cost is acceptable for beta, will be revisited later)
- **SHA-256 checksum** on every backup file, validated on restore
- **Pre-restore snapshot** taken automatically before any destructive restore, slotted into `pre-restore-{timestamp}` for one-tap rollback
- **Record-count sanity check** before wipe — a backup with zero records can't silently destroy a populated store
- **Image copy failures propagate** — restore aborts loudly instead of silently producing missing files

**3. Test Coverage**
- Round-trip tests for every model: empty store, full store, relationship cycles, large image counts
- Migration tests: V1 → V2 backup loaded by V2 code, V2 backup loaded by V2 code
- Failure tests: corrupted JSON, truncated files, missing checksum, wrong version, missing images
- Recovery mode path tests: deliberately break the store, verify the launch routes to recovery

**Three remaining beta gates from the original audit (still required, but secondary to data safety):**
- Privacy Policy + Terms of Service hosted at real public URLs
- TestFlight listing live in App Store Connect
- Booking notifications and client search (descoped to "minimum viable" if needed to make room for the data work)

> **Exit gate:** First TestFlight build accepted by Apple, distributed to at least 3 external testers, **a forced V1 → V2 migration on a real beta tester's iPad has been demonstrated to preserve all data including images**, no P0/P1 bug reports.

---

### `0.9.x-beta` · Stabilization
> Patch line on the beta. Bug fixes and small UX corrections from TestFlight feedback. **No new features and no schema changes.** Anything tempting that isn't a fix gets deferred to 1.0-rc or 1.1.

> **Exit gate:** Two consecutive `0.9.x-beta` builds with no new bug reports of severity P0–P2 and no migration regressions.

---

### `1.0.0-rc.N` · Cosmetic polish & release candidates
> Bug-fix and **cosmetic / UI cleanup** only. The Client / Session / Piece architecture is frozen by this point. RC builds refine the visual layer against the use case beta testers actually exercise.

**The work:**
- UI cleanup driven by TestFlight feedback — what testers actually touched, what they ignored, what confused them
- Final pass on visual consistency, typography, spacing, empty states
- Final pass on accessibility (VoiceOver labels, Dynamic Type)
- Haptic feedback on key actions
- Each RC must survive at least 48 hours on TestFlight without a new defect before the next RC can ship

> **Exit gate:** App Store submission queued, Apple review approval in hand, all RCs converged.

---

### `1.0.0` · Public launch
> The first build with `CFBundleShortVersionString = 1.0.0`. This is the version users see in the App Store. Treat it as a marketing milestone, not just a number — the in-app About screen, README, website hero, and any "status" badge all flip together on this day.

> **Exit gate:** N/A — this is the destination.

---

### `1.1.x` · First post-launch wave
> Features deferred from 1.0 because they didn't gate the launch. The data-safety foundation laid in 0.8/0.9 is what makes shipping these safely possible.

- **Calendar view** alongside the existing list-based booking view
- **Dashboard charts** for earnings-over-time, monthly breakdown, top clients
- **Client search & filter polish** beyond the 0.9 minimum
- **Sample data opt-in** for new users
- **Onboarding walkthrough** beyond the 3-step setup
- **Backup retirement decision** — revisit "embed all images" tradeoff now that migration is proven; possibly switch to deduplicated/incremental backups

> **Exit theme:** "Counter is a real product, and now it has the visualizations and onboarding to back that up."

---

### `1.2.x` · Communication & data portability
- **SMS templates** parallel to the email template system
- **Automated follow-ups** (healed-photo check-ins)
- **Data export** (full JSON/CSV)
- **Data import** for artists migrating from spreadsheets
- **Client merge / dedup**
- **Client import from Contacts**

> **Exit theme:** "Counter plays nicely with the rest of your tools."

---

### `1.3.x` · Multi-device & financial depth
- **iCloud sync** for multi-iPad studios *(this is a `MAJOR` candidate post-1.0 if it requires schema changes — see `VERSIONING.md`)*
- **Invoice generation** with line items and payment terms
- **Tax summary export**
- **Multi-currency support**
- **Recurring bookings**

> **Exit theme:** "Counter scales beyond a single artist at a single station."

---

### `2.0.0` · *(speculative)*
The first plausible `MAJOR` bump after 1.0. Most likely triggered by **iCloud sync** if it requires a schema migration users will perceive, or by a substantial UX overhaul that re-onboards existing users. Not committed to — listed here so the version-history doc has a horizon.

---

## Cadence observations

A few patterns from the backwards walk that are worth keeping in mind for forward planning:

- **0.4 → 0.6 was a single weekend** (March 15–16). Three "version" releases in 36 hours. That's fine for an unreleased project but won't survive contact with TestFlight users.
- **The March 16 → April 7 gap was three weeks** of no commits. Future gaps should be marked explicitly as a `0.x.0` boundary rather than left as silent drift.
- **Most "version" commits in the existing history are net-negative on lines** (refactors, cleanups, settings splits). That's healthy — Counter has been growing more by deletion than by addition lately, which is consistent with being close to feature-complete.
- **Recovery, biometric lock, and email templates all landed before notifications, search, or sync.** The harder-but-deferred items are the ones gating beta. That's the correct order of operations for an offline-first studio app, but it does mean 0.9 will feel like "the boring infrastructure release" — plan the messaging accordingly.

---

## Maintenance

- This document is **regenerated**, not append-only. When a new version ships, rewrite the relevant section to reflect what actually landed, then move the forward-looking entry one step closer to "shipped."
- **Tag versions in git** going forward. `git tag v0.8.0` today would prevent the next reconstruction from being guesswork.
- Update `last_updated` at the top whenever you touch this file.
