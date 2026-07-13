#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache"

swift build -c release --product MeetingAudioCapture

APP_DIR="$ROOT_DIR/.build/release/MeetingAudioCapture.app"
LEGACY_APP_DIR="$ROOT_DIR/.build/release/MeetingRecorder.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$APP_DIR" "$LEGACY_APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$ROOT_DIR/.build/release/MeetingAudioCapture" "$MACOS_DIR/MeetingAudioCapture"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

chmod +x "$MACOS_DIR/MeetingAudioCapture"

echo "$APP_DIR"
