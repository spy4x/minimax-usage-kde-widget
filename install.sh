#!/usr/bin/env bash
# Install the MiniMax Quota plasmoid into user-local Plasma 6.
# Copies (not symlinks) so the install survives if the source repo
# is moved, renamed, or wiped. Re-run after editing QML to refresh.
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLASMOID_ID="org.spy4x.minimaxquota"
SRC="$SCRIPT_DIR/$PLASMOID_ID"
DEST="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"

if [ ! -d "$SRC" ]; then
  echo "ERROR: plasmoid source not found at $SRC" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"

# Replace any existing install (file, dir, or symlink) so we always end up
# with a fresh copy of the source.
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  echo "Replacing existing install at $DEST"
  rm -rf "$DEST"
fi

cp -r "$SRC" "$DEST"

echo "Installed: $DEST (copy from $SRC)"
echo
cat <<'EOF'
Next steps on your KDE Plasma 6 desktop:
  1. Right-click on desktop or panel -> Add Widgets...
  2. Search "MiniMax" (or "org.spy4x.minimaxquota")
  3. Drag onto your desktop or panel
  4. Right-click the widget -> "Configure MiniMax Quota..."
  5. Paste your Token Plan Subscription Key (sk-cp-...) -> OK

After editing QML/JSON, re-run ./install.sh to refresh the install copy.
If widgets don't appear, run from a terminal:
  busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 0

Or log out and back in (Wayland sessions often need a full restart).
EOF
