#!/bin/bash
# Deep local cleanup for MacHarmony test iterations.
# Removes app bundle, caches, preferences, containers, logs, saved state, and keychain auth record.
#
# Usage:
#   bash scripts/purge-mac-harmony.sh

set -euo pipefail

APP_NAME="MacHarmony"
BUNDLE_ID="com.macharmony.app"
KEYCHAIN_SERVICE="com.macharmony.auth"
KEYCHAIN_ACCOUNT="auth-record"

echo "🧹 Purging local $APP_NAME data..."

# Best-effort app quit.
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

echo "🗑  Removing app bundle..."
sudo rm -rf "/Applications/$APP_NAME.app" 2>/dev/null || true

PATHS=(
  "$HOME/Library/Application Support/$BUNDLE_ID"
  "$HOME/Library/Application Support/$APP_NAME"
  "$HOME/Library/Caches/$BUNDLE_ID"
  "$HOME/Library/Caches/$APP_NAME"
  "$HOME/Library/Preferences/$BUNDLE_ID.plist"
  "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
  "$HOME/Library/Logs/$APP_NAME"
  "$HOME/Library/Logs/$BUNDLE_ID"
  "$HOME/Library/Application Scripts/$BUNDLE_ID"
  "$HOME/Library/WebKit/$BUNDLE_ID"
)

FAILED=()

for p in "${PATHS[@]}"; do
  if [ -e "$p" ]; then
    rm -rf "$p" 2>/dev/null || FAILED+=("$p")
  fi
done

# Containers sometimes need elevated permissions; try both ways.
for c in \
  "$HOME/Library/Containers/$BUNDLE_ID" \
  "$HOME/Library/Group Containers/"*"$BUNDLE_ID"*; do
  [ -e "$c" ] || continue
  rm -rf "$c" 2>/dev/null || sudo rm -rf "$c" 2>/dev/null || FAILED+=("$c")
done

echo "🧾 Clearing defaults + keychain auth record..."
defaults delete "$BUNDLE_ID" 2>/dev/null || true
security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" 2>/dev/null || true

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo
  echo "⚠️  Some paths could not be removed (usually macOS privacy restrictions):"
  for f in "${FAILED[@]}"; do
    echo "   - $f"
  done
  echo "   Grant Full Disk Access to Terminal and run again if needed."
else
  echo "✅ Local $APP_NAME data removed."
fi
