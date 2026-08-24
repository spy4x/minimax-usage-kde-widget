# Changelog

All notable changes to this plasmoid are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] — 2026-08-24

### Added
- Layout orientation config (horizontal / vertical) for narrow panels.
- Vertical layout stacks the two quota cards (5h + weekly) top-to-bottom.

### Changed
- Default widget size bumped from 640×420 to 960×630 (1.5×).
- Minimum size bumped from 520×340 to 780×510.

## [1.1.3] — 2026-08-24

### Fixed
- Widget appeared as a small square on first add because `PlasmoidItem`
  had no `implicitWidth`/`implicitHeight`. Set both to match
  `X-Plasma-DefaultSize` so Plasma can size it and render the
  Add Widgets preview.

## [1.1.2] — 2026-08-24

### Changed
- Both concentric rings now fill in the same direction (consumption view).
  Outer ring switched from time-remaining to time-elapsed so the two
  rings are visually consistent.
- Center text hierarchy swap: `"% left"` is now the big number on top,
  countdown ("reset 21m") is the small monospace below.

## [1.1.1] — 2026-08-24

### Added
- Outer time-remaining ring on each card (concentric with the
  quota-used ring). Allows visual comparison of utilization rate.

## [1.1.0] — 2026-08-24

### Changed
- **Major visual redesign.** Stacked linear progress bars replaced
  by two side-by-side cards with circular progress rings, dark navy
  palette, header clock, footer live indicator.
- `QuotaBar.qml` replaced by `QuotaCard.qml`.
- `CompactRepresentation.qml` updated to match the new palette.

### Added
- Live-ticking countdown (subtracts elapsed since fetch each second).
- Header clock updates every second (HH:MM:SS).
- Default + minimum size bumped to 640×420 / 520×340.

## [1.0.6] — 2026-08-24

### Changed
- Default size 420×220 → 480×300; minimum 280×140 → 380×220.
  Content was overflowing the old defaults on first placement.

## [1.0.5] — 2026-08-24

### Changed
- Polish pass on layout, colors, and bar styles. Card border darker
  for visibility on any wallpaper. Removed `KPlugin.Icon` to avoid
  title overlap when the containment shows the applet icon.

## [1.0.4] — 2026-08-24

### Fixed
- Config dialog showed only Keyboard Shortcuts + About (no General tab).
  Restructured to Plasma 6 pattern: `contents/config/config.qml`
  (ConfigModel + ConfigCategory) + `contents/ui/ConfigGeneral.qml`
  (KCM.SimpleKCM root). Updated `X-Plasma-Config` to point at
  `config/config.qml`.
- `theme is not defined` errors in `main.qml` and `QuotaBar.qml`.
  Plasma 6 no longer provides `theme` as a context global; switched
  to `PlasmaCore.Theme.<name>` after `import org.kde.plasma.core as
  PlasmaCore`.

## [1.0.3] — 2026-08-24

### Fixed
- Config dialog root must be `KCM.SimpleKCM` (from
  `org.kde.kcmutils`) per the Plasma 6 porting guide. Plain `Item`
  root was silently ignored.
- Bars rendered `"Used 100%"` / red on no-data because QML coerces
  `null` → `0` on `real` properties. Switched QuotaBar to `var`
  type with explicit `hasData` / `usedPercent` readonly properties;
  display now shows `"—"` on no-data.

## [1.0.2] — 2026-08-24

### Fixed
- `PlasmoidItem` import + root type. Plasma 6 requires the root of the
  full representation QML to be `PlasmoidItem`, not plain `Item`.

## [1.0.1] — 2026-08-24

### Fixed
- `X-Plasma-API-MinimumVersion` was misspelled. Plasma 6 expects
  `X-Plasma-API-Minimum-Version` (hyphenated). Dropped the unused
  `X-Plasma-API` field; system applets only declare the minimum.

## [1.0.0] — 2026-08-24

### Added
- Initial release.
- 5h + weekly quota bars with reset countdowns.
- Color thresholds: green / orange / red based on usage.
- CompactRepresentation for panel use.
- Configuration dialog (API key, refresh interval, endpoint).
- Node smoke-test (9/9 passing).
