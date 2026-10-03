#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p .build/module-cache build
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
swift build --configuration release --disable-sandbox --cache-path .build/package-cache --config-path .build/config --security-path .build/security
APP="${1:-$PWD/build/Still.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Still "$APP/Contents/MacOS/Still"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
codesign --force --deep --sign - "$APP"
printf 'Built %s\n' "$APP"
