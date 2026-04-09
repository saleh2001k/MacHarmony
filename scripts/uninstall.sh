#!/bin/bash
# Uninstall MacHarmony — removes the app and all related data

APP_NAME="MacHarmony"
BUNDLE_ID="com.macharmony.app"

echo "🗑  Uninstalling $APP_NAME..."

# Quit if running
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
sleep 1

# Remove the app
sudo rm -rf "/Applications/$APP_NAME.app"

# Remove all app data
rm -rf ~/Library/Application\ Support/$BUNDLE_ID
rm -rf ~/Library/Application\ Support/$APP_NAME
rm -rf ~/Library/Caches/$BUNDLE_ID
rm -rf ~/Library/Caches/$APP_NAME
rm -rf ~/Library/Preferences/$BUNDLE_ID.plist
rm -rf ~/Library/Saved\ Application\ State/$BUNDLE_ID.savedState
rm -rf ~/Library/Logs/$APP_NAME
rm -rf ~/Library/Logs/$BUNDLE_ID
sudo rm -rf ~/Library/Containers/$BUNDLE_ID
sudo rm -rf ~/Library/Group\ Containers/*$BUNDLE_ID* 2>/dev/null || true

# Remove UserDefaults (AppStorage keys: hasShownOnboarding, useDarkMode, etc.)
defaults delete $BUNDLE_ID 2>/dev/null || true

echo "✅ $APP_NAME fully removed."
