#!/bin/bash
# End-to-end production release script for MacHarmony.
# Handles: version bump -> archive/export -> dmg build -> notarize/staple ->
# Sparkle sign_update -> appcast update.
#
# Hosting the DMG is left to you: the built DMG is placed in
# macharmony-website/public/downloads/, and the appcast enclosure URL is
# built from DOWNLOAD_BASE_URL. Point that at wherever you serve the DMG.
#
# Usage:
#   APPLE_ID="you@icloud.com" \
#   APPLE_TEAM_ID="TEAMID" \
#   APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
#   DOWNLOAD_BASE_URL="https://downloads.example.com/releases" \
#   bash scripts/release-full.sh 1.0.3
#
# Optional env vars:
#   APPLE_NOTARY_PROFILE=notarytool-profile
#   SIGN_UPDATE_BIN=/abs/path/to/sign_update
#   RELEASE_NOTES_HTML="<li>...</li><li>...</li>"
#   APP_PATH="/path/to/exported/MacHarmony.app"   # skips archive/export and uses this app


set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "❌ Missing version."
  echo "   Usage: bash scripts/release-full.sh <version>"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEBSITE_ROOT="$(dirname "$PROJECT_ROOT")/macharmony-website"
PBXPROJ="$PROJECT_ROOT/MacHarmony.xcodeproj/project.pbxproj"
APPCAST="$WEBSITE_ROOT/public/appcast.xml"
DMG_PATH="$WEBSITE_ROOT/public/downloads/MacHarmony.dmg"
ARCHIVE_PATH="$HOME/Desktop/MacHarmony-${VERSION}.xcarchive"
EXPORT_PATH="$HOME/Desktop/MacHarmony-${VERSION}-export"
EXPORT_APP="$EXPORT_PATH/MacHarmony.app"
EXPORT_OPTIONS="$PROJECT_ROOT/scripts/export-options-developer-id.plist"
NOTARY_PROFILE="${APPLE_NOTARY_PROFILE:-notarytool-profile}"
APP_PATH="${APP_PATH:-}"

APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
DOWNLOAD_BASE_URL="${DOWNLOAD_BASE_URL:-}"
RELEASE_NOTES_HTML="${RELEASE_NOTES_HTML:-<li>Maintenance and stability improvements.</li>}"

if [ -z "$DOWNLOAD_BASE_URL" ]; then
  echo "❌ DOWNLOAD_BASE_URL is required (base URL where the DMG is hosted)."
  exit 1
fi

if [ -z "$APPLE_ID" ] || [ -z "$APPLE_TEAM_ID" ] || [ -z "$APPLE_APP_PASSWORD" ]; then
  echo "❌ APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_PASSWORD are required."
  exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Version must be in MAJOR.MINOR.PATCH format (example: 1.0.3)."
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
BUILD_NUMBER=$((MAJOR * 10000 + MINOR * 100 + PATCH))

SIGN_UPDATE_BIN="${SIGN_UPDATE_BIN:-}"
if [ -z "$SIGN_UPDATE_BIN" ]; then
  if [ -x "$PROJECT_ROOT/bin/sign_update" ]; then
    SIGN_UPDATE_BIN="$PROJECT_ROOT/bin/sign_update"
  elif [ -x "$(dirname "$PROJECT_ROOT")/.cursor/tools/bin/sign_update" ]; then
    SIGN_UPDATE_BIN="$(dirname "$PROJECT_ROOT")/.cursor/tools/bin/sign_update"
  elif command -v sign_update >/dev/null 2>&1; then
    SIGN_UPDATE_BIN="$(command -v sign_update)"
  fi
fi
if [ -z "$SIGN_UPDATE_BIN" ] || [ ! -x "$SIGN_UPDATE_BIN" ]; then
  echo "❌ sign_update not found. Set SIGN_UPDATE_BIN or install Sparkle tools."
  exit 1
fi

echo "🔢 Updating version to $VERSION ($BUILD_NUMBER)..."
perl -0pi -e "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/g; s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g;" "$PBXPROJ"

if [ -n "$APP_PATH" ]; then
  if [ ! -d "$APP_PATH" ]; then
    echo "❌ APP_PATH does not exist: $APP_PATH"
    exit 1
  fi
  echo "📦 Using provided app path: $APP_PATH"
else
  echo "🏗️  Archiving app..."
  xcodebuild archive \
    -project "$PROJECT_ROOT/MacHarmony.xcodeproj" \
    -scheme "MacHarmony" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH"

  echo "📤 Exporting signed app..."
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"
  APP_PATH="$EXPORT_APP"
fi

echo "💽 Building DMG..."
bash "$PROJECT_ROOT/scripts/build-dmg.sh" "$APP_PATH"

echo "🔐 Storing/refreshing notary credentials profile..."
xcrun notarytool store-credentials "$NOTARY_PROFILE" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" >/dev/null

echo "🧾 Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "📎 Stapling + validating DMG..."
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "✍️  Signing update metadata (Sparkle)..."
SIGN_OUTPUT="$("$SIGN_UPDATE_BIN" "$DMG_PATH")"
ED_SIG="$(printf '%s' "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
DMG_LEN="$(printf '%s' "$SIGN_OUTPUT" | sed -n 's/.*length="\([0-9]*\)".*/\1/p')"
if [ -z "$ED_SIG" ] || [ -z "$DMG_LEN" ]; then
  echo "❌ Failed to parse sign_update output:"
  echo "$SIGN_OUTPUT"
  exit 1
fi

echo "📦 DMG built at: $DMG_PATH"
echo "   Upload it to your host so it is reachable under DOWNLOAD_BASE_URL."

VERSIONED_URL="${DOWNLOAD_BASE_URL%/}/MacHarmony-${VERSION}.dmg"
PUB_DATE="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")"
ITEM_FILE="$(mktemp)"
cat > "$ITEM_FILE" <<EOF
    <!-- ── v${VERSION} — Automated release ───────────────────────────────── -->
    <item>
      <title>MacHarmony ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h3 style="font-family:-apple-system,sans-serif;font-size:14px;">What's New in ${VERSION}</h3>
        <ul style="font-family:-apple-system,sans-serif;font-size:13px;line-height:1.6;">
          ${RELEASE_NOTES_HTML}
        </ul>
      ]]></description>
      <enclosure
        url="${VERSIONED_URL}"
        sparkle:edSignature="${ED_SIG}"
        length="${DMG_LEN}"
        type="application/octet-stream"
      />
    </item>
EOF

echo "📰 Updating appcast..."
# Remove any existing item with the same short version string.
perl -0pi -e "s|\\s*<!-- ── v${VERSION}.*?</item>\\s*||gs" "$APPCAST"
# Insert new item after <language> line.
awk -v insert_file="$ITEM_FILE" '
  {
    print $0
    if ($0 ~ /<language>en<\/language>/) {
      while ((getline line < insert_file) > 0) print line
      close(insert_file)
      print ""
    }
  }
' "$APPCAST" > "${APPCAST}.tmp"
mv "${APPCAST}.tmp" "$APPCAST"
rm -f "$ITEM_FILE"

echo "✅ Release ${VERSION} complete."
echo "   Build number: ${BUILD_NUMBER}"
echo "   Versioned URL: ${VERSIONED_URL}"
echo "   DMG length: ${DMG_LEN}"
echo "   Sparkle signature: ${ED_SIG}"
