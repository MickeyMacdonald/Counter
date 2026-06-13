# Session handoff — App icons (Jun 2026)

## What shipped (latest commit on `main`)

Custom user-created app icons were **removed**. Settings → App Icon is now a simple picker for **developer-built alternates only**:

| Icon | Plist key | Asset set |
|------|-----------|-----------|
| Classic (primary) | — | `CounterAppIcon` |
| Ukraine | `Ukraine` | `CounterAppIconUkraine` |
| Holiday | `Xmas` | `CounterAppIconXmas` |
| Pride | `Pride` | `CounterAppIconPride` |

**Pride** is new this session: assets in `CounterAppIconPride.appiconset` + `AppIconThumbPride`, registered in `Counter/App/AppIconInfo.plist` and `BuiltInAppIcon.catalog`.

## What was removed

- `AppIconEditorView`, `AppIconRenderer`, custom slot assets (`CounterAppIconCustom01`–`08`)
- `AppLogoMark` imageset, IconSlotSync build script, custom icon persistence
- Custom01–08 entries from `AppIconInfo.plist`

## Key files

- `Counter/Models/Configuration/AppIconModels.swift` — `BuiltInAppIcon.catalog`
- `Counter/Services/AppIcon/AppIconStore.swift` — apply + UserDefaults selection (`app.selectedIcon.v2`)
- `Counter/Views/Admin/Settings/SettingsAppIconView.swift` — icon grid UI
- `Counter/App/AppIconInfo.plist` — alternate icon registration (merged with generated Info.plist)

## iOS constraint (decided this session)

Users **cannot** change the Home Screen icon to arbitrary runtime-generated PNGs without a new app build. Custom icon creation was dropped for this reason.

## Adding a new built-in alternate

1. Add `CounterAppIcon{Name}.appiconset` + thumb imageset to `Assets.xcassets`
2. Register in `AppIconInfo.plist` (iPhone + iPad `CFBundleAlternateIcons`)
3. Add entry to `BuiltInAppIcon.catalog`

## Uncommitted / out of scope

- `SettingsAboutView`: label rename Channel → Stage (not in app-icon commit)
- Root design files (`LogoDesign.png`, `.af` sources) — local only, not tracked

## Recent history on `main`

- `2eba053` — added custom icon editor (since reverted)
- `faf600e` — primary icon composer asset update
- Latest — custom icon regression + Pride
