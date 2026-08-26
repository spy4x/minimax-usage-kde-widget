#!/usr/bin/env bash
# Lint every QML file under contents/ui/ using PySide6's bundled qmllint
# (Qt 6). Catches syntax errors, missing braces, undefined identifiers,
# and other static issues before Plasma tries to load the widget.
#
# Exits non-zero on any file with errors (warnings allowed per
# .qmllint.ini at the repo root).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="${HOME}/.local/bin/pyside6-qmllint"

if [[ ! -x "$LINT" ]]; then
  echo "lint-qml: $LINT not found. Install with: pip install --user pyside6" >&2
  exit 127
fi

shopt -s nullglob
files=( "$ROOT"/org.spy4x.minimaxquota/contents/ui/*.qml )

if (( ${#files[@]} == 0 )); then
  echo "lint-qml: no QML files found under contents/ui/" >&2
  exit 0
fi

fail=0
for f in "${files[@]}"; do
  # qmllint exits 0 on clean, 1 on warnings-only, >=2 on errors. The .ini
  # in the repo root downgrades the noisy "Unqualified access" warnings
  # caused by missing Plasma/Kirigami import paths to info-level so they
  # don't fail the build on every commit.
  out="$("$LINT" "$f" 2>&1)"
  code=$?
  if (( code == 0 )); then
    continue
  fi
  # Show only lines that aren't info-only (filter out the import noise).
  errs="$(printf '%s\n' "$out" | grep -v -E '^\s*$|^\s*Info:|^Info: |^\s*import\s|^---$')"
  if (( code >= 2 )) || [[ -n "$errs" ]]; then
    echo "=== $(basename "$f") (qmllint exit $code) ==="
    printf '%s\n' "$errs"
    echo ""
    fail=1
  fi
done

if (( fail )); then
  echo "lint-qml: errors found" >&2
  exit 1
fi

echo "lint-qml: ${#files[@]} files clean"