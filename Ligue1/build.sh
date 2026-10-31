#!/bin/bash
# © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
# Builds Ligue1.app with the Command Line Tools toolchain (no Xcode required).
#   ./build.sh          build into ./build/Ligue1.app
#   ./build.sh run      build, then launch
#   ./build.sh install  build, then copy to /Applications
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Ligue1"
DEPLOY_TARGET="14.0"
ARCHS="arm64 x86_64"    # binaire universel (Apple Silicon + Intel)
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
SDK="$(xcrun --show-sdk-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# --- Compile (one slice per arch, lipo'd together) ---
slices=()
for arch in $ARCHS; do
    out="$BUILD_DIR/$APP_NAME-$arch"
    swiftc \
        -sdk "$SDK" \
        -target "$arch-apple-macos$DEPLOY_TARGET" \
        -swift-version 5 \
        -O -whole-module-optimization \
        -o "$out" \
        ./*.swift
    slices+=("$out")
done
lipo -create "${slices[@]}" -output "$APP/Contents/MacOS/$APP_NAME"
rm -f "${slices[@]}"

# --- Icon: 1024px source -> AppIcon.icns ---
# Source régénérable : swift outils/icone_ballon.swift Assets.xcassets/AppIcon.appiconset/ballon.png
ICON_SRC="Assets.xcassets/AppIcon.appiconset/ballon.png"
if [ -f "$ICON_SRC" ]; then
    ICONSET="$BUILD_DIR/AppIcon.iconset"
    rm -rf "$ICONSET"; mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z $size $size            "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png"      >/dev/null
        sips -z $((size*2)) $((size*2)) "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png"  >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
fi

cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Signature. Une identité stable garde les mêmes autorisations d'une
# compilation à l'autre ; à défaut, signature ad hoc.
SIGN_ID="${LIGUE1_SIGN_ID:-Ligue1 Local Signing}"
if codesign --force --deep --sign "$SIGN_ID" "$APP" 2>/dev/null; then
    echo "Signe avec : $SIGN_ID"
else
    codesign --force --deep --sign - "$APP"
    echo "Signe ad-hoc : identite absente."
fi
codesign --verify --verbose "$APP"

echo "Built $APP"

case "${1:-}" in
    run)     open "$APP" ;;
    install) rm -rf "/Applications/$APP_NAME.app"
             cp -R "$APP" /Applications/
             echo "Installed /Applications/$APP_NAME.app" ;;
esac
