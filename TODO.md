# Counter — Project TODO

Last updated: 2026-06-09 *(synced against git history through `bd4f1ba`, 2026-05-17)*

> **Reading order:** This file is the granular task list. The version-grained roadmap lives in [`docs/internal/VERSION_HISTORY.md`](docs/internal/VERSION_HISTORY.md). The rules that govern channel transitions live in [`docs/internal/VERSIONING.md`](docs/internal/VERSIONING.md). The `.cntrdb` / photo-overhaul track lives in [`docs/internal/TASKLIST_CNTRDB_AND_PHOTO_OVERHAUL.md`](docs/internal/TASKLIST_CNTRDB_AND_PHOTO_OVERHAUL.md). Items below are tagged with their target version using `[v0.9.x]` / `[v1.0]` markers.

---

## ⭐ Next Up — the remaining items (consolidated 2026-06-09)

> Everything still genuinely open, deduped across this file, `BETA_NEXT.md`, `VERSION_HISTORY.md`, the cntrdb tasklist, and in-code TODO comments. Ordered by recommended attack order.

### 1. Ship the TestFlight build *(the critical path — everything gating beta is done except these mechanical steps)*
- [ ] **Run the test suite** — open in Xcode, any iPad simulator, `⌘U`; fix anything that surfaces. *(Unblocked since 2026-05-16.)*
- [ ] **Archive & upload** — `Any iPad Device (arm64)` → Product → Archive → Distribute App → TestFlight & App Store.
- [ ] **App Store Connect** — confirm the app record for `com.thecounterapp.app` (the live bundle ID); add the published Privacy Policy / ToS URLs to the listing; add internal testers once the build processes.
- [ ] **Deprecate legacy bundle IDs** — `com.counterprealpha.app` and `com.countercm.app` are retired; remove/deprecate their App Store Connect app records and unregister the App IDs in the Developer portal.
- [ ] **App Store assets** — 12.9" iPad screenshots, description + keywords, icon at required sizes, age rating questionnaire.

### 2. Backup coverage gap + `.cntrdb` testing
- [ ] ⚠️ **`BookingTaskTemplate` is missing from BOTH backup pipelines** *(found during 2026-06-09 sync)* — it's a live `@Model` in `CounterSchemaV4`, but has no counterpart in `RecoveryBackup` (JSON) and no table in the `.cntrdb` schema. Any restore silently drops all booking task templates. Contradicts the "zero data loss" promise of the 0.9 theme — fix before TestFlight if feasible.
- [ ] **`.cntrdb` Phase 1.6 tests** — import is destructive and has zero coverage. Round-trip (seed → export → wipe → import), manifest checksum tamper-refusal, image-count integrity, foreign-key orphan check. The JSON `RecoveryService` got exactly this treatment; `CntrdbImporter` (~1,100 lines) has none. See the cntrdb tasklist for the full test matrix.
- [ ] **Decide: co-existence vs replacement** — does `.cntrdb` eventually replace JSON backups, or stay the "professional" format alongside the JSON safety net? Flagged in the cntrdb doc as "decide before v1.0."

### 3. Small code debt
- [ ] **`SchedulingView` daily mode** — the only real TODO comments left in the codebase (`SchedulingView.swift:3,22,32,40,140`): the commented-out `.daily` case needs the exhaustive switch at line ~136 repaired, or the dead code removed.
- [ ] **`Drafting → initialDrafting` shim** → formal `MigrationStage.custom`. Shim handles all reads safely; revisit before 1.0. *(Carried from Pillar 1.)*

### 4. Repo & process hygiene
- [ ] **Delete `Workspace_counter_20260607_111734/`** — untracked grab-bag of "counter"-named files (duplicate schema copies, a `.blend`, an `.ino`, two CSS-counter JS files); the `CounterApp.swift` inside is byte-identical to the live one. Looks like an accidental search-result export.
- [ ] **`.gitignore` pass** — `.DS_Store`, `*.xcuserstate`, `.com-apple-bird-*`, design sources (`LogoDesign.af`), `Counter Dummy Images/` (or commit them deliberately).
- [ ] **Tag versions in git** going forward (`git tag v0.9.0`) — `VERSION_HISTORY.md` had to be reconstructed from guesswork because no tags exist.
- [ ] **Re-sync legal markdown ↔ HTML discipline** — `docs/legal/*.md` now mirror the published HTML (synced 2026-06-09); future legal edits go to the markdown first, then regenerate the HTML.

### 5. Website / infrastructure *(unchanged, see External section below)*
- [ ] Custom domain, contact-form activation, real download links — details under **External**.

---

## Data Safety & Migration

> **Strategic decision (2026-04-14):** Data continuity is the dominant theme of `0.9.x-beta`. Counter holds real client data, including health notes, intake answers, and signed agreements. A single bricked launch on a real artist's iPad is a trust event we cannot recover from.
>
> **Status 2026-06-13: this theme is complete** except the low-urgency Drafting shim (highlighted above). Formal `VersionedSchema` cap is V4; later additive model changes migrate implicitly. See `Counter/Services/Schema/`.

### `[v0.8.x]` Foundation — schema versioning + recovery mode ✅ complete

- [x] **`CounterSchemaV1`** — wrap the schema in a `VersionedSchema`; the seam every future migration plugs into.
- [x] **`CounterMigrationPlan`** — `SchemaMigrationPlan`, spanning V1 → V4 (V5–V8 were redundant checksum duplicates; removed 2026-06-13).
- [x] **Recovery Mode launch path** — no more `fatalError` when the `ModelContainer` can't open; routes to `RecoveryModeView`.
- [x] **Force-trigger test** — `RecoveryStoreReset.corruptStoreForTesting()` + Settings → Recovery → Developer buttons. *(2026-05-10)*
- [x] **All schema files registered in the Xcode target.** *(Verified 2026-05-10)*
- [x] **Register `CustomDiscount` model** — landed as the V1 → V2 migration.
- [x] **`CounterApp.swift` references the current schema version.** *(Fixed 2026-05-10)*

### `[v0.9.0]` Pillar 1 — Migration Safety

- [ ] **Convert `Drafting → initialDrafting` shim** to a formal `MigrationStage.custom`. Low urgency — shim handles all reads; revisit before 1.0. *(Also listed in Next Up §3.)*
- [x] **Convert `piece.imageGroups` shim** — no live model property remains. *(Closed 2026-05-10)*
- [x] **Pre-migration auto-backup** — V2→V3 custom stage has `willMigrate` backup; later lightweight stages are additive-only.
- [x] **Forward migration of backups** — `decodeIfPresent` with defaults; pre-V5/V6 JSON backups load cleanly.
- [x] **`PieceImage` legacy model removed entirely** — model deleted, remaining `inspirationImages`/`pieceImages` refs purged from `RecoveryService`. *(`e76628d`, `bd4f1ba`, 2026-05-17)*

### `[v0.9.0]` Pillar 2 — Backup Hardening ✅ complete

- [x] **Embed all image binaries** in backup files (revisit cost in 1.1.x).
- [x] **SHA-256 checksum** on every backup file, validated on restore.
- [x] **Pre-restore snapshot** with one-tap rollback (`counter_pre_restore_{timestamp}`).
- [x] **Record-count sanity check** — `RecoveryError.refuseEmptyRestore`.
- [x] **Image copy failures propagate** — pre-flight existence + post-copy count checks.

### `[v0.9.0]` Pillar 3 — Test Coverage ✅ complete *(landed 2026-05-16, commit `678af8f`)*

- [x] **Round-trip tests** — `RecoveryServiceRoundTripTests` (empty store, full store, relationships).
- [x] **Backwards-compat tests** — `RecoveryBackupCodableTests` (older backup JSON loads under current code).
- [x] **Failure tests** — `RecoveryServiceIntegrityTests` (corrupted JSON, checksum, version, missing images).
- [x] **Recovery mode path tests** — `LaunchStateTests` (broken store routes to recovery).

### `[v0.9.x]` `.cntrdb` SQLite export/import *(new since last sync — tracked in detail in the [cntrdb tasklist](docs/internal/TASKLIST_CNTRDB_AND_PHOTO_OVERHAUL.md))*

- [x] **Track 1 core shipped** (`8e05f89`) — `CntrdbSchema` (DDL + `_meta` table), `CntrdbExporter`, `CntrdbImporter` (full preflight: checksum, version, image-count, refuse-empty, pre-restore JSON snapshot), `CntrdbPackage` (manifest + SHA-256), extracted `SQLiteService`; wired into Settings → Recovery.
- [ ] **Phase 1.6 tests** — none exist. *(Highlighted in Next Up §2.)*
- [ ] **UTType registration** — `com.counter.cntrdb` is not declared in the project; Files.app treats the package as a plain folder.
- [ ] **Track 2 photo overhaul** — not started (`PhotoRegistry`, `ThumbnailCache`, orphan detection), except `PieceImage` removal which closed Phase 2.0's biggest open question.

---

## Beta Tester Feedback — Round 1 (2026-05-09) ✅ all addressed

> All bugs, destructive-action safety, client management, pieces/sessions, discounts, and search items from the first tester session shipped in v0.9.x. See git history 2026-05-09 → 2026-05-17 for details; the granular checklist was archived from this file on 2026-06-09 (it was 100% complete — see this file's git history for the itemized list).

---

## Beta Gates (non-data)

### `[v0.8.x]` Legal & version sync ✅ complete

- [x] **Privacy policy finalized & published** — draft banners removed, all `[VERIFY]` tags resolved against confirmed app behavior, effective 2026-05-17. *(`0e47977`; note: published without external lawyer review — revisit if risk profile changes.)*
- [x] **Terms of Service finalized & published** — same treatment; donation-refund clause added (§11). *(`0e47977`)*
- [x] **Reconcile version surfaces** — `MARKETING_VERSION 0.9.0`, `CFBundleVersion 9000`, About screen reads from bundle. *(`b838bf1`)*
- [x] **`CFBundleVersion` scheme** — adopted per `VERSIONING.md` (0.9.0 → build 9000).

### `[v0.9.0]` Distribution & feature minimums

- [x] **Privacy policy + ToS hosted at real public URLs** — `noindex` removed, Legal footer column on all public pages. *(`d371c4a`, `0e47977`)*
- [ ] **TestFlight listing** in App Store Connect. *(Next Up §1.)*
- [x] **Booking notifications (minimum viable)** — evening-before + morning-of local notifications, Settings → Notifications controls. *(2026-05-10)*
- [x] **Client search (minimum viable)** — `SidebarSearchField`; excludes archived/blacklisted, star-to-top sorting. *(2026-05-10)*

---

## App Store Submission Checklist

- [x] Privacy policy URL (hosted, published 2026-05-17)
- [x] Terms of Service URL (hosted, published 2026-05-17)
- [ ] App Store screenshots (12.9" iPad)
- [ ] App description and keywords
- [ ] App icon exported at required sizes *(icon variants were re-exported as solid RGB PNGs for ITMS-90717 in `e9ae4be` — verify the full size matrix during submission)*
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
- [ ] **Donation payment flow** — Decide on web approach: Stripe payment links, Buy Me a Coffee, or remove web buttons and direct to in-app only *(ToS §7 now commits to site-based donations + possible future Patreon — the web flow needs to exist)*
- [ ] **Open Graph & SEO meta tags** — `<meta description>`, OG image/title for link previews
- [ ] **App screenshots on features page** — even 2–3 iPad mockups
- [ ] **Proper favicon** — sized favicons from AppIcon.png (16x16, 32x32, apple-touch-icon)

### `[v1.0]` Lower Priority
- [ ] **Analytics** — note: the published privacy policy currently states "we do not run any analytics scripts on this site"; adding analytics requires a policy update first
- [ ] **Email setup verification** — confirm `mickey@thecounterapp.ca` is receiving mail *(note: the published privacy policy §11 says no third-party email routing — verify the Cloudflare routing claim one way or the other and keep the policy truthful)*

---

## Post-1.0 Features

> Items deferred from the 1.0 critical path. Listed for visibility, not commitment. The version map in `VERSION_HISTORY.md` slots these into 1.1 / 1.2 / 1.3 themes.

### `[v1.1]` Polish & visualization
- [ ] **Calendar view** — Visual calendar (day/week/month) alongside the list-based booking view *(the dormant `.daily` mode in `SchedulingView` is a fragment of this — see Next Up §3)*
- [ ] **Dashboard charts** — earnings-over-time, monthly breakdown, top clients by revenue
- [ ] **Sample data opt-in** — demo data so new users can explore
- [ ] **Guided onboarding walkthrough** — beyond the 3-step setup
- [ ] **Backup retirement decision** — revisit "embed all images" tradeoff; possibly deduplicated/incremental backups *(interacts with the `.cntrdb` co-existence decision in Next Up §2)*
- [ ] **Accessibility audit** — VoiceOver labels, Dynamic Type, contrast
- [ ] **iPad multitasking** — Split View and Slide Over
- [ ] **Haptic feedback** — payment logged, booking confirmed, signature captured

### `[v1.2]` Communication & data portability
- [ ] **SMS templates** — extend the email template system to SMS/iMessage
- [ ] **Automated follow-ups** — healed-photo check-ins after configurable weeks
- [ ] **Data export** — full JSON/CSV *(partially superseded: `.cntrdb` export already provides a complete, inspectable SQLite export)*
- [ ] **Data import** — from spreadsheets for switching artists
- [ ] **Client merge/dedup**
- [ ] **Client import from Contacts**
- [ ] **Gallery sharing** — curated gallery views as link or PDF portfolio
- [ ] **Image compression / storage management** — surface usage, offer cleanup

### `[v1.3]` Multi-device & financial depth
- [ ] **iCloud sync** — *pre-requisite: migration safety (0.9) proven and stable*
- [ ] **Invoice generation** — formal invoice PDFs
- [ ] **Tax summary export** — income by category (CSV or PDF)
- [ ] **Multi-currency support**
- [ ] **Recurring bookings**

---

## Completed (chronological)

- [x] **Version bump to Alpha 0.8** (2026-04-13)
- [x] **Privacy Policy + ToS drafts** + HTML mirrors (2026-04-13)
- [x] **Versioning Strategy** — `docs/internal/VERSIONING.md` (2026-04-13)
- [x] **Version History & Roadmap** — `docs/internal/VERSION_HISTORY.md` (2026-04-14)
- [x] **Schema versioning + recovery launch path** (2026-04-14)
- [x] **Pillar 2 — Backup Hardening** (2026-04-14)
- [x] **Backup `appVersion` reads from `Bundle.main`** (2026-04-14)
- [x] **`CounterSchemaV2` + V1 → V2 lightweight migration** (2026-04-14)
- [x] **Round 1 beta tester feedback** — all bugs, archive/delete safety, starring, blacklist, event tags, discounts, search (2026-05-09 → 05-10)
- [x] **Booking notifications + client search (minimum viable)** (2026-05-10)
- [x] **`.cntrdb` export/import + extracted `SQLiteService`** (`8e05f89`)
- [x] **Archive/Deletion overhaul** (`c2129f6`)
- [x] **Pillar 3 test coverage** — CounterTests target with round-trip, integrity, recovery-mode, backwards-compat tests (2026-05-16, `678af8f`)
- [x] **Version surfaces unified** — 0.9.0 / build 9000 (`b838bf1`)
- [x] **ITMS-90717 icon fix** — solid RGB PNGs (`e9ae4be`)
- [x] **Privacy Policy + ToS finalized and published** — effective 2026-05-17 (`0e47977`)
- [x] **`PieceImage` legacy model removed entirely** (2026-05-17, `e76628d` + `bd4f1ba`)
- [x] **Planning docs synced to repo state** — this file, `BETA_NEXT.md`, cntrdb tasklist, legal markdown mirrors (2026-06-09)
