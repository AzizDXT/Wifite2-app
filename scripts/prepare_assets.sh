#!/usr/bin/env bash
#
# prepare_assets.sh — build the RELEASE payload.zip that the app downloads
# at runtime. Output: dist/payload.zip. Upload it to a GitHub release so the
# default download URL (releases/latest/download/payload.zip) resolves to it.
#
# The app does NOT bundle this — it fetches it on first launch.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
TMP="$(mktemp -d)"
PAYLOAD="$TMP/payload"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DIST" "$PAYLOAD/bin" "$PAYLOAD/lib"

# ---------------------------------------------------------------------------
# 1) OneShot source (automatic)
# ---------------------------------------------------------------------------
echo "[*] Cloning OneShot (kimocoder fork)..."
git clone --depth 1 https://github.com/kimocoder/OneShot.git "$TMP/OneShot"
cp "$TMP/OneShot/oneshot.py" "$PAYLOAD/oneshot.py"
for extra in pixiewps wps *.py; do
  [ -e "$TMP/OneShot/$extra" ] && cp -r "$TMP/OneShot/$extra" "$PAYLOAD/" 2>/dev/null || true
done
echo "[+] OneShot source staged"

# ---------------------------------------------------------------------------
# 2) arm64 binaries — supply these into $PAYLOAD/bin (and libs into /lib)
# ---------------------------------------------------------------------------
cat <<EOF

[!] Copy arm64 (aarch64) binaries into:
      $PAYLOAD/bin   -> python3 wpa_supplicant pixiewps iw
      $PAYLOAD/lib   -> the *.so they link against (+ python3 stdlib)

    OneShot needs no monitor mode — it uses wpa_supplicant on a managed
    interface, so the phone's internal wlan0 works (root required).

    Easiest source (Termux):
      pkg install python pixiewps wpa-supplicant iw
      cp \$PREFIX/bin/{python3,pixiewps,wpa_supplicant,iw}  $PAYLOAD/bin/
      cp -r \$PREFIX/lib/python3.* \$PREFIX/lib/*.so        $PAYLOAD/lib/

    Press Enter to package, or Ctrl-C to abort.
EOF
read -r _

# ---------------------------------------------------------------------------
# 3) zip -> dist/payload.zip (upload this to a GitHub release)
# ---------------------------------------------------------------------------
rm -f "$DIST/payload.zip"
( cd "$PAYLOAD" && zip -qr "$DIST/payload.zip" . )
echo "[+] Wrote $DIST/payload.zip"
echo "[*] Upload it:  gh release create vX.Y.Z $DIST/payload.zip   (or attach to an existing release)"
echo "[*] The app downloads it automatically from releases/latest/download/payload.zip"
