# MiniMax Quota — KDE Plasma 6 Widget

Plasma 6 plasmoid that shows your MiniMax M3 Token Plan usage — both the
5-hour and weekly windows — with live reset countdowns. Two concentric
rings per card let you see at a glance whether you're pacing your
consumption against the window.

![widget preview](docs/preview.png)

## Features

- **5-hour window** card with concentric rings: outer = time elapsed,
  inner = quota used. Compare the two to spot over- or under-utilization.
- **Weekly window** card with the same layout.
- **Color-coded** inner ring: cyan → orange (< 1h reset) → red (< 30m reset).
- **Live-ticking** countdowns (subtract elapsed since fetch each second).
- **Live clock** in the header.
- **Manual refresh** button + auto-polling (configurable, default 60s).
- API key entered once via the widget's config dialog, stored via
  `QtCore.Settings` in `~/.config/plasma-workspace/`. Never in the repo.

## Install (KDE Plasma 6 desktop)

```bash
git clone https://github.com/spy4x/minimax-usage-kde-widget
cd minimax-usage-kde-widget
./install.sh
```

Then:

1. Right-click desktop or panel → **Add Widgets...**
2. Search **"MiniMax"** (or `org.spy4x.minimaxquota`)
3. Drag the widget onto your desktop or panel
4. Right-click the widget → **Configure MiniMax Quota...**
5. Paste your Token Plan **Subscription Key** (the one from
   [Billing → Token Plan](https://platform.minimax.io/user-center/payment/token-plan),
   format `sk-cp-...`)
6. Click OK. Widget polls within ~1 second.

`install.sh` copies the plasmoid into `~/.local/share/plasma/plasmoids/`
(not symlinks) so Syncthing races against `~/sync/code/` can't wipe the
install. After QML/JSON edits, re-run `./install.sh` to refresh the copy.

## API

The widget queries the public Token Plan usage endpoint:

```
GET https://www.minimax.io/v1/token_plan/remains
Authorization: Bearer <your-token-plan-key>
```

The JSON response contains a `model_remains` array. The widget filters
for `model_name == "general"` and displays:

- `current_interval_remaining_percent` — 5-hour window, 0..100 (100 = unused)
- `current_weekly_remaining_percent` — weekly window, 0..100
- `remains_time` — milliseconds until the 5-hour window resets
- `weekly_remains_time` — milliseconds until the weekly window resets

## Security

- The API key is stored in `~/.config/plasma-workspace/` via `QtCore.Settings`.
  It's **never** hardcoded into the widget, the repo, or logs.
- For extra hardening:

  ```bash
  chmod 600 ~/.config/plasma-workspace/*minimaxquota*.conf
  ```

- **Never share your key.** If you leak it (chat, screenshot, public issue),
  rotate it in the MiniMax dashboard **immediately** — old value is
  compromised the moment it appears in any delivered state.

## Files

```
org.spy4x.minimaxquota/     # the plasmoid source
├── metadata.json
└── contents/
    ├── config/
    │   ├── config.qml         # ConfigModel with General category
    │   └── ui/ConfigGeneral.qml  # configuration dialog form
    └── ui/
        ├── main.qml            # full representation (the tile you see)
        ├── CompactRepresentation.qml
        └── QuotaCard.qml       # reusable card with concentric rings
install.sh                     # copy into ~/.local/share/plasma/plasmoids/
scripts/smoke-test.mjs         # node test for parsing & formatting
docs/preview.png               # widget screenshot
```

## Development / testing without KDE

```bash
node scripts/smoke-test.mjs
```

This validates the response parsing and `formatDuration` logic without
needing Plasma installed.

## License

MIT — see [LICENSE](LICENSE).
