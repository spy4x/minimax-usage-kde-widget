# Local rules — extends global ~/.config/opencode/AGENTS.md

This repo is a public KDE Plasma 6 plasmoid. No secrets ever.

## Hard constraints

- **No API keys, tokens, or any real credentials** in tracked files.
  All secrets enter via the widget's config dialog and persist to
  QtCore.Settings on the user's local machine.
- No `.env`, `.env.age`, or any key-bearing file. `.gitignore` blocks them.
- The leaked key in the original chat session is a public surface; rotate it
  in the MiniMax dashboard immediately. Never reuse it.

## Style

- Plasmoid files in `org.spy4x.minimaxquota/`. Don't move.
- No TypeScript, no build step. Pure QML + a single Node smoke-test.
- **Before every commit, run `./scripts/check.sh`.** It runs both gates
  and fails fast on either:
  - `node scripts/smoke-test.mjs` — mirrors the QML JS logic in Node.
  - `scripts/lint-qml.sh` — runs `qmllint` (bundled with PySide6 at
    `~/.local/bin/pyside6-qmllint`) over every `contents/ui/*.qml`.
    Catches missing braces, undefined identifiers, type errors, and
    other static issues that Plasma only surfaces at widget load with
    cryptic QML errors. Config: `.qmllint.ini` at repo root downgrades
    the noisy "Unqualified access" warnings (Plasma/Kirigami can't be
    resolved without runtime import paths) so they don't fail the
    build; real syntax/type errors still do. Don't lower the warning
    level for real categories to make the build green.
  - If `pyside6-qmllint` is missing: `pip install --user pyside6`.
- **Add a Node test when you add JS logic to a QML file.** The smoke
  test mirrors each QML JS function into `scripts/smoke-test.mjs` and
  adds assertions. If your change isn't tested, the next agent will
  ship a regression.

## Releases

- Bump `metadata.json` `KPlugin.Version` on changes.
- Conventional commits (`feat|fix|chore(scope): subject`).