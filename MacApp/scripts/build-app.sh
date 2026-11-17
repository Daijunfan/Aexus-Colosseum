#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Aexus Colosseum"
EXECUTABLE="AexusColosseum"
DEST="/Applications/$APP_NAME.app"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/aexus-app.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/$APP_NAME.app"
ART="$ROOT/../The Pit AI Arena.png"

echo "▸ Icon…"
if [[ ! -f "$ROOT/Assets/AppIcon.icns" || "${REBUILD_ICON:-0}" == "1" ]]; then
  swift "$ROOT/scripts/make-appicon.swift" "$ART" "$ROOT/Assets" \
        "$ROOT/Sources/AexusColosseum/Resources"
fi

echo "▸ Building release binary…"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# SwiftPM resource bundle (contains the seeded catalog).
for bundle in "$BIN_DIR"/*.bundle; do
  [[ -e "$bundle" ]] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
done

cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/.build/checkouts/SwiftTerm/LICENSE" "$APP/Contents/Resources/SwiftTerm-LICENSE.txt"

echo "▸ Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1

# Exactly one copy on the Mac: the newly built bundle replaces whatever is in
# /Applications, and the old in-project build output is not kept around.
echo "▸ Installing to $DEST"
rm -rf "$DEST"
ditto "$APP" "$DEST"
codesign --force --deep --sign - "$DEST" >/dev/null 2>&1
rm -rf "$ROOT/dist"

echo "▸ Ready: $DEST"
