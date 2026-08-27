# Changelog

All notable changes to this plasmoid are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.5.6] — 2026-08-27

### Fixed
- **Stats charts: bars collapsed to width=0 on data refresh** —
  `barWidth` was a `readonly property` with a function body. QML
  evaluates Repeater delegate bindings lazily; when `dsPoints` changed
  (e.g. after `seedFakeHistory`), the delegate's `width: chart.barWidth`
  read the **stale** value (still 0 from initial render) and every
  bar landed at width=0 on top of the index-based x. Same class of bug
  as the previous `chart.barX(modelData.ts)` issue. Inlined the width
  formula as a ternary in the delegate and removed the property;
  replaced the helper with `barCenterX(index, n, plotInnerWidth)` so
  the tooltip also follows the index math.

## [1.5.5] — 2026-08-27

### Fixed
- **Stats charts: bars stacked at the right edge** — the bar's `x`
  binding used `chart.barX(modelData.ts)`, a function that reads
  `chart.firstTs` / `chart.spanMs` at call time. QML evaluated the
  binding *before* those properties updated when `dsPoints` changed,
  so every bar got `ratio=1` and overlapped at the rightmost edge.
  Position by `Repeater.index` instead — for the 5min-sampled data
  the widget produces, the result is visually identical to
  timestamp-based positioning. Removes the stale-dependency hazard.
- **Stats charts: bar height** — each bucket's `bar.p` was set to
  `minV` (= max used within the bucket). With seeded sawtooth data,
  most buckets looked invisible (height 0), so the chart appeared as
  one tall column at the spike. Switch to the average remaining per
  bucket so bars reflect typical usage in the window. `minP` / `maxP`
  envelope retained for any future peak visualization.

## [1.5.4] — 2026-08-27

### Fixed
- **HistoryStore.qml closing brace** — `seedFakeHistory` (1.5.3) was
  missing the outer `Item` scope's closing `}`, so Plasma refused to
  load the widget. Caught by `qmllint` (see dev tooling below).

### Added
- **QML lint gate** (`scripts/lint-qml.sh` + `.qmllint.ini`) — runs
  `pyside6-qmllint` over every `contents/ui/*.qml`. Catches syntax
  errors, undefined identifiers, type errors, etc. that Plasma only
  surfaces at widget load with cryptic errors. Install PySide6 if
  missing.
- **`scripts/check.sh`** — single pre-push gate: smoke test + QML
  lint. AGENTS.md updated.

### Added
- **QML lint gate** (`scripts/lint-qml.sh` + `.qmllint.ini` at repo root)
  runs `pyside6-qmllint` over every `contents/ui/*.qml`. Catches
  syntax errors, undefined identifiers, type errors, and other static
  issues that Plasma only surfaces at widget load. `qmllint` ships
  with PySide6; install with `pip install --user pyside6` if missing.
- **`scripts/check.sh`** runs smoke test + QML lint as a single
  pre-push gate. AGENTS.md updated — both checks are required before
  any commit.
>>>>>>> 7ddc282 (chore(dev): qmllint gate + scripts/check.sh + AGENTS.md)

## [1.5.3] — 2026-08-27

### Added
- **History dev tools** in the General config page (new "Backup & dev
  tools" section):
  - **Backup current history** — snapshots the namespaced blob to a
    separate `HistoryBackup` Settings slot so it survives a later
    "Clear history" or "Fill with fake samples".
  - **Restore from backup** — replaces the current namespace with the
    snapshot and clears the backup slot so a second click can't
    silently re-apply it.
  - **Fill with fake samples** — generates a deterministic sawtooth
    spanning the configured 5h and weekly retention windows (varies
    end-of-window remaining per window so multiple bars render). Both
    seed and restore run through confirmation dialogs that explain
    what's about to be overwritten.

## [1.5.2] — 2026-08-26

### Changed
- **Header shows widget version** (e.g. `v1.5.2`) next to the Refresh
  button instead of the live clock, so you can tell at a glance whether
  Plasma is running the freshly-installed QML or a cached older copy.

## [1.5.1] — 2026-08-26

### Fixed
- **Stats charts: bar metric.** Each bucket's bar height now uses the
  average remaining percentage (not the min), so buckets with no usage
  spike no longer collapse to height 0. Previously only the peak bucket
  was visible, making the chart look like "one column".
