#!/bin/bash
# Script to apply display names across all platforms
# Run after: dart run icons_launcher:create

set -e

APP_NAME="HanKan - Chinese Reader"
SHORT_NAME="HanKan"

echo "Applying display names across platforms..."

# Android (already set, but ensure it)
if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
    sed -i "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/" android/app/src/main/AndroidManifest.xml
    echo "✓ Android"
fi

# iOS (already set, but ensure it)
if [ -f "ios/Runner/Info.plist" ]; then
    sed -i "s/<string>HanKan.*<\/string>/<string>$APP_NAME<\/string>/g" ios/Runner/Info.plist
    echo "✓ iOS"
fi

# Web manifest.json
if [ -f "web/manifest.json" ]; then
    sed -i "s/\"name\": \"[^\"]*\"/\"name\": \"$APP_NAME\"/" web/manifest.json
    sed -i "s/\"short_name\": \"[^\"]*\"/\"short_name\": \"$SHORT_NAME\"/" web/manifest.json
    echo "✓ Web manifest"
fi

# Web index.html
if [ -f "web/index.html" ]; then
    sed -i "s/<title>[^<]*<\/title>/<title>$APP_NAME<\/title>/" web/index.html
    sed -i "s/content=\"[^\"]*\" \/>$/content=\"$APP_NAME\">/" web/index.html
    # Fix the apple-mobile-web-app-title line properly
    sed -i "s/<meta name=\"apple-mobile-web-app-title\" content=\"[^\"]*\">/<meta name=\"apple-mobile-web-app-title\" content=\"$APP_NAME\">/" web/index.html
    echo "✓ Web index.html"
fi

# Linux window title
if [ -f "linux/runner/my_application.cc" ]; then
    sed -i 's/gtk_header_bar_set_title(header_bar, "[^"]*");/gtk_header_bar_set_title(header_bar, "'"$APP_NAME"'");/' linux/runner/my_application.cc
    sed -i 's/gtk_window_set_title(window, "[^"]*");/gtk_window_set_title(window, "'"$APP_NAME"'");/' linux/runner/my_application.cc
    echo "✓ Linux"
fi

# Windows window title
if [ -f "windows/runner/main.cpp" ]; then
    sed -i 's/L"[^"]*"/L"'"$APP_NAME"'"/' windows/runner/main.cpp
    echo "✓ Windows"
fi

# Windows Runner.rc
if [ -f "windows/runner/Runner.rc" ]; then
    sed -i "s/\"ProductName\", \"[^\"]*\"/\"ProductName\", \"$APP_NAME\"/" windows/runner/Runner.rc
    sed -i "s/\"FileDescription\", \"[^\"]*\"/\"FileDescription\", \"$APP_NAME\"/" windows/runner/Runner.rc
    echo "✓ Windows Runner.rc"
fi

# Snap desktop file
if [ -f "snap/gui/hankan_chinese_reader.desktop" ]; then
    sed -i "s/Name=.*/Name=$APP_NAME/" snap/gui/hankan_chinese_reader.desktop
    echo "✓ Snap desktop"
fi

echo "Done! All display names applied."