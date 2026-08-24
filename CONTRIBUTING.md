# Contributing

Thanks for taking the time to contribute. This is a small, focused
project — a single Plasma 6 plasmoid — so the contribution surface is
narrow and the turnaround is fast.

## Quick checklist

- [ ] Search existing [issues](../../issues) and [PRs](../../pulls) to avoid duplicates.
- [ ] For non-trivial changes, open an issue first to align on direction.
- [ ] Run `./install.sh` after edits — it copies into Plasma's user-local path.
- [ ] Bump `KPlugin.Version` in `metadata.json` on user-visible changes.
- [ ] Use Conventional Commits.
- [ ] Verify the smoke-test passes (`node scripts/smoke-test.mjs`).

## Workflow

1. Fork or clone the repo.
2. Create a branch: `git checkout -b feat/my-change` or `fix/...` /
   `refactor/...` / `docs/...` / `chore/...` / `style/...`.
3. Make changes.
4. **Test on a real Plasma 6 desktop** before opening a PR. The
   smoke-test covers parsing/formatting but not rendering — QML bugs
   only show up in a live shell.
5. Commit (Conventional Commits).
6. Open a PR. CI doesn't exist; review is manual.

## Style

- 2-space indent, double quotes, no semicolons, trailing commas where legal.
- Plasmoid source stays inside `org.spy4x.minimaxquota/`. No build tooling.
- QML braces balance — verify with:

  ```bash
  for f in org.spy4x.minimaxquota/contents/**/*.qml; do
    o=$(grep -o '{' "$f" | wc -l); c=$(grep -o '}' "$f" | wc -l)
    [ "$o" = "$c" ] || echo "MISMATCH: $f"
  done
  ```

- Conventional commits:

  ```
  feat(plasmoid): add vertical layout option
  fix(plasmoid): coerce null to 0 in QuotaBar — display shows '—'
  docs: add webp preview, optimize 87%
  ```

  Subject ≤ 72 chars, imperative mood, no trailing period, no AI attribution.

## Architecture decisions (so you don't have to re-litigate)

- **No build tooling** (no webpack/vite/etc). QML + Node only.
- **`install.sh` copies** (not symlinks) into `~/.local/share/plasma/plasmoids/`.
  A copy is independent of the source repo: if the repo is moved, renamed,
  or wiped, the install keeps working.
- **Plasma 6 conventions** (see [porting guide](https://develop.kde.org/docs/plasma/widget/porting_kf6/)):
  - Root must be `PlasmoidItem` (not `Item`)
  - Config dialog root must be `KCM.SimpleKCM` (not `Item`)
  - `theme` global is gone — use `PlasmaCore.Theme.*` after `import org.kde.plasma.core as PlasmaCore`
  - `X-Plasma-API-Minimum-Version` (hyphenated, not camelCase)

## Security

- **Never commit secrets** — no API keys, tokens, or `.env` files.
  The widget reads the key from the user's local config dialog.
- The repo-local [AGENTS.md](AGENTS.md) extends the global security rules.

## Reporting bugs

Use the [bug report template](../../issues/new?template=bug_report.md).
Include:

- Plasma version (`plasmashell --version`)
- Widget version (`cat ~/.local/share/plasma/plasmoids/org.spy4x.minimaxquota/metadata.json | grep Version`)
- `journalctl --user -b --no-pager --since "1 minute ago" | grep -i spy4x` output
- Steps to reproduce
