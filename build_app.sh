#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="角色效率岛"
EXECUTABLE_NAME="CharacterEfficiencyIsland"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
RESOURCE_BUNDLE_NAME="CharacterEfficiencyIsland_CharacterEfficiencyIsland.bundle"

cd "$ROOT_DIR"
swift build -c release --product "$EXECUTABLE_NAME"
RELEASE_DIR="$(swift build -c release --show-bin-path)"

/bin/rm -rf "$APP_DIR"
/bin/mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

/bin/cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
/bin/cp "$RELEASE_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
/bin/chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

if [[ -d "$RELEASE_DIR/$RESOURCE_BUNDLE_NAME" ]]; then
  /bin/cp -R "$RELEASE_DIR/$RESOURCE_BUNDLE_NAME" "$RESOURCES_DIR/"
fi

for image in "$ROOT_DIR"/Sources/CharacterEfficiencyIsland/Assets/*.png; do
  /bin/cp "$image" "$RESOURCES_DIR/"
done

ICON_SOURCE="$ROOT_DIR/Sources/CharacterEfficiencyIsland/Assets/statusIcon.png"
ICONSET="$DIST_DIR/AppIcon.iconset"
/bin/rm -rf "$ICONSET"
/bin/mkdir -p "$ICONSET"

sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"
/bin/rm -rf "$ICONSET"

codesign --force --deep --sign - "$APP_DIR" >/dev/null

/bin/rm -f "$DIST_DIR/$APP_NAME.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$DIST_DIR/$APP_NAME.zip"

echo "$APP_DIR"
echo "$DIST_DIR/$APP_NAME.zip"
