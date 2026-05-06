#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Yiyi"
BUNDLE_NAME="译译.app"
BUILD_DIR=".build/release"
OUT_DIR="build"
APP_DIR="$OUT_DIR/$BUNDLE_NAME"

echo "==> swift build -c release"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP_DIR/Contents/Info.plist"

# Ad-hoc codesign so Accessibility permission sticks to this binary.
codesign --force --deep --sign - \
    --entitlements Yiyi.entitlements \
    --options runtime \
    "$APP_DIR" 2>/dev/null || codesign --force --deep --sign - "$APP_DIR"

echo "==> Built: $APP_DIR"
echo "   使用方式："
echo "   1. open \"$APP_DIR\""
echo "   2. 首次运行会弹辅助功能权限请求，去「系统设置 → 隐私与安全性 → 辅助功能」里打勾"
echo "   3. 菜单栏点 🗨️ → 设置…，填入 DeepSeek API Key"
echo "   4. 选中任意文字，按 ⌥D"
