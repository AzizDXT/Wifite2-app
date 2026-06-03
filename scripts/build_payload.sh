#!/usr/bin/env bash
#
# build_payload.sh — fully automatic payload builder for the OneShot app.
#
# Produces dist/payload.zip containing:
#   oneshot.py + bin/ (python3, pixiewps, wpa_supplicant, iw, …) + lib/ (their
#   shared objects + the Python stdlib), all aarch64.
#
# Binaries are pulled from the Termux apt repo (aarch64) with automatic
# dependency resolution — no device or manual copying needed.
#
# Usage:
#   scripts/build_payload.sh                 # build dist/payload.zip
#   PUBLISH=1 TAG=v0.1.0 scripts/build_payload.sh   # build + upload via gh
#
# Requirements (on your build machine): curl OR wget, dpkg-deb, xz, zip, perl,
# git; and `gh` (authenticated) only when PUBLISH=1.
#
set -euo pipefail

# ---- config ----------------------------------------------------------------
ARCH="${ARCH:-aarch64}"
# Two repos: python/openssl/libnl live in termux-main; the WPS tools
# (pixiewps, wpa-supplicant, iw) live in the separate termux-root repo.
# Each entry is "<base-url> <dist>/<component>".
MAIN_REPO="${TERMUX_MAIN_REPO:-https://packages.termux.dev/apt/termux-main}"
ROOT_REPO="${TERMUX_ROOT_REPO:-https://packages.termux.dev/apt/termux-root}"
REPOS=(
  "$MAIN_REPO dists/stable/main/binary-$ARCH/Packages"
  "$ROOT_REPO dists/root/stable/binary-$ARCH/Packages"
)
ONESHOT_REPO="${ONESHOT_REPO:-https://github.com/kimocoder/OneShot.git}"
# Root packages; their dependency closure is resolved automatically.
ROOT_PKGS=(python pixiewps wpa-supplicant iw openssl libnl)
# Meta/utility packages we never want pulled into the payload.
SKIP_PKGS=" termux-tools termux-keyring termux-am termux-am-socket termux-exec \
termux-licenses command-not-found apt dpkg dash bash coreutils ncurses-utils \
ca-certificates gnupg readline-static "

PREFIX_REL="data/data/com.termux/files/usr"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT_DIR/dist"
WORK="$(mktemp -d)"
PAYLOAD="$WORK/payload"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DIST" "$PAYLOAD/bin" "$PAYLOAD/lib"

# ---- helpers ---------------------------------------------------------------
fetch() {  # fetch <url> <out>
  if command -v curl >/dev/null; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null; then wget -qO "$2" "$1"
  else echo "need curl or wget" >&2; exit 1; fi
}

# ---- 1) package index ------------------------------------------------------
# URL[pkg] holds the full .deb download URL (the repo base is folded in so the
# two repos can be merged into one map); DEPS[pkg] holds its dependency list.
declare -A URL DEPS
i=0
for entry in "${REPOS[@]}"; do
  base="${entry%% *}"; path="${entry#* }"
  echo "[*] Fetching package index: $base ($ARCH)..."
  idx="$WORK/idx.$((i++))"
  fetch "$base/$path" "$idx"
  while IFS=$'\t' read -r pkg file deps; do
    [[ -n "$pkg" ]] || continue
    # First repo wins for a given package (main before root).
    [[ -n "${URL[$pkg]:-}" ]] && continue
    URL["$pkg"]="$base/$file"
    DEPS["$pkg"]="$deps"
  done < <(perl -ne '
    if (/^Package:\s*(\S+)/) { $p=$1 }
    elsif (/^Filename:\s*(\S+)/) { $f=$1 }
    elsif (/^Depends:\s*(.+)/) { $d=$1 }
    elsif (/^\s*$/ && defined $p) {
      $d //= ""; $d =~ s/\([^)]*\)//g; $d =~ s/\s+//g;
      print "$p\t$f\t$d\n"; undef $p; undef $f; undef $d;
    }' "$idx")
done

# ---- 2) resolve dependency closure (BFS) -----------------------------------
echo "[*] Resolving dependencies..."
declare -A SEEN
queue=("${ROOT_PKGS[@]}")
resolved=()
while ((${#queue[@]})); do
  p="${queue[0]}"; queue=("${queue[@]:1}")
  [[ -n "${SEEN[$p]:-}" ]] && continue
  [[ " $SKIP_PKGS " == *" $p "* ]] && continue
  [[ -z "${URL[$p]:-}" ]] && continue         # virtual / unknown -> skip
  SEEN[$p]=1
  resolved+=("$p")
  IFS=',' read -ra ds <<< "${DEPS[$p]:-}"
  for d in "${ds[@]}"; do
    d="${d%%|*}"                               # take first of "a|b"
    [[ -n "$d" ]] && queue+=("$d")
  done
done
echo "[+] ${#resolved[@]} packages: ${resolved[*]}"

# ---- 3) download + extract -------------------------------------------------
for p in "${resolved[@]}"; do
  echo "[*] fetch $p"
  fetch "${URL[$p]}" "$WORK/$p.deb"
  mkdir -p "$WORK/x/$p"
  dpkg-deb -x "$WORK/$p.deb" "$WORK/x/$p"
done

# ---- 4) assemble payload from the Termux prefix ----------------------------
echo "[*] Assembling payload..."
for p in "${resolved[@]}"; do
  src="$WORK/x/$p/$PREFIX_REL"
  for sub in bin lib libexec etc share; do
    if [[ -d "$src/$sub" ]]; then
      mkdir -p "$PAYLOAD/$sub"
      cp -a "$src/$sub/." "$PAYLOAD/$sub/" 2>/dev/null || true
    fi
  done
done

# Sanity: required binaries present?
missing=()
for b in python3 pixiewps wpa_supplicant iw; do
  [[ -e "$PAYLOAD/bin/$b" ]] || missing+=("$b")
done
if ((${#missing[@]})); then
  echo "[!] WARNING: missing binaries: ${missing[*]}" >&2
fi

# ---- 5) OneShot source -----------------------------------------------------
echo "[*] Cloning OneShot..."
git clone --depth 1 "$ONESHOT_REPO" "$WORK/OneShot"
cp "$WORK/OneShot/oneshot.py" "$PAYLOAD/oneshot.py"
[[ -f "$WORK/OneShot/vulnwsc.txt" ]] && cp "$WORK/OneShot/vulnwsc.txt" "$PAYLOAD/"
for extra in pixiewps wps; do
  [[ -e "$WORK/OneShot/$extra" ]] && cp -r "$WORK/OneShot/$extra" "$PAYLOAD/" || true
done

# ---- 6) zip ----------------------------------------------------------------
rm -f "$DIST/payload.zip"
( cd "$PAYLOAD" && zip -qr "$DIST/payload.zip" . )
echo "[+] Wrote $DIST/payload.zip ($(du -h "$DIST/payload.zip" | cut -f1))"

# ---- 7) optional publish (fixes the runtime 404) ---------------------------
if [[ "${PUBLISH:-0}" == "1" ]]; then
  command -v gh >/dev/null || { echo "[!] gh not found" >&2; exit 1; }
  TAG="${TAG:-payload-$(date +%Y%m%d%H%M)}"
  echo "[*] Publishing release $TAG..."
  if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" "$DIST/payload.zip" --clobber
  else
    gh release create "$TAG" "$DIST/payload.zip" \
      --title "$TAG" --notes "OneShot runtime payload (aarch64)" --latest
  fi
  echo "[+] Published. The app's default URL now resolves:"
  echo "    .../releases/latest/download/payload.zip"
fi
