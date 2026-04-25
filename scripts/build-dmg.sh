#!/bin/bash
# Build MacHarmony.dmg from an exported MacHarmony.app
# Usage: ./build-dmg.sh /path/to/MacHarmony.app
#   or:  ./build-dmg.sh   (looks for MacHarmony.app on ~/Desktop by default)

set -e

APP_PATH="${1:-$HOME/Desktop/MacHarmony.app}"
MISSING_APP_HINT_PATH="$APP_PATH"
STAGING_DIR="/tmp/macharmony-dmg-staging"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEBSITE_DOWNLOADS="$(dirname "$PROJECT_ROOT")/macharmony-website/public/downloads"
mkdir -p "$WEBSITE_DOWNLOADS"
OUTPUT_DMG="$WEBSITE_DOWNLOADS/MacHarmony.dmg"
ICON="$PROJECT_ROOT/MacHarmony/Assets.xcassets/AppIcon.appiconset/512.png"

# Treat docs placeholder as invalid input and auto-detect instead.
if [ "$APP_PATH" = "/path/to/exported/MacHarmony.app" ]; then
    APP_PATH=""
    MISSING_APP_HINT_PATH="/path/to/exported/MacHarmony.app (placeholder)"
fi

# Auto-detect common export locations if path is missing.
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    shopt -s nullglob
    for candidate in "$HOME/Desktop/MacHarmony.app" "$HOME/Desktop/MacHarmony-"*/"MacHarmony.app"; do
        if [ -d "$candidate" ]; then
            APP_PATH="$candidate"
            break
        fi
    done
    shopt -u nullglob
fi

# Validate app exists
if [ ! -d "$APP_PATH" ]; then
    if [ -z "$APP_PATH" ]; then
        APP_PATH="$MISSING_APP_HINT_PATH"
    fi
    echo "❌ MacHarmony.app not found at: $APP_PATH"
    echo "   Export it from Xcode: Product → Archive → Distribute App → Direct Distribution"
    echo "   Then rerun with either:"
    echo "   - bash MacHarmony/scripts/build-dmg.sh"
    echo "   - bash MacHarmony/scripts/build-dmg.sh \"\$HOME/Desktop/MacHarmony-X.Y.Z/MacHarmony.app\""
    exit 1
fi

# Verify the exported app is signed with Hardened Runtime.
codesign_output="$(codesign -dvv "$APP_PATH" 2>&1 || true)"
if [[ "$codesign_output" != *"flags="*"runtime"* ]]; then
    echo "❌ \"$APP_PATH\" is not signed with Hardened Runtime."
    echo "   In Xcode: Target -> Signing & Capabilities -> enable Hardened Runtime."
    echo "   Then Archive + Distribute App again, and rerun this script."
    exit 1
fi

# Clean up old artifacts
rm -rf "$STAGING_DIR"
rm -f "$OUTPUT_DMG"
rm -f /tmp/rw.*.MacHarmony.dmg

# Stage the app
mkdir -p "$STAGING_DIR"
cp -r "$APP_PATH" "$STAGING_DIR/"

echo "📦 Building DMG from $APP_PATH..."
create-dmg \
  --volname "MacHarmony" \
  --volicon "$ICON" \
  --window-pos 200 120 \
  --window-size 560 380 \
  --icon-size 120 \
  --icon "MacHarmony.app" 160 185 \
  --hide-extension "MacHarmony.app" \
  --app-drop-link 400 185 \
  --hdiutil-retries 10 \
  "$OUTPUT_DMG" \
  "$STAGING_DIR"

# Clean up staging
rm -rf "$STAGING_DIR"
echo "✅ DMG created: $OUTPUT_DMG"
