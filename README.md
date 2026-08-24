# MiniMax Quota — KDE Plasma 6 Widget

Plasma 6 plasmoid that shows your MiniMax M3 Token Plan usage — both the
5-hour and weekly windows — with live reset countdowns. Designed to sit on
a secondary monitor and remind you to use the quota.

![widget preview placeholder](docs/screenshot-placeholder.png)

## Features

- **5-hour window** progress bar with reset countdown.
- **Weekly window** progress bar with reset countdown.
- Color-coded bars: green → orange → red as you consume more.
- Manual refresh button + automatic polling (configurable, default 60s).
- API key never hardcoded — entered once via the widget's config dialog.
- API key persisted via `QtCore.Settings` (0600 file recommended).

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

If widgets don't appear, run `plasmoidreload` in a terminal, or log out
and back in (Wayland often requires a full session restart).

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
    ├── config/main.qml     # configuration dialog
    └── ui/
        ├── main.qml         # full representation (the tile you see)
        ├── CompactRepresentation.qml
        └── QuotaBar.qml     # reusable progress row
install.sh                   # symlink into ~/.local/share/plasma/plasmoids/
scripts/smoke-test.mjs       # node test for parsing & formatting
```

## Development / testing without KDE

```bash
node scripts/smoke-test.mjs
```

This validates the response parsing and `formatDuration` logic without
needing Plasma installed.

## License

MIT — see [LICENSE](LICENSE).