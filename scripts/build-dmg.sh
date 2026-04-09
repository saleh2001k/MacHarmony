#!/bin/bash
# Build MacHarmony.dmg from an exported MacHarmony.app
# Usage: ./build-dmg.sh /path/to/MacHarmony.app
#   or:  ./build-dmg.sh   (looks for MacHarmony.app on ~/Desktop by default)

set -e

APP_PATH="${1:-$HOME/Desktop/MacHarmony.app}"
STAGING_DIR="/tmp/macharmony-dmg-staging"
OUTPUT_DMG="$HOME/Downloads/MacHarmony.dmg"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON="$PROJECT_ROOT/MacHarmony/Assets.xcassets/AppIcon.appiconset/512.png"

# Validate app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ MacHarmony.app not found at: $APP_PATH"
    echo "   Export it from Xcode: Product → Archive → Distribute App → Direct Distribution"
    exit 1
fi

# Clean up old artifacts
rm -rf "$STAGING_DIR"
rm -f "$OUTPUT_DMG"
rm -f "$HOME/Downloads/rw.*.MacHarmony.dmg"

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
