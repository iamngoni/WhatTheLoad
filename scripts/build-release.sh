#!/bin/bash

# WhatTheLoad Release Build Script

set -e

echo "🔨 Building WhatTheLoad for Release..."

# Clean build folder
xcodebuild clean -project WhatTheLoad.xcodeproj -scheme WhatTheLoad -configuration Release

# Build for release
xcodebuild archive \
    -project WhatTheLoad.xcodeproj \
    -scheme WhatTheLoad \
    -configuration Release \
    -archivePath build/WhatTheLoad.xcarchive

# Export app
xcodebuild -exportArchive \
    -archivePath build/WhatTheLoad.xcarchive \
    -exportPath build/Release \
    -exportOptionsPlist scripts/ExportOptions.plist

# Create DMG (requires create-dmg: brew install create-dmg)
if command -v create-dmg &> /dev/null; then
    echo "📦 Creating DMG..."
    create-dmg \
        --volname "WhatTheLoad" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "WhatTheLoad.app" 175 120 \
        --hide-extension "WhatTheLoad.app" \
        --app-drop-link 425 120 \
        "build/WhatTheLoad.dmg" \
        "build/Release/WhatTheLoad.app"
    echo "✅ DMG created at build/WhatTheLoad.dmg"
else
    echo "⚠️  create-dmg not found. Install with: brew install create-dmg"
    echo "✅ App built at build/Release/WhatTheLoad.app"
fi

echo "🎉 Build complete!"
