#!/usr/bin/env bash
#
# prepare_assets.sh — populate app/src/main/assets/payload/ before building.
#
# Run this on your workstation (needs network + arm64 binaries). It:
#   1. Clones the OneShot Python source into the payload.
#   2. Reminds you to drop the arm64 binaries OneShot calls into payload/bin.
#
# The payload is bundled into the APK and extracted at runtime by AssetInstaller.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/app/src/main/assets/payload"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[*] Payload dir: $ASSETS"
mkdir -p "$ASSETS/bin"

# ---------------------------------------------------------------------------
# 1) OneShot source
# ---------------------------------------------------------------------------
echo "[*] Cloning OneShot (kimocoder fork)..."
git clone --depth 1 https://github.com/kimocoder/OneShot.git "$TMP/OneShot"
cp "$TMP/OneShot/oneshot.py" "$ASSETS/oneshot.py"
# OneShot is largely single-file; copy any extra modules/data it ships with.
for extra in pixiewps wps *.py; do
  [ -e "$TMP/OneShot/$extra" ] && cp -r "$TMP/OneShot/$extra" "$ASSETS/" 2>/dev/null || true
done
echo "[+] OneShot source copied"

# ---------------------------------------------------------------------------
# 2) arm64 binaries — YOU must supply these
# ---------------------------------------------------------------------------
cat <<'EOF'

[!] ACTION REQUIRED: place arm64 (aarch64) binaries in payload/bin/

    Required by OneShot:
      python3          self-contained arm64 build (+ stdlib in payload/lib)
      wpa_supplicant   OneShot drives it via its control socket
      pixiewps         offline Pixie Dust PIN computation
      iw               wireless interface control

    NOTE: OneShot does NOT need monitor mode — it uses wpa_supplicant on a
    managed interface, so the phone's internal wlan0 works (root required).

    Where to get arm64 builds:
      - Termux:   pkg install python pixiewps wpa-supplicant iw
                  then copy $PREFIX/bin/<tool> and the $PREFIX/lib/*.so they
                  link against into payload/bin and payload/lib
      - Kali NetHunter chroot: copy /usr/bin/<tool> (+ their libs)
      - Build from source with the Android NDK

    Verify arch:  file payload/bin/pixiewps   # -> ARM aarch64

EOF

echo "[*] Done. Now build:  ./gradlew assembleDebug"
