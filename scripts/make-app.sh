#!/bin/sh
# Builds DeskDroids.app (release, ad-hoc signed) and installs it in ~/Applications.
set -eu

cd "$(dirname "$0")/.."
bundle_id=com.stevendew.desk-droids
app=.build/DeskDroids.app
dest="$HOME/Applications/DeskDroids.app"

swift build -c release
bin="$(swift build -c release --show-bin-path)/DeskDroids"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin" "$app/Contents/MacOS/DeskDroids"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>         <string>$bundle_id</string>
    <key>CFBundleName</key>               <string>DeskDroids</string>
    <key>CFBundleDisplayName</key>        <string>desk-droids</string>
    <key>CFBundleExecutable</key>         <string>DeskDroids</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>0.6</string>
    <key>CFBundleVersion</key>            <string>6</string>
    <key>LSMinimumSystemVersion</key>     <string>13.0</string>
    <key>LSUIElement</key>                <true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"

# Quit the installed copy (not the dev build) so it can be replaced.
pkill -f "$dest/Contents/MacOS/DeskDroids" || true
mkdir -p "$HOME/Applications"
rm -rf "$dest"
cp -R "$app" "$dest"
echo "Installed $dest"
echo "Quit the dev build first (it holds port 4747), then: open \"$dest\""
