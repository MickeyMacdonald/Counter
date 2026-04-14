---
title: Windows → Mac Hand-off
status: LIVE — update on every PC workspace session
last_updated: 2026-04-14 (pillar 2 slice)
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

- `Counter/Migrations/CounterSchemaV1.swift`
- `Counter/Migrations/CounterMigrationPlan.swift`
- `Counter/App/RecoveryModeView.swift`

**Files modified from PC (already on disk, no Xcode action needed beyond a build):**

- `Counter/App/CounterApp.swift` — replaced `fatalError` with a `LaunchState` enum that routes to `RecoveryModeView` on `ModelContainer` failure. Now uses `Schema(versionedSchema: CounterSchemaV1.self)` and passes `migrationPlan: CounterMigrationPlan.self`.

**Mac-side actions, in order:**

- [ ] **Add the three new files to the `Counter` target.** In Xcode: right-click the `Counter` group → "Add Files to Counter…" → select the three files above → confirm the `Counter` target checkbox is on. The `Migrations/` folder needs to exist as a real Xcode group (not just a folder reference) so future migration files land in the right place.
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
