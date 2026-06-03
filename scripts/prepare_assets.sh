#!/usr/bin/env bash
#
# prepare_assets.sh — build assets/payload.zip before `flutter build apk`.
#
# Run on your workstation (needs network + arm64 binaries). It:
#   1. Clones the OneShot source.
#   2. Assembles a payload tree (oneshot.py + bin/ + lib/).
#   3. Zips it to assets/payload.zip, which the app extracts at runtime.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/assets"
TMP="$(mktemp -d)"
PAYLOAD="$TMP/payload"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$ASSETS" "$PAYLOAD/bin" "$PAYLOAD/lib"

# ---------------------------------------------------------------------------
# 1) OneShot source
# ---------------------------------------------------------------------------
echo "[*] Cloning OneShot (kimocoder fork)..."
git clone --depth 1 https://github.com/kimocoder/OneShot.git "$TMP/OneShot"
cp "$TMP/OneShot/oneshot.py" "$PAYLOAD/oneshot.py"
for extra in pixiewps wps *.py; do
  [ -e "$TMP/OneShot/$extra" ] && cp -r "$TMP/OneShot/$extra" "$PAYLOAD/" 2>/dev/null || true
done
echo "[+] OneShot source staged"

# ---------------------------------------------------------------------------
# 2) arm64 binaries — YOU must supply these into $PAYLOAD/bin (and libs in /lib)
# ---------------------------------------------------------------------------
cat <<EOF

[!] ACTION REQUIRED before zipping: copy arm64 (aarch64) binaries into:
      $PAYLOAD/bin   -> python3 wpa_supplicant pixiewps iw
      $PAYLOAD/lib   -> the *.so they link against (+ python3 stdlib)

    OneShot does NOT need monitor mode — it uses wpa_supplicant on a managed
    interface, so the phone's internal wlan0 works (root required).

    Easiest source (Termux):
      pkg install python pixiewps wpa-supplicant iw
      cp \$PREFIX/bin/{python3,pixiewps,wpa_supplicant,iw}  $PAYLOAD/bin/
      cp -r \$PREFIX/lib/python3.* \$PREFIX/lib/*.so        $PAYLOAD/lib/

    Press Enter once the binaries are in place to build the zip (Ctrl-C to abort).
EOF
read -r _

# ---------------------------------------------------------------------------
# 3) zip into the Flutter asset
# ---------------------------------------------------------------------------
( cd "$PAYLOAD" && zip -qr "$ASSETS/payload.zip" . )
echo "[+] Wrote $ASSETS/payload.zip"
echo "[*] Now: flutter pub get && flutter build apk --release"
