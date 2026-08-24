---
name: Pull request
about: Contribute a change to the MiniMax Quota widget
---

## What

A concise description of the change.

## Why

The motivation. Link the issue if there is one.

## How tested

- [ ] `node scripts/smoke-test.mjs` passes (9/9)
- [ ] Tested on a real Plasma 6 desktop
- [ ] Widget renders at default size without manual resize
- [ ] Config dialog opens, fields save
- [ ] Empty-state (no API key) renders the hint
- [ ] Live data renders (poll, colors, countdowns)

## Screenshots

If the change is visual, attach before/after.

## Checklist

- [ ] `KPlugin.Version` bumped if user-visible
- [ ] Conventional commit message (≤72 chars, no trailing period)
- [ ] No secrets in the diff
- [ ] Plasmoid files only added/modified under `org.spy4x.minimaxquota/`
