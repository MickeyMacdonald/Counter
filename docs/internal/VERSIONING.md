---
title: Counter Versioning Strategy
status: PROPOSAL — pending sign-off
last_updated: 2026-04-13
---

# Counter Versioning Strategy

> **Status:** Proposal. This is a starting point — tweak it to fit your actual release cadence and the way you want the app to be perceived. Anything you change here, mirror in `SettingsAboutView.swift` and the README so they don't drift.

## Goals

A versioning strategy for Counter should:

1. **Tell the user where the app is in its life** at a glance — alpha, beta, stable
2. **Tell *you* what kind of changes are safe** at any given point — schema migrations, breaking UI changes, polish only
3. **Map cleanly to App Store / TestFlight** so the marketing version and the build number both make sense to Apple's review process
4. **Survive the migration shim problem** — Counter already has at least two legacy migrations live (`ImageGroup`, `Drafting → initialDrafting`), which is real evidence the schema evolves. Versioning needs to make schema-breaking releases obvious.

## Proposed scheme

**`MAJOR.MINOR.PATCH[-channel]`** — semantic versioning, with an explicit pre-release channel until 1.0.

| Channel | Format | Meaning | Example |
|---|---|---|---|
| Alpha | `0.x.y-alpha` | Internal / dogfood. Schema may change without migration. Features may appear, change, or vanish. | `0.8.0-alpha` |
| Beta | `0.x.y-beta` | TestFlight. Feature-complete for the next 1.0 scope. Schema changes require a migration. Focus is stability. | `0.9.0-beta` |
| Release Candidate | `1.0.0-rc.N` | Bug-fix-only candidates for 1.0. No new features. | `1.0.0-rc.1` |
| Stable | `MAJOR.MINOR.PATCH` | Public App Store. SemVer rules apply. | `1.0.0`, `1.2.3` |

### What each segment means after 1.0

- **MAJOR** bumps when the SwiftData schema changes in a way that requires a migration the user can perceive (data converts, fields move, models split). Or when the UI changes so much that an existing user would need re-onboarding.
- **MINOR** bumps when you add features without breaking existing data or workflows.
- **PATCH** bumps when you fix bugs, polish, or ship security updates.

### Pre-1.0 deviation from strict SemVer

Strict SemVer says anything `0.x` is "no guarantees." Counter is going to be running on real iPads with real client data well before 1.0, so we treat pre-1.0 versions with more discipline than that:

- `0.x` → `0.(x+1)`: may break the SwiftData schema, but **must** ship a migration. There is no "blow away the database" release after Alpha 0.8.
- `0.x.y` → `0.x.(y+1)`: bug-fix and polish only. No schema changes.

In other words: pre-1.0, MINOR is allowed to break things *with migrations*, PATCH is not allowed to break anything.

## Channel transitions

This is where Counter is right now and where it's going:

```
Pre-Alpha (historical)
       │
       ▼
Alpha 0.8.x ← we are here (2026-04-13)
       │
       │ feature work + the 5 beta-gate TODOs
       ▼
Beta 0.9.0  → first TestFlight
       │
       │ feedback, stabilization, no new features
       ▼
1.0.0-rc.N  → release candidates, bug fixes only
       │
       ▼
1.0.0       → public App Store launch
```

### Gates for moving channels

| Transition | Required to ship |
|---|---|
| Alpha → Beta (0.8 → 0.9) | Privacy policy + ToS published, booking notifications, client search, TestFlight listing live, no known data-loss bugs |
| Beta → RC (0.9 → 1.0-rc.1) | One TestFlight cycle with no P0/P1 reports, App Store listing assets ready, all migrations tested with real data |
| RC → Stable (1.0-rc → 1.0.0) | Two consecutive RCs with no new bug reports, Apple review approval in hand |

`[DECIDE: tighten or loosen these gates to taste. They're conservative right now.]`

## Build numbers

Apple wants two numbers in `Info.plist`:

- **`CFBundleShortVersionString`** — the marketing version users see. Use the SemVer string above (drop the `-alpha`/`-beta` suffix because Apple's field is numeric-dotted only — track the channel in the build label and About screen instead).
- **`CFBundleVersion`** — a monotonically increasing build number. Use a **single integer that always increments**, e.g. `812` for the 12th build of the 0.8 line.

### Build number scheme

`{major}{minor}{patch}{counter}` as a flat integer, padded so it sorts:

| Marketing version | CFBundleVersion examples |
|---|---|
| 0.8.0 | 8000, 8001, 8002, … |
| 0.8.1 | 8100, 8101, … |
| 0.9.0 | 9000, 9001, … |
| 1.0.0 | 10000, 10001, … |
| 1.2.3 | 10230, 10231, … |

The counter at the end is per-patch-version. This keeps build numbers strictly increasing (which Apple requires) without needing a database to track them.

`[DECIDE: alternative is just "monotonic build number, ignored by humans" — much simpler, but loses the ability to read the version out of the build number at a glance.]`

## What "Alpha 0.8" means today

As of 2026-04-13 the version is **`0.8.0-alpha`** (`CFBundleShortVersionString: 0.8.0`, `CFBundleVersion: 8000` if/when we adopt this scheme).

Implications:

- The schema is allowed to change between 0.8 and 0.9, but **must** ship a migration.
- The schema is **not** allowed to change between 0.8.0 and 0.8.1 — patch releases are bug-fix and polish only.
- Users on 0.8.x are treated as real users, not throwaways. Their data must survive every release from here on out.
- New features intended for 1.0 should land before 0.9.0-beta. Anything that lands after 0.9.0 ships needs to be labeled "experimental" and protected by a feature flag, or deferred to 1.1.

## In-app surfaces

The version label appears in:

- `Counter/Views/Admin/Settings/SettingsAboutView.swift` — primary user-visible label
- `Info.plist` — `CFBundleShortVersionString` and `CFBundleVersion`
- `README.md` — in any "Status" badge or section once one exists
- `TODO.md` — when noting which version a feature is targeting

These should always agree. A pre-commit hook or a single `version.swift` constant pulled from `Info.plist` would be a good way to keep them in sync. `[DECIDE: worth adding now or wait until 1.0?]`

## Versioning the legacy migrations

Counter's TODO already calls out two cleanup items tied to migration shims:

- `piece.imageGroups` → consolidate to session-based storage
- `Drafting` → `initialDrafting` SessionType migration

Decision rule under this scheme: **shim removals are MAJOR-bumps after 1.0**, but **MINOR-bumps before 1.0** (as long as a migration is shipped). So both of those cleanups can land in 0.9.0-beta if you want, but shouldn't land in 0.8.x.

## Open questions

- [ ] Do you want a separate "Studio Beta" channel after 1.0 for opting real studios into early features?
- [ ] Should `-alpha` and `-beta` builds be distributed via TestFlight only, or also as ad-hoc builds for specific testers?
- [ ] Is there a separate version for the website (`docs/`)? If yes, does it follow the app or go independent?
- [ ] How do you want to communicate breaking releases to users — release notes in the App Store only, or also a "What's new" sheet inside the app?

## Tweak this document

This is a proposal, not a commitment. Edit freely until it matches your vision, then check it in. Once it's checked in, treat it as the contract: any release that violates it should either fail review, or update this document first.
