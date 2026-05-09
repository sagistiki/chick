#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Chick"
APP_DIR="$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR"

echo "Compiling main.swift..."
swiftc -O main.swift -o "$BIN_DIR/$APP_NAME" \
  -framework Cocoa -framework CoreImage

echo "Copying sprites..."
# Per-style chick spritesheets (256×64 each, 4 frames of 64×64).
for style in realistic anime memoji lego embroidered oil psx; do
  src="chick_${style}.png"
  if [ -f "$src" ]; then
    cp "$src" "$RES_DIR/chicken_${style}.png"
  else
    echo "  WARNING: $src missing — that style won't be available"
  fi
done

# ----- App icon: rasterize SVG to .icns -----
echo "Rendering app icon from icon.svg..."
RENDER_BIN=".build/render_icon"
mkdir -p .build
swiftc -O render_icon.swift -o "$RENDER_BIN" -framework Cocoa

ICONSET_DIR=".build/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Standard macOS iconset sizes (each base size + @2x retina)
declare -a sizes=(16 32 128 256 512)
for s in "${sizes[@]}"; do
  s2=$((s * 2))
  "$RENDER_BIN" icon.svg "$s"  "$ICONSET_DIR/icon_${s}x${s}.png"
  "$RENDER_BIN" icon.svg "$s2" "$ICONSET_DIR/icon_${s}x${s}@2x.png"
done

iconutil -c icns "$ICONSET_DIR" -o "$RES_DIR/AppIcon.icns"
echo "App icon → $RES_DIR/AppIcon.icns"

# Status-bar icon (22 pt + 44 pt @2x). Stored as a multi-rep TIFF so macOS picks the right size.
"$RENDER_BIN" icon.svg 22 ".build/menu_22.png"
"$RENDER_BIN" icon.svg 44 ".build/menu_44.png"
cp ".build/menu_22.png" "$RES_DIR/MenuIcon.png"
cp ".build/menu_44.png" "$RES_DIR/MenuIcon@2x.png"

# Single-image anime coop + island (500×500). Required asset.
if [ ! -f "new-chicks/coop.png" ]; then
  echo "ERROR: new-chicks/coop.png is missing — required for the chicken island widget"
  exit 1
fi
cp "new-chicks/coop.png" "$RES_DIR/coop.png"

# Keep the icon source alongside for users who want to tweak the design.
cp icon.svg "$RES_DIR/icon.svg"

# ----- Sounds -----
if [ -d "sounds" ]; then
  mkdir -p "$RES_DIR/sounds"
  shopt -s nullglob nocaseglob 2>/dev/null || true
  for f in sounds/*.mp3 sounds/*.wav sounds/*.aiff sounds/*.aif sounds/*.m4a sounds/*.caf; do
    [ -e "$f" ] || continue
    cp "$f" "$RES_DIR/sounds/"
  done
  echo "Sounds copied: $(ls "$RES_DIR/sounds" 2>/dev/null | wc -l | tr -d ' ') file(s)"
else
  echo "No sounds/ directory found (chirps will be silent until you add audio files there)"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>Chick</string>
  <key>CFBundleIdentifier</key><string>com.local.chick</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Refresh icon cache so Finder/Dock pick up the new icon immediately.
touch "$APP_DIR"

echo "Built $APP_DIR"
echo "Run: open '$APP_DIR'  (or double-click it in Finder)"
