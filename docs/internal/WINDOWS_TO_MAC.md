---
title: Windows → Mac Hand-off
status: LIVE — update on every PC workspace session
last_updated: 2026-04-14
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
