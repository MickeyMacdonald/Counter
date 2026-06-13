# Beta Launch — Next Steps
_Last updated: 2026-06-09_

> Fuller consolidated list lives in [`TODO.md`](TODO.md) → "⭐ Next Up". This file is just the launch-critical slice.

## Unblocked right now

- [ ] **Run test suite** — open project in Xcode, pick any iPad simulator, hit `⌘U`. Fix any compile errors that surface (type names, enum cases).
- [ ] **Archive & upload to TestFlight** — `Any iPad Device (arm64)` → Product → Archive → Distribute App → TestFlight & App Store.
- [ ] **App Store Connect** — confirm app record exists for `com.counterprealpha.app`; add the published Privacy Policy / ToS URLs to the listing; add internal testers once build processes.
- [ ] **App Store assets** — 12.9" screenshots, description, keywords, age rating.

## Done since last update (2026-05-17)

- [x] Privacy Policy + Terms of Service finalized and **published** — effective 2026-05-17, all `[VERIFY]`/`[DECIDE]` tags resolved, `noindex` removed, Legal footer on all public pages (`0e47977`, `d371c4a`). *Resolved without external lawyer review.*
- [x] `PieceImage` legacy model removed entirely (`e76628d`).
- [x] `.cntrdb` SQLite export/import shipped (`8e05f89`) — **but untested; see TODO.md Next Up §2 before promoting it to testers.**

## Website / infrastructure

- [ ] Custom domain — point `thecounterapp.ca` (Cloudflare) at GitHub Pages
- [ ] Activate contact form — one-time FormSubmit.co email confirmation from `mickey@thecounterapp.ca`
- [ ] Replace placeholder App Store download buttons (currently fire JS alerts)

## Low-urgency code items

- [ ] `Drafting → initialDrafting` shim → formal `MigrationStage.custom` (safe to defer to pre-1.0; shim handles all reads)
- [ ] `SchedulingView` daily-mode TODOs — repair the exhaustive switch or delete the dead code
