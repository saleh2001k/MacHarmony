#!/bin/bash
# Build MacHarmony DMG and upload to Supabase Storage.
# Usage:
#   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... bash scripts/release-supabase.sh 1.0.0 "/path/to/MacHarmony.app"
#   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... bash scripts/release-supabase.sh 1.0.0
#   SKIP_BUILD=1 SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... bash scripts/release-supabase.sh 1.0.0

set -euo pipefail

VERSION="${1:-}"
APP_PATH="${2:-}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEBSITE_ROOT="$(dirname "$PROJECT_ROOT")/macharmony-website"
DMG_PATH="$WEBSITE_ROOT/public/downloads/MacHarmony.dmg"
SKIP_BUILD="${SKIP_BUILD:-0}"

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
SUPABASE_STORAGE_BUCKET="${SUPABASE_STORAGE_BUCKET:-releases}"
LATEST_OBJECT_PATH="${SUPABASE_LATEST_OBJECT_PATH:-MacHarmony.dmg}"
VERSIONED_OBJECT_PATH="${SUPABASE_VERSIONED_PREFIX:-MacHarmony-}${VERSION}.dmg"

if [ -z "$VERSION" ]; then
  echo "❌ Missing version."
  echo "   Usage: bash scripts/release-supabase.sh <version> [app-path]"
  exit 1
fi

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
  echo "❌ SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required."
  exit 1
fi

if [ "$SKIP_BUILD" != "1" ]; then
  if [ -n "$APP_PATH" ]; then
    bash "$PROJECT_ROOT/scripts/build-dmg.sh" "$APP_PATH"
  else
    bash "$PROJECT_ROOT/scripts/build-dmg.sh"
  fi
fi

if [ ! -f "$DMG_PATH" ]; then
  echo "❌ DMG not found after build: $DMG_PATH"
  exit 1
fi

upload_object() {
  local object_path="$1"
  local upload_url="${SUPABASE_URL%/}/storage/v1/object/${SUPABASE_STORAGE_BUCKET}/${object_path}"

  curl --fail --silent --show-error \
    -X POST "$upload_url" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "x-upsert: true" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$DMG_PATH" > /dev/null
}

echo "⬆️  Uploading DMG to Supabase bucket '$SUPABASE_STORAGE_BUCKET'..."
upload_object "$VERSIONED_OBJECT_PATH"
upload_object "$LATEST_OBJECT_PATH"

BASE_PUBLIC_URL="${SUPABASE_URL%/}/storage/v1/object/public/${SUPABASE_STORAGE_BUCKET}"
VERSIONED_PUBLIC_URL="${BASE_PUBLIC_URL}/${VERSIONED_OBJECT_PATH}"
LATEST_PUBLIC_URL="${BASE_PUBLIC_URL}/${LATEST_OBJECT_PATH}"

echo "✅ Upload complete."
echo "Versioned URL: $VERSIONED_PUBLIC_URL"
echo "Latest URL:    $LATEST_PUBLIC_URL"
echo
echo "Set website env:"
echo "VITE_DOWNLOAD_URL=$LATEST_PUBLIC_URL"
