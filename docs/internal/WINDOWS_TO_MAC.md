---
title: Windows → Mac Hand-off
status: LIVE — update on every PC workspace session
last_updated: 2026-04-14 (V2 schema slice)
---

# Windows → Mac Hand-off

> **What this is:** A running checklist of things that were edited from the Windows workspace and still need to be touched on the Mac before they're real. Counter is an Xcode project — `.swift` files written from PC don't get added to the target, builds don't get verified, and on-device tests don't get run until the next Mac session.
>
> **How to use this:**
>
> 1. **At the end of every PC session:** add a dated entry under "Pending" describing what changed and what the Mac needs to do about it.
> 2. **At the start of every Mac session:** work top-down through "Pending", check items off, and when an entry is fully resolved move it to "Resolved" with the date.
> 3. Keep entries small and concrete — one slice of work per entry, not "miscellaneous tweaks".
>
> If an item has been sitting in "Pending" for more than a couple of sessions, it's a sign it's actually blocked, not just waiting. Promote it to a real `TODO.md` item instead of letting it rot here.

---

## Pending

### 2026-04-14 · CounterSchemaV2 — formalize CustomDiscount

> **Read this first.** This is the first migration that will actually run on a real device with real data. If it goes wrong, the failure mode is "user opens Counter and gets an error" — which is exactly what `RecoveryModeView` was built for, but it's still a moment that needs a careful walk-through. Do NOT install this build over a populated production-ish store until the smoke tests below have passed on a throwaway store.

**Files added from PC (need to be added to the Xcode `Counter` target):**

- `Counter/Services/CounterSchemaV2.swift`

**Files modified from PC (already on disk, no Xcode action needed beyond a build):**

- `Counter/Services/CounterMigrationPlan.swift` — appended `CounterSchemaV2.self` to `schemas` and added a `.lightweight(fromVersion: V1, toVersion: V2)` stage. Long comment at the top of the file explains why this stage does NOT use the willMigrate auto-backup hook (additive-only, no transformation, no half-migrated state possible) and includes a commented template for the next stage that absolutely WILL need it.
- `Counter/App/CounterApp.swift` — `Schema(versionedSchema: CounterSchemaV1.self)` → `Schema(versionedSchema: CounterSchemaV2.self)`. The migration plan is unchanged from the previous slice; SwiftData walks the stages array to get from whatever's on disk up to V2.
- `Counter/Models/RecoveryBackup.swift` — added `CustomDiscountBackup` struct and an **optional** `customDiscounts: [CustomDiscountBackup]?` field on `RecoveryBackup`. Optional is load-bearing: pre-V2 backup files don't have this field at all, and bumping `RecoveryBackup.currentVersion` would break their decode (forward migration of backups is still a pillar 1 task).
- `Counter/Services/RecoveryService.swift` — `serializeAllModels` now fetches `CustomDiscount` records and emits a `cdBackups` array; the `RecoveryBackup` constructor passes them through; `deserializeAndInsert` has a new loop that treats `nil` as `[]` (legacy backup) and inserts each discount; `wipeAllData` deletes `CustomDiscount.self` last; `totalModelCount` includes `customDiscounts?.count ?? 0`.

**Important context on what was happening before V2:**

`SettingsViewFinancial.swift:101` was already inserting `CustomDiscount` records via `modelContext.insert(...)` and querying them via `@Query(sort: \CustomDiscount.sortOrder)`. Pre-V2, `CustomDiscount` was NOT in the schema. The exact behavior of SwiftData when you `insert` an unregistered `@Model` is undefined — it may have been silently ephemeral, may have crashed in a way the user never reported, or may have been quietly persisted to a side-table. **Whatever the previous behavior was, V2 makes it official.** If a user had any custom discounts that were somehow persisted under V1, they'll either show up in V2 untouched (if SwiftData was persisting them all along) or appear gone (if they were ephemeral). There's no clean way to recover from the latter case from the PC side; the user can re-create them in Settings → Financial. Worth mentioning if any beta tester reports "my discounts are gone" — that's the diagnosis.

**Mac-side actions, in order:**

- [ ] **Add `Counter/Services/CounterSchemaV2.swift` to the `Counter` target** in Xcode. The migration files live alongside the other services now (no separate `Migrations/` group) — drag it into the `Services` group and confirm the `Counter` target checkbox is on.
- [ ] **Build.** Friction points to watch for:
  - `CounterSchemaV2.models` lists 19 entries. Compare against `CounterSchemaV1.models` — they should be identical except for `CustomDiscount.self` at the end. If they've drifted (e.g. someone added another model since), V2 must include the drift too, otherwise the migration loses data on the new entity.
  - `CustomDiscount`'s init has all-defaulted parameters. The `deserializeAndInsert` call uses named args (`name:percentage:sortOrder:`) which match the init signature exactly — should compile clean.
  - `RecoveryBackup` constructor in `RecoveryService.swift:performBackupInternal` now passes `customDiscounts: cdBackups` as a named arg — make sure the trailing comma placement didn't get mangled by my edit.
- [ ] **Smoke test #1 — fresh install, V2 from scratch.** Wipe the simulator/device, install the build, walk through onboarding, create a custom discount in Settings → Financial. Take a manual backup. Inspect `Counter Recovery/counter_recovery_*/backup.json` and confirm there's a `customDiscounts` array with one entry. This proves the V2-native happy path.
- [ ] **Smoke test #2 — upgrade from V1.** This is the load-bearing test. Steps:
  1. Check out the previous build (the one with `Schema(versionedSchema: CounterSchemaV1.self)` in `CounterApp.swift`), build, install, populate with seed data + a few real records.
  2. Without wiping, install the new V2 build over top.
  3. Launch. Confirm the app opens cleanly (does NOT route to Recovery Mode).
  4. Confirm all V1 data is intact: clients, pieces, sessions, photos, settings.
  5. Go to Settings → Financial → Custom Discounts. The list should be empty (or whatever was there pre-V2 if SwiftData was somehow persisting them — see context above). Add a new discount.
  6. Take a manual backup. Confirm the resulting `backup.json` has a `customDiscounts` array including the new entry.
- [ ] **Smoke test #3 — restore a pre-V2 backup on a V2-running build.** This proves the optional `customDiscounts` field is doing its job:
  1. Find a `backup.json` from before this slice (any backup taken on the previous build), or just delete the `customDiscounts` line from a fresh backup with a text editor and re-zip it.
  2. Restore from it via Settings → Recovery.
  3. Confirm the restore completes cleanly. The restored store should have zero custom discounts (because the pre-V2 backup couldn't carry them) and everything else intact.
- [ ] **Smoke test #4 — round-trip a backup with discounts.** Take a backup with discounts present, restore from it, confirm the discounts come back exactly. This proves the serialize → deserialize loop is symmetric.
- [ ] **Tag the build.** `git tag v0.8.3` (or whatever the next patch is) once #1–#4 all pass. **Do NOT tag if any smoke test fails — V2 staying tagged means the migration boundary is permanent.** A failed migration that ships becomes a permanent stain on the version chain because reversing it requires another migration.

**If smoke test #2 fails** (the upgrade-from-V1 case is the one most likely to surprise):

- The expected error path is "ModelContainer init throws" → `CounterApp.swift` catches and routes to `RecoveryModeView`. This is the **good** failure mode — the user can see backups and reset.
- The unexpected error path is "ModelContainer init succeeds but data is missing or corrupt." This would mean SwiftData accepted the schema but the migration mangled something. If you see this, **do not ship**. Roll back `CounterApp.swift` to use `CounterSchemaV1.self`, file the symptoms in this file under a new "Blocked" section, and we'll reassess from the PC side.
- The previous-build's last automatic backup is the user's safety net. It's a V1 backup, so it has no `customDiscounts` field, but it can be restored on the V2 build (smoke test #3 proves this).

---

### 2026-04-14 · Pillar 2 — Backup Hardening

**Files modified from PC (no Xcode target work needed — all already in target):**

- `Counter/Models/RecoveryBackup.swift` — added `BackupKind` enum, optional `jsonChecksum` and `kind` fields on `BackupMetadata` (with `effectiveKind` shim for legacy decoding), and four new `RecoveryError` cases: `.checksumMismatch`, `.refuseEmptyRestore`, `.imageCountMismatch`, `.preRestoreSnapshotFailed`.
- `Counter/Services/RecoveryService.swift` — added `import CryptoKit`, `Self.currentAppVersion` (reads `CFBundleShortVersionString` + `CFBundleVersion`), `Self.sha256Hex(_:)`, refactored `performBackup` into a thin wrapper around `performBackupInternal(context:kind:folderPrefix:)`, added `performPreRestoreSnapshot(context:)`, rewrote `restore(from:context:)` with checksum verification → empty-record guard → pre-flight image existence check → pre-restore snapshot → wipe/insert → image restore + post-copy count verification, added `expectedCount:` parameter to `restoreImages`, added `recursiveFileCount(at:)`, added `prunePreRestoreSnapshots()`, made `pruneOldBackups()` and `pruneLocalMirror()` kind-aware, added `includeImages:` parameter to `mirrorToLocalDocuments` (now defaults true), and replaced the `"Pre-Alpha 0.2"` literal in `serializeAllModels` with `RecoveryService.currentAppVersion`.
- `Counter/Views/Admin/Settings/SettingsViewRecovery.swift` — split the single backup list into two sections (`Available Backups` for user backups, `Safety Snapshots` for pre-restore snapshots), extracted a shared `backupRow(_:)` helper, updated the footer text to mention the dual retention budget.

**Mac-side actions, in order:**

- [ ] **Build.** No new files this slice — everything's an edit to files already in the target. Friction points to watch for:
  - `import CryptoKit` is iOS 13+, so the deployment target is fine, but if the project has an unusually low minimum it'll surface here.
  - The `BackupMetadata` initializer in `RecoveryService.swift:131` now passes `jsonChecksum:` and `kind:` as named arguments. Old metadata files on disk (without those fields) will decode fine because both are `Optional`, but if you wrote any test fixtures with explicit `BackupMetadata(...)` literals, they'll need the new args added.
  - `Self.currentAppVersion` is a static on the actor — accessed from inside `@MainActor private func serializeAllModels` via `RecoveryService.currentAppVersion`. Should be fine because it only reads `Bundle.main.infoDictionary` (no actor isolation needed), but if Swift complains about the cross-isolation read, change it to a free function or a top-level `let`.
- [ ] **Smoke test the happy path on the iPad:**
  - Run "Back Up Now" in Settings → Recovery. Confirm it succeeds, the new backup appears in "Available Backups", and the on-disk `metadata.json` includes a `jsonChecksum` field and `"kind": "userBackup"`.
  - Tap "Restore" on that backup. Confirm: (a) a *second* entry appears in a new "Safety Snapshots" section labeled with the moment-of-restore time, (b) the restore completes successfully, (c) the snapshot's metadata file has `"kind": "preRestoreSnapshot"`.
  - Restore from the snapshot. Confirm you get back to where you were before the previous restore, and yet another snapshot lands in the Safety Snapshots section.
- [ ] **Smoke test the new failure paths:**
  - **Checksum mismatch:** open a backup's `backup.json` in a hex editor and flip a single byte. Tap restore — should fail with the checksum error and **leave the live store untouched** (no pre-restore snapshot, no wipe).
  - **Empty restore guard:** the only way to get here is to hand-craft a backup whose JSON has all-empty arrays. Easier path: just trust the unit test once 0.9.0 test coverage lands. Optional smoke test for this slice.
  - **Image count mismatch:** delete a single file from a backup's `Images/` subfolder, then restore. Should fail with the image-count error AFTER the wipe — meaning the user has to roll back via the auto-snapshot. This is the path that proves the snapshot is load-bearing, so it's the most important one to hit at least once.
- [ ] **Verify the local-Documents mirror now contains images.** Inspect `Documents/Counter Recovery/counter_recovery_*/Images/` via the Files app on the iPad. Pre-existing mirrors won't have it; new backups taken after this build should.
- [ ] **Tag the build.** `git tag v0.8.2` (or whatever the next patch is) once the smoke tests pass.

**Footguns to watch for during testing — these are not bugs, they're known limitations of this slice:**

- Pre-restore snapshots take the **current** state. If the user's current state is already corrupt (e.g. half-wiped from a previous failed restore), the snapshot captures that corruption. The user is no worse off than before, but the snapshot isn't magic.
- The pre-restore snapshot bypasses the 60s debounce on `performBackup`. It does NOT bypass any other error path — if `serializeAllModels` itself throws, the snapshot fails and `restore()` throws `preRestoreSnapshotFailed` and refuses to proceed. That's the intended behavior, but it does mean a sufficiently broken store could become un-restorable. Recovery Mode (the launch path from the previous slice) is the answer for that case.
- `RecoveryModeView` (the failed-launch screen) lists ALL backups including snapshots — by design, since in a recovery context any restore point is valuable. If the mixing turns out to be confusing in practice, split it the same way `SettingsViewRecovery` does.

---

### 2026-04-14 · Schema versioning + Recovery Mode launch path

**Files added from PC (need to be added to the Xcode `Counter` target):**

- `Counter/Services/CounterSchemaV1.swift`
- `Counter/Services/CounterMigrationPlan.swift`
- `Counter/App/RecoveryModeView.swift`

> **Path note:** the V1 schema and migration plan originally lived in `Counter/Migrations/` and have since moved to `Counter/Services/` (PC-side rename via `git mv`). On the Mac, drag them into the existing `Services` Xcode group — there is no longer a separate `Migrations` group.

**Files modified from PC (already on disk, no Xcode action needed beyond a build):**

- `Counter/App/CounterApp.swift` — replaced `fatalError` with a `LaunchState` enum that routes to `RecoveryModeView` on `ModelContainer` failure. Now uses `Schema(versionedSchema: CounterSchemaV1.self)` and passes `migrationPlan: CounterMigrationPlan.self`.

**Mac-side actions, in order:**

- [ ] **Add the three new files to the `Counter` target.** In Xcode: right-click the `Services` group → "Add Files to Counter…" → select `CounterSchemaV1.swift` and `CounterMigrationPlan.swift` → confirm the `Counter` target checkbox is on. Repeat for `RecoveryModeView.swift` under the `App` group.
- [ ] **Build.** Most likely friction points:
  - `Schema(versionedSchema:)` is iOS 17+. Confirm the deployment target is fine.
  - `RecoveryService.shared.listBackups()` is `async throws` — the `.task` modifier in `RecoveryModeView` handles that. If the signature has drifted, fix the call site.
  - The `.modelContainer(container)` modifier moved from being attached to the `WindowGroup` to being attached to `ContentView` inside the `switch`. Functionally equivalent, but if anything in `ContentView` was reaching for `@Environment(\.modelContext)` from outside that subtree it would break.
- [ ] **Force-trigger Recovery Mode at least once on the iPad.** On a throwaway branch, throw unconditionally inside `CounterApp.init` (e.g. `throw NSError(domain: "test", code: 1)` after the container init), run on device, and verify:
  - `RecoveryModeView` renders without crashing
  - The backups list populates from `RecoveryService.shared.listBackups()` (assuming there's at least one backup on the device)
  - The "Technical details" disclosure shows the thrown error and the text is selectable / copyable
  - The "Reset Counter's data store" alert appears, the destructive action runs, and a relaunch produces a fresh empty store
  - Revert the throw before merging
- [ ] **Tag the build.** Once it boots clean and the recovery path has been triggered once, `git tag v0.8.1` (or whatever the next patch is) so the next reconstruction in `VERSION_HISTORY.md` doesn't have to guess.

**Footguns deliberately deferred to 0.9.0 — do NOT fix in this slice:**

- `CustomDiscount` is missing from the schema. Adding it to V1 *is itself* a schema change and must land as the first `V1 → V2` migration stage, not as a silent edit to V1.
- `RecoveryService.swift:64` still hardcodes `appVersion: "Pre-Alpha 0.2"` on every backup it writes. Cosmetic now, load-bearing once forward migration of backups is real.

---

## Resolved

> Move entries here when every checkbox under them is ticked. Keep the original date so the log stays honest.

*(empty — first entry will land here once the 2026-04-14 slice has been built and force-triggered on a real iPad)*
