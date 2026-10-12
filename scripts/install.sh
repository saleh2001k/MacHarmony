#!/bin/bash
# Build MacHarmony in the Release configuration and install it to /Applications.
#
# Usage:
#   ./scripts/install.sh              # build, install, launch
#   ./scripts/install.sh --no-launch  # build + install only
#
# Optional env vars:
#   INSTALL_DIR=/Applications   # where MacHarmony.app is copied (e.g. "$HOME/Applications")
#   TEAM_ID=ABCDE12345          # sign with your Apple Developer team instead of ad-hoc

set -euo pipefail

APP_NAME="MacHarmony"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$PROJECT_ROOT/build/install"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
DEST_APP="$INSTALL_DIR/$APP_NAME.app"
TEAM_ID="${TEAM_ID:-}"
LAUNCH=1

for arg in "$@"; do
  case "$arg" in
    --no-launch) LAUNCH=0 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "❌ Unknown option: $arg"; exit 1 ;;
  esac
done

# xcodebuild needs the full Xcode app, not just the Command Line Tools.
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "❌ xcodebuild is not available."
  echo "   Install Xcode from the App Store, then run:"
  echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

if [ -n "$TEAM_ID" ]; then
  echo "🔏 Signing with Apple Developer team $TEAM_ID"
  SIGNING_OPTS=(-allowProvisioningUpdates)
  SIGNING_SETTINGS=(CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM_ID")
else
  # Ad-hoc ("Sign to Run Locally"): no Apple account needed.
  echo "🔏 Signing ad-hoc (set TEAM_ID to sign with your Apple Developer team)"
  SIGNING_OPTS=()
  SIGNING_SETTINGS=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
fi

echo "🏗️  Building $APP_NAME (Release)..."
xcodebuild \
  -project "$PROJECT_ROOT/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet \
  ${SIGNING_OPTS[@]+"${SIGNING_OPTS[@]}"} \
  build \
  "${SIGNING_SETTINGS[@]}"

if [ ! -d "$BUILT_APP" ]; then
  echo "❌ Build finished but $BUILT_APP was not found."
  exit 1
fi

if pgrep -x "$APP_NAME" >/dev/null; then
  echo "🛑 Quitting running $APP_NAME..."
  osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do
    pgrep -x "$APP_NAME" >/dev/null || break
    sleep 1
  done
  pkill -x "$APP_NAME" 2>/dev/null || true
fi

echo "📦 Installing to $DEST_APP..."
mkdir -p "$INSTALL_DIR" 2>/dev/null || true
if ! { rm -rf "$DEST_APP" && ditto "$BUILT_APP" "$DEST_APP"; } 2>/dev/null; then
  echo "🔑 $INSTALL_DIR needs admin rights; retrying with sudo..."
  sudo rm -rf "$DEST_APP"
  sudo ditto "$BUILT_APP" "$DEST_APP"
fi

codesign --verify --deep --strict "$DEST_APP"

# Refresh Launchpad / Spotlight / Finder so the new build shows up right away.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$DEST_APP/Contents/Info.plist" 2>/dev/null || echo '?')"
echo "✅ $APP_NAME $VERSION installed at $DEST_APP"

if [ "$LAUNCH" = 1 ]; then
  open "$DEST_APP"
fi
