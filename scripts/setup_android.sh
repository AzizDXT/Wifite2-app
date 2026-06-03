#!/usr/bin/env bash
#
# setup_android.sh — generate the git-ignored android/ host project and inject
# the runtime permissions the app needs. Safe to run repeatedly. Used by both
# local builds and CI.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -d android ]; then
  echo "[*] Generating android/ host project..."
  TMP="$(mktemp -d)"
  # Create into a temp dir and copy only android/ so our pubspec/lib are safe.
  flutter create --org run.taleb --project-name oneshot \
    --platforms=android "$TMP/host" >/dev/null
  cp -r "$TMP/host/android" ./android
  rm -rf "$TMP"
  echo "[+] android/ created"
fi

MANIFEST="android/app/src/main/AndroidManifest.xml"
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  echo "[*] Injecting permissions into AndroidManifest..."
  perl -0pi -e 's{(\s*<application)}{\n    <uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />\n    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />$1}' "$MANIFEST"
  echo "[+] Permissions added"
fi

echo "[*] Android host ready. Build with: flutter build apk --release"
