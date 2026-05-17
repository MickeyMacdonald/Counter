# Beta Launch — Next Steps
_Last updated: 2026-05-16_

## Unblocked right now

- [ ] **Run test suite** — open project in Xcode, pick any iPad simulator, hit `⌘U`. Fix any compile errors that surface (type names, enum cases).
- [ ] **Archive & upload to TestFlight** — when back at iPad/Mac setup: `Any iPad Device (arm64)` → Product → Archive → Distribute App → TestFlight & App Store.
- [ ] **App Store Connect** — confirm app record exists for `com.counterprealpha.app`; add internal testers once build processes.

## Needs a lawyer (external dependency)

- [ ] Privacy policy review — resolve every `[VERIFY]` tag in `docs/legal/privacy-policy.md`
- [ ] Terms of Service review — resolve every `[VERIFY]` and `[DECIDE]` tag in `docs/legal/terms-of-service.md`

## After legal docs are approved

- [ ] Host privacy policy + ToS at public URLs (remove `noindex` from `docs/privacy.html` / `docs/terms.html`)
- [ ] Add URLs to App Store Connect listing (required for external TestFlight)

## Website / infrastructure

- [ ] Custom domain — point `thecounterapp.ca` (Cloudflare) at GitHub Pages
- [ ] Activate contact form — one-time FormSubmit.co email confirmation from `mickey@thecounterapp.ca`
- [ ] Replace placeholder App Store download buttons (currently fire JS alerts)

## Low-urgency code item

- [ ] `Drafting → initialDrafting` shim → formal `MigrationStage.custom` (safe to defer to pre-1.0; shim handles all reads)
