#!/usr/bin/env bash
set -euo pipefail

SCHEME="BrowserBaby"
CONFIGURATION="Release"
ARCHIVE_PATH="build/BrowserBaby.xcarchive"
EXPORT_DIR="build/export"
APP_PATH="$EXPORT_DIR/BrowserBaby.app"
ZIP_PATH="build/BrowserBaby-macOS.zip"

mkdir -p build

if [ ! -d "BrowserBaby.xcodeproj" ]; then
  echo "Generating project with xcodegen..."
  xcodegen generate --spec project.yml
fi

xcodebuild archive \
  -project BrowserBaby.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'platform=macOS' \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
cp -R "$ARCHIVE_PATH/Products/Applications/BrowserBaby.app" "$APP_PATH"

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Shareable app zip created at: $ZIP_PATH"
