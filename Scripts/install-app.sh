#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MeetingAudioCapture"
APP_BUNDLE_ID="app.codex.meeting-audio-capture"
LEGACY_BUNDLE_ID="app.codex.meeting-recorder"
APP_BUNDLE="$ROOT_DIR/.build/release/$APP_NAME.app"
INSTALL_DIR="/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"
PROCESS_PATTERN="/$APP_NAME.app/Contents/MacOS/$APP_NAME"
LEGACY_PROCESS_PATTERN="/MeetingRecorder.app/Contents/MacOS/MeetingRecorder"

cd "$ROOT_DIR"

"$ROOT_DIR/Scripts/package-app.sh"

quit_app() {
    local bundle_id="$1"
    local pattern="$2"

    if ! pgrep -f "$pattern" >/dev/null 2>&1; then
        return 0
    fi

    osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true

    for _ in {1..20}; do
        if ! pgrep -f "$pattern" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.2
    done

    return 1
}

if ! quit_app "$APP_BUNDLE_ID" "$PROCESS_PATTERN"; then
    echo "$APP_NAME is still running. Quit it from the menu bar, then rerun this script." >&2
    exit 1
fi

if ! quit_app "$LEGACY_BUNDLE_ID" "$LEGACY_PROCESS_PATTERN"; then
    echo "Legacy MeetingRecorder is still running. Quit it from the menu bar, then rerun this script." >&2
    exit 1
fi

if [[ "$INSTALLED_APP" != "/Applications/$APP_NAME.app" ]]; then
    echo "Unexpected install path: $INSTALLED_APP" >&2
    exit 1
fi

rm -rf "$INSTALLED_APP"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/"
open "$INSTALLED_APP"

echo "$INSTALLED_APP"
