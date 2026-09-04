#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CACHE_ARM64="$DIR/build_cache/arm64"
CACHE_X86="$DIR/build_cache/x86_64"
APP_BUNDLE="$DIR/PrayerTimes.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building Prayer Times as Universal 2 Binary (Apple Silicon + Intel)..."
mkdir -p "$CACHE_ARM64" "$CACHE_X86" "$MACOS" "$RESOURCES"

SOURCES=(
  "$DIR/Sources/PrayerEngine.swift"
  "$DIR/Sources/NotificationHelper.swift"
  "$DIR/Sources/LocationManager.swift"
  "$DIR/Sources/LaunchAtLoginHelper.swift"
  "$DIR/Sources/PrayerStore.swift"
  "$DIR/Sources/Views/PopoverView.swift"
  "$DIR/Sources/AppDelegate.swift"
  "$DIR/Sources/main.swift"
)

# 1. Compile arm64 slice (Apple Silicon M1/M2/M3/M4)
echo "Compiling arm64 slice..."
swiftc \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$CACHE_ARM64" \
  -O \
  "${SOURCES[@]}" \
  -o "$MACOS/PrayerTimes-arm64"

# 2. Compile x86_64 slice (Intel Macs)
echo "Compiling x86_64 slice..."
swiftc \
  -target x86_64-apple-macos13.0 \
  -module-cache-path "$CACHE_X86" \
  -O \
  "${SOURCES[@]}" \
  -o "$MACOS/PrayerTimes-x86_64"

# 3. Combine into Universal 2 binary with lipo
echo "Creating Universal 2 fat binary with lipo..."
lipo -create -output "$MACOS/PrayerTimes" "$MACOS/PrayerTimes-arm64" "$MACOS/PrayerTimes-x86_64"
rm -f "$MACOS/PrayerTimes-arm64" "$MACOS/PrayerTimes-x86_64"

# Copy Info.plist
cp "$DIR/Info.plist" "$CONTENTS/Info.plist"

# Copy Resources
if [ -d "$DIR/Resources" ]; then
    cp -R "$DIR/Resources/"* "$RESOURCES/"
fi

echo "APPL????" > "$CONTENTS/PkgInfo"

# Ad-hoc sign
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "✅ App bundle built successfully at: $APP_BUNDLE"
lipo -info "$MACOS/PrayerTimes"
