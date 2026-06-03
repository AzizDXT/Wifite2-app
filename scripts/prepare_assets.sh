#!/usr/bin/env bash
#
# prepare_assets.sh — populate app/src/main/assets/payload/ before building.
#
# Run this on your workstation (needs network + arm64 binaries). It does TWO
# things:
#   1. Clones the wifite2 Python source into the payload.
#   2. Reminds you to drop the arm64 tool binaries into payload/bin.
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
# 1) wifite source
# ---------------------------------------------------------------------------
echo "[*] Cloning wifite2 (kimocoder fork)..."
git clone --depth 1 https://github.com/kimocoder/wifite2.git "$TMP/wifite2"
cp -r "$TMP/wifite2/wifite"   "$ASSETS/wifite"
cp    "$TMP/wifite2/Wifite.py" "$ASSETS/Wifite.py"
echo "[+] wifite source copied"

# ---------------------------------------------------------------------------
# 2) arm64 binaries — YOU must supply these
# ---------------------------------------------------------------------------
cat <<'EOF'

[!] ACTION REQUIRED: place arm64 (aarch64) binaries in payload/bin/

    Required:   python3
    Core:       iw  ip  airmon-ng  airodump-ng  aireplay-ng  aircrack-ng
    WPS:        reaver  wash  bully
    PMKID/WPA:  hcxdumptool  hcxpcapngtool  tshark
    Cracking:   hashcat   (+ its OpenCL/kernels, large)

    Where to get arm64 builds:
      - Kali NetHunter chroot:  copy /usr/bin/<tool>  (+ libs they need)
      - Termux:                 pkg install python aircrack-ng reaver hcxtools
                                then copy $PREFIX/bin/<tool> and the matching
                                $PREFIX/lib/*.so they link against
      - Build from source with the Android NDK (most reliable for injection
        tooling that pins libpcap/libnl versions)

    python3 must be a self-contained arm64 build (e.g. Termux's python +
    its $PREFIX/lib/python3.* stdlib copied to payload/lib).

    Verify each binary is arm64:  file payload/bin/aircrack-ng

EOF

echo "[*] Done. Now build:  ./gradlew assembleDebug"
