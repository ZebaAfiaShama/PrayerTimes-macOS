#!/bin/bash
set -e

SOURCE_APP="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/PrayerTimes.app"
DEST_DIR="$HOME/Applications"

mkdir -p "$DEST_DIR"
echo "Installing Prayer Times to $DEST_DIR..."

# Quit existing running instance if any
pkill -f PrayerTimes || true
pkill -f DhakaNamazBar || true

# Copy app bundle
rm -rf "$DEST_DIR/PrayerTimes.app"
rm -rf "$DEST_DIR/DhakaNamazBar.app"
cp -R "$SOURCE_APP" "$DEST_DIR/"

echo "✅ Installed successfully to $DEST_DIR/PrayerTimes.app"
echo "Starting app..."
open "$DEST_DIR/PrayerTimes.app" || "$DEST_DIR/PrayerTimes.app/Contents/MacOS/PrayerTimes" &
