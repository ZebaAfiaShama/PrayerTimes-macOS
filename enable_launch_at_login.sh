#!/bin/bash

APP_PATH="$HOME/Applications/PrayerTimes.app"
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/PrayerTimes.app"
fi

echo "Adding $APP_PATH to macOS Login Items..."
osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP_PATH\", hidden:false}" 2>/dev/null && echo "✅ Added to Login Items!" || echo "⚠️ Could not automatically add to Login Items. You can manually drag $APP_PATH into System Settings -> General -> Login Items."
