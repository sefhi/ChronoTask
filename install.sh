#!/bin/bash
#
# ChronoTask — build and install.
#
# ChronoTask is not distributed through the App Store and is not notarised, so this
# script signs it ad-hoc (a free, local signature) and strips the quarantine flag.
# That is what lets the app open without Gatekeeper complaining, and without you
# needing an Apple Developer account.
#
#   ./install.sh              build and install into /Applications
#   ./install.sh --run        …and launch it when done
#   ./install.sh --dev        install into ./Build instead (no /Applications write)
#   ./install.sh --login      also start ChronoTask automatically at login
#   ./install.sh --uninstall  remove the app and the login item
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ChronoTask"
BUNDLE_ID="com.chronotask.app"
DEST_DIR="/Applications"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/${BUNDLE_ID}.plist"
RUN_AFTER=0
ADD_LOGIN_ITEM=0

for arg in "$@"; do
  case "$arg" in
    --run)   RUN_AFTER=1 ;;
    --dev)   DEST_DIR="$REPO/Build" ;;
    --login) ADD_LOGIN_ITEM=1 ;;
    --uninstall)
      echo "==> Removing ChronoTask"
      pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
      launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
      rm -f "$LAUNCH_AGENT"
      rm -rf "/Applications/${APP_NAME}.app" "$REPO/Build/${APP_NAME}.app"
      echo "    Done. Your ClickUp token is still in the Keychain;"
      echo "    remove it with: security delete-generic-password -s ${BUNDLE_ID}"
      exit 0 ;;
    -h|--help)
      sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

APP="${DEST_DIR}/${APP_NAME}.app"
BUILD_DIR="$REPO/.build-tmp"

echo "==> ChronoTask installer"
echo "    Target: $APP"

# ---------------------------------------------------------------- build

# Full Xcode gives the better build (asset catalog, app icon). Command Line Tools
# alone are enough to produce a working binary, just without the icon.
if xcodebuild -version >/dev/null 2>&1; then
  echo "==> Building with Xcode"
  command -v xcodegen >/dev/null 2>&1 || {
    echo "!!  XcodeGen is required. Install it with: brew install xcodegen" >&2
    exit 1
  }
  (cd "$REPO" && xcodegen generate >/dev/null)
  xcodebuild -project "$REPO/${APP_NAME}.xcodeproj" \
             -scheme "$APP_NAME" \
             -configuration Release \
             SYMROOT="$BUILD_DIR" \
             CODE_SIGN_IDENTITY="-" \
             CODE_SIGNING_REQUIRED=NO \
             CODE_SIGNING_ALLOWED=NO \
             build >/dev/null
  BUILT="$BUILD_DIR/Release/${APP_NAME}.app"
else
  echo "==> Building with the Swift compiler (Xcode not selected)"
  BUILT="$BUILD_DIR/${APP_NAME}.app"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILT/Contents/MacOS" "$BUILT/Contents/Resources/Fonts"

  find "$REPO/ChronoTask" -name '*.swift' -not -path '*/Resources/*' \
    | sort | tr '\n' '\0' > "$BUILD_DIR/files.z"
  xargs -0 swiftc -O \
      -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
      -target "$(uname -m)-apple-macos13.0" \
      -swift-version 5 -parse-as-library \
      -o "$BUILT/Contents/MacOS/${APP_NAME}" < "$BUILD_DIR/files.z"

  cp "$REPO/ChronoTask/Info.plist" "$BUILT/Contents/Info.plist"
  cp "$REPO"/ChronoTask/Resources/Fonts/*.ttf "$BUILT/Contents/Resources/Fonts/"
  printf 'APPL????' > "$BUILT/Contents/PkgInfo"

  # Info.plist is written for Xcode, which expands these at build time. Left as-is
  # they reach the bundle as literal "$(…)" strings, and LaunchServices reads a
  # nonsense minimum system version.
  plutil -replace CFBundleExecutable -string "$APP_NAME" "$BUILT/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$BUILT/Contents/Info.plist"
  plutil -replace LSMinimumSystemVersion -string "13.0" "$BUILT/Contents/Info.plist"

  # `swiftc` cannot compile an asset catalogue and `actool` ships only with full
  # Xcode, but `iconutil` is part of the base system — which is enough for the app
  # icon. The menu bar mark needs nothing here: it is drawn in code precisely so
  # that it cannot go missing on this path (see Utilities/StatusItemIcon.swift).
  ICONSET="$BUILD_DIR/AppIcon.iconset"
  APPICON_SRC="$REPO/ChronoTask/Assets.xcassets/AppIcon.appiconset"
  if [ -d "$APPICON_SRC" ]; then
    mkdir -p "$ICONSET"
    # The appiconset uses the same icon_<size>[@2x].png names iconutil expects.
    cp "$APPICON_SRC"/icon_*.png "$ICONSET/" 2>/dev/null || true
    if iconutil -c icns "$ICONSET" -o "$BUILT/Contents/Resources/AppIcon.icns" 2>/dev/null; then
      plutil -replace CFBundleIconFile -string "AppIcon" "$BUILT/Contents/Info.plist"
    else
      echo "    Note: could not build the app icon; the app is unaffected."
    fi
    rm -rf "$ICONSET"
  fi
fi

# ---------------------------------------------------------------- install

echo "==> Installing"
pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
mkdir -p "$DEST_DIR"
rm -rf "$APP"
cp -R "$BUILT" "$APP"
rm -rf "$BUILD_DIR"

# Ad-hoc signature: no Apple Developer account, no notarisation. It is what lets
# the Keychain recognise the app across launches, so your token survives updates.
echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

# Without this, an app built locally can still be treated as downloaded and blocked.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

if ! codesign --verify --deep "$APP" 2>/dev/null; then
  echo "!!  Signature verification failed — the app may refuse to open." >&2
fi

# ---------------------------------------------------------------- login item

if [ "$ADD_LOGIN_ITEM" -eq 1 ]; then
  echo "==> Adding login item"
  mkdir -p "$(dirname "$LAUNCH_AGENT")"
  cat > "$LAUNCH_AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>${BUNDLE_ID}</string>
    <key>ProgramArguments</key>
    <array><string>${APP}/Contents/MacOS/${APP_NAME}</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><false/>
</dict>
</plist>
PLIST
  launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
  launchctl load "$LAUNCH_AGENT"
fi

echo
echo "==> Installed at $APP"
echo "    Open the panel from anywhere with ⌥⌘T, or click the stopwatch in the menu bar."

if [ "$RUN_AFTER" -eq 1 ]; then
  echo "==> Launching"
  open "$APP"
fi
