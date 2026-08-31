#!/usr/bin/env bash
# Pre-push gate: run both smoke test and QML lint. Exits non-zero on the
# first failure. Use this instead of running each script manually.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0

echo "==> smoke test"
if ! node "$ROOT/scripts/smoke-test.mjs"; then
  fail=1
fi

echo
echo "==> QML lint"
if ! "$ROOT/scripts/lint-qml.sh"; then
  fail=1
fi

echo
if (( fail )); then
  echo "check: FAIL" >&2
  exit 1
fi
echo "check: ok"