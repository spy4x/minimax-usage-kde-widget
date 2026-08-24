---
name: Bug report
about: Something is broken in the MiniMax Quota widget
title: "[bug] "
labels: bug
---

## Description

A clear description of what went wrong.

## Steps to reproduce

1. …
2. …
3. …

## Expected

What you expected to happen.

## Actual

What actually happened.

## Environment

- Plasma version: `plasmashell --version`
- Widget version: `cat ~/.local/share/plasma/plasmoids/org.spy4x.minimaxquota/metadata.json | grep Version`
- Linux distro: (Fedora / Arch / openSUSE / etc.)
- DE session: Wayland / X11

## Logs

```bash
journalctl --user -b --no-pager --since "1 minute ago" | grep -i spy4x
```

Paste the output. **Redact any API key** — values starting with `sk-cp-...`
are secrets; replace with `<REDACTED:API_KEY>`.

## Screenshots

If relevant, attach. **Do not include screenshots that show your API
key** (e.g. the config dialog with the password field unmasked).
