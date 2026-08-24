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
- Run `node scripts/smoke-test.mjs` before pushing.

## Releases

- Bump `metadata.json` `KPlugin.Version` on changes.
- Conventional commits (`feat|fix|chore(scope): subject`).