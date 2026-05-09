---
title: Tasklist — `.cntrdb` SQLite Format & Photo Management Overhaul
status: PROPOSED
last_updated: 2026-05-09
---

# Tasklist — `.cntrdb` SQLite Format & Photo Management Overhaul

> **Status:** Scoping document. Two related tracks: (1) introduce a SQLite-backed `.cntrdb` package format as a richer replacement/companion to the current JSON backup pipeline, and (2) overhaul the photo management subsystem so image records reference the same canonical schema, making the photo layer easier to reason about and migrate.

---

## Background

Counter currently persists data via **SwiftData** (SQLite under the hood, but the schema is private to SwiftData) and exports/restores via a **JSON + image-folder bundle** managed by `RecoveryService`. The JSON format is human-readable but verbose, has no foreign keys, requires a manual relinking phase on restore, and offers no read-only inspection from external tools.

The proposal: introduce a **public, app-owned SQLite schema** delivered as a `.cntrdb` package (folder) — usable for backups, transfers between devices, archival, and (eventually) the canonical reference for photo metadata.

---

## Track 1 — `.cntrdb` SQLite Format

### Goals

1. Define a stable, versioned **public schema** independent of SwiftData's internal one.
2. Ship a package format `MyBackup.cntrdb/` containing `database.sqlite`, `Images/`, `manifest.json`.
3. Provide first-class export and import flows in Settings/Recovery, alongside (not replacing) JSON backups during the alpha/beta period.
4. Open the door to inter-app portability and external inspection (DB Browser for SQLite, etc.).

### Non-goals (for v1)

- Live-write to SQLite at runtime (SwiftData remains the runtime store).
- Replacing the JSON `RecoveryService` outright — both formats co-exist until `.cntrdb` is proven.
- Embedding image BLOBs inside the SQLite file (images stay as files in the package).

### Phase 1.0 — Schema design & dependency choice

- [x] Decide on SQLite library: **raw `sqlite3` C API** chosen. Trade-off: more boilerplate (~200 lines of wrapper) vs. zero external dependencies, no SwiftPM additions to the `.pbxproj`, no binary-size cost. The export/import path is one-shot (not a runtime DB), so the boilerplate is bounded and maintenance is local. GRDB remains an option for v2 if querying inside `.cntrdb` from app code becomes a real workflow.
- [ ] Draft the public schema DDL covering all current models (see *Schema Coverage* below). Stable column names, snake_case, UUID primary keys, ISO8601 timestamps.
- [ ] Add `_meta` table: `schema_version INTEGER`, `app_version TEXT`, `exported_at TEXT`, `source_device TEXT`, `notes TEXT`.
- [ ] Define foreign-key constraints with `ON DELETE` semantics that match SwiftData cascade rules.
- [ ] Write the schema as a single canonical SQL file checked into the repo (`Counter/Services/Cntrdb/Schema/v1.sql` or similar).
- [ ] Add a unit test that asserts the DDL applies cleanly to an empty SQLite database.

### Phase 1.1 — Package format & UTType

- [ ] Register `com.counter.cntrdb` UTType in `Info.plist` with `LSItemContentTypes` declaring it as a package (folder bundle) conforming to `public.composite-content`.
- [ ] Define `manifest.json` schema: format version, schema version, app version, created at, model counts, image counts, json/db sizes, SHA-256 checksum of `database.sqlite`.
- [ ] Decide whether the package is the bare folder or a zipped `.cntrdb` (recommend bare folder for iOS, with optional `.cntrdb.zip` for AirDrop/email).
- [ ] Confirm Files.app and the share sheet treat the package opaquely on iOS 17/18.

### Phase 1.2 — Exporter

- [ ] `CntrdbExporter` actor mirroring the structure of `RecoveryService`'s backup pipeline.
- [ ] Per-model export functions reading from `ModelContext` and inserting into a fresh SQLite db.
- [ ] Image copy step (re-use the logic from `RecoveryService` — copies `Documents/CounterImages/` into `Images/` inside the package).
- [ ] Compute and write `manifest.json` with checksums.
- [ ] Wire into Settings → Recovery view alongside the existing JSON backup button.

### Phase 1.3 — Importer

- [ ] `CntrdbImporter` actor mirroring `RecoveryService`'s restore phases.
- [ ] Preflight checks: schema version compatibility, manifest checksum, image folder presence, image count match, empty-import refusal.
- [ ] Auto-snapshot the current state to a pre-restore JSON backup before applying.
- [ ] Phased insert respecting referential ordering (independent → clients → pieces → sessions → progress → images → agreements/logs → payments → bookings).
- [ ] Image copy-in step.
- [ ] Wire into Settings → Recovery view with `.fileImporter` and explicit confirmation alert.

### Phase 1.4 — Schema coverage checklist

The schema must cover every `@Model` currently shipped. Track each one:

**Core**
- [ ] `clients`
- [ ] `pieces`
- [ ] `sessions`
- [ ] `bookings`
- [ ] `booking_task_templates`

**Configuration**
- [ ] `user_profiles`
- [ ] `agreements`
- [ ] `email_templates`

**Financial**
- [ ] `payments`
- [ ] `discounts`
- [ ] `flash_price_tiers`

**Gallery**
- [ ] `work_images`
- [ ] `session_progress`
- [ ] `piece_images` *(legacy — include for round-trip but mark deprecated)*
- [ ] `gallery_groups`

**Scheduling**
- [ ] `availability_slots`
- [ ] `availability_overrides`
- [ ] `session_categories`
- [ ] `session_rate_configs`

**Communication**
- [ ] `communication_logs`

**Meta**
- [ ] `_meta`
- [ ] `_user_defaults` *(key/value snapshot of relevant `UserDefaults` keys, mirroring current JSON behavior)*

### Phase 1.5 — Versioning & migration policy

- [ ] Document policy: `_meta.schema_version` increments on any breaking change. Importer must refuse newer versions, may attempt migration of older versions.
- [ ] Establish a migration step pattern (one SQL file per version transition).
- [ ] Add a `Counter/Services/Cntrdb/Migrations/` directory with a README.

### Phase 1.6 — Tests & verification

- [ ] Round-trip test: seed → export `.cntrdb` → wipe → import → assert model counts and key field equality.
- [ ] Image integrity test: every `work_images.file_path` resolves to a file in `Images/`.
- [ ] Foreign-key integrity test: no orphaned rows after export.
- [ ] Manifest checksum test: tampering with `database.sqlite` makes import refuse.
- [ ] Performance smoke test on a realistic dataset (e.g. 200 clients, 1000 pieces, 10k images).

---

## Track 2 — Photo Management Overhaul

> **Depends on:** Track 1 phases 1.0 and 1.4 — the public SQLite schema becomes the *reference model* for photo metadata. Even though SwiftData is still the runtime store, the `.cntrdb` schema disambiguates what a "photo record" canonically is, which is a good forcing function for cleaning up the runtime layer.

### Why now

Today there are three overlapping image models — `WorkImage`, `PieceImage` (legacy), and the per-stage `SessionProgress` images — plus an `ImageStorageService` that mostly handles paths and a `PhotoImportService` that handles ingest. Behavior is correct but the surface area is wide:

- Two active model types (`WorkImage`, `PieceImage`) with overlapping fields.
- Categorization split across `category`, `healingStage`, `source`, `isPortfolio`, `isPrimary`.
- File path management is implicit — relative paths into `Documents/CounterImages/` with no central registry.
- No deduplication, no thumbnail cache, no orphan detection.

### Goals

1. Single canonical photo record type (`WorkImage`) with `PieceImage` retired post-migration.
2. A photo registry service that owns the file system layout and exposes typed queries (by client, by piece, by stage, by category).
3. Thumbnail cache with explicit invalidation hooks.
4. Orphan detection (files on disk with no DB row, or rows pointing at missing files) surfaced in Recovery view.
5. The runtime model maps 1:1 to the `.cntrdb` `work_images` table — same field names where reasonable, same semantics.

### Phase 2.0 — Audit & alignment

- [ ] Inventory every read/write site touching `WorkImage`, `PieceImage`, `SessionProgress.images`. Map to current call sites.
- [ ] Compare current SwiftData model fields to the proposed `.cntrdb` `work_images` schema. Resolve drift before locking the schema in Track 1.
- [ ] Decide final fate of `PieceImage`: migration shim only, or full removal post-v1.0?

### Phase 2.1 — Photo registry service

- [ ] New `PhotoRegistry` actor that owns `Documents/CounterImages/` layout.
- [ ] Methods: `register(_:from:)`, `unregister(_:)`, `resolve(path:)`, `enumerate(forClient:)`, `enumerate(forPiece:)`.
- [ ] Replace direct `FileManager` calls scattered across views with registry calls.
- [ ] Registry writes mirror to a `_photo_index` runtime cache that matches the `work_images` shape.

### Phase 2.2 — Thumbnail cache

- [ ] `ThumbnailCache` keyed by `WorkImage.id` + size class (small/medium/large).
- [ ] On-disk under `Caches/Thumbnails/` (excluded from backup — derivable).
- [ ] Generated lazily; invalidated when source `WorkImage` updates.
- [ ] Hooks for `GalleryImageCell` and `FullScreenImageViewer` to use the cache.

### Phase 2.3 — Orphan detection & repair

- [ ] Sweep that compares `WorkImage` rows to disk:
  - Rows without files → flag for user (offer "remove broken record" or "locate file").
  - Files without rows → flag for user (offer "import as orphan" or "delete").
- [ ] Surface results in Recovery view as a counter ("3 broken photo records, 12 orphaned files").
- [ ] Reuse the same sweep during `.cntrdb` import preflight.

### Phase 2.4 — Schema convergence

- [ ] After the registry lands, ensure the runtime `WorkImage` field set is exactly the union of what the registry needs and what the `work_images` `.cntrdb` table stores.
- [ ] Bump `.cntrdb` schema version if anything changes; update migration.
- [ ] Document the mapping in `docs/internal/PHOTO_MODEL.md` (new file once this phase completes).

### Phase 2.5 — Tests

- [ ] Photo registry unit tests (register, unregister, enumerate, resolve).
- [ ] Thumbnail cache invalidation test.
- [ ] Orphan sweep test on a synthetic broken state.
- [ ] Round-trip test: photo → `.cntrdb` export → import → verify file is on disk and registry entry exists.

---

## Open questions

- [ ] **Co-existence vs replacement:** Does `.cntrdb` eventually replace JSON backups, or stay alongside as the "professional" format while JSON remains the safety net? Decide before v1.0.
- [ ] **Cross-platform:** Is there a plausible macOS or web companion that would consume `.cntrdb`? If yes, the schema should be even more conservative about iOS-specific types.
- [ ] **Encryption:** Should `.cntrdb` support optional passphrase encryption (SQLCipher) given client PII? Defer past v1, but design the manifest to allow signaling encryption later.
- [ ] **Streaming export:** For very large datasets, does the exporter need to stream rather than load everything into memory? Likely fine at current scale; revisit at 10k+ pieces.

---

## Risks

- **Schema drift:** the public schema and the SwiftData schema diverging silently. Mitigation: round-trip test in CI; the photo overhaul forcing alignment for at least the image table.
- **Importer regressions:** import is destructive. Mitigation: pre-restore JSON snapshot, same as `RecoveryService` does today.
- **GRDB dependency:** adds ~2 MB to the binary. Mitigation: gate behind a feature flag during alpha; evaluate raw `sqlite3` if size becomes a concern.

---

## Suggested order of attack

1. Track 1 Phase 1.0 — lock the schema and library choice.
2. Track 2 Phase 2.0 — audit photo models against the schema; resolve drift now while the schema is still soft.
3. Track 1 Phases 1.1–1.3 — build exporter/importer end-to-end.
4. Track 1 Phase 1.6 — tests and round-trip.
5. Track 2 Phases 2.1–2.5 — photo overhaul once `.cntrdb` is the stable source of truth for image metadata.
