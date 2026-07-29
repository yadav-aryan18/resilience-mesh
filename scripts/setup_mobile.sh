#!/bin/bash
set -e

echo "📱 Setting up ResilienceMesh Mobile Node..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Ensure Flutter, Pub, and XDG directories write to workspace
export PUB_CACHE="${PUB_CACHE:-$WORKSPACE_ROOT/.pub-cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$WORKSPACE_ROOT/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$WORKSPACE_ROOT/.cache}"

mkdir -p "$PUB_CACHE" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

# Auto-detect Flutter SDK in PATH or workspace/local locations
if ! which flutter > /dev/null 2>&1; then
    for PATH_CANDIDATE in "$WORKSPACE_ROOT/flutter/bin" "$HOME/flutter/bin" "$HOME/development/flutter/bin" "/opt/flutter/bin" "/snap/bin"; do
        if [ -f "$PATH_CANDIDATE/flutter" ]; then
            export PATH="$PATH_CANDIDATE:$PATH"
            break
        fi
    done
fi

if ! which flutter > /dev/null 2>&1; then
    echo "⚠️  Flutter SDK binary not detected in PATH or standard locations."
    echo "   Please install Flutter SDK (>=3.19.0) from https://docs.flutter.dev/get-started/install"
    echo "   and ensure 'flutter' is added to your environment PATH."
    exit 1
fi

echo "🔍 Flutter environment version:"
flutter --version

cd "$WORKSPACE_ROOT/mobile"

echo "📦 Fetching Flutter pub dependencies..."
flutter pub get

echo "🔨 Building release APK..."
flutter build apk --release

echo "✅ ResilienceMesh Mobile APK build complete!"
echo "   APK Binary: mobile/build/app/outputs/flutter-apk/app-release.apk"
echo "   Or run on connected device: flutter run --release"
