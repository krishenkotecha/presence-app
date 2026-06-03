#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$PROJECT_DIR/Presence.xcodeproj"
DERIVED_DATA_PATH="$PROJECT_DIR/DerivedData"
DEVICE_ID="${1:-00008140-00194D523C38801C}"
BUNDLE_ID="com.krishenkotecha.Presence"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphoneos/Presence.app"

echo "Building Presence for device $DEVICE_ID..."
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme Presence \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -allowProvisioningUpdates \
  build

echo "Installing Presence..."
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  "$APP_PATH"

echo "Launching Presence..."
xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  "$BUNDLE_ID"
