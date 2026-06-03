# OneShot-app — Flutter (APK) wrapper for OneShot

[![CI](https://github.com/AzizDXT/Wifite2-app/actions/workflows/ci.yml/badge.svg)](https://github.com/AzizDXT/Wifite2-app/actions/workflows/ci.yml)

A **Flutter** Android app with a calm, professional UI that **automatically
downloads** the [OneShot](https://github.com/kimocoder/OneShot) WPS-attack tool
plus the arm64 binaries it needs (`payload.zip`), extracts them, and runs
OneShot **as root** — streaming its output to a live console. The APK itself is
small; the payload is fetched at runtime. It's a *launcher/container* for
OneShot, not a reimplementation.

> ⚠️ **Read [LEGAL.md](LEGAL.md) first.** Authorized testing only.

---

## Why OneShot fits a rooted Pixel

OneShot does **not** need monitor mode or packet injection — it drives WPS /
Pixie-Dust through `wpa_supplicant` on a normal *managed* interface, so the
phone's **internal `wlan0`** works with no external USB adapter.

| # | Requirement | Pixel 2024 (rooted) |
|---|-------------|---------------------|
| 1 | **Root** (`su`) | ✅ |
| 2 | Monitor mode / injection | ❌ not needed |
| 3 | External USB adapter | ❌ not required (internal `wlan0`) |
| 4 | **arm64 binaries** (`python3`, `wpa_supplicant`, `pixiewps`, `iw`) | auto-downloaded in `payload.zip` |

> OneShot starts its own `wpa_supplicant`; Android's Wi‑Fi service also owns
> `wlan0`, so free it first (toggle Wi‑Fi off, or `su -c svc wifi disable`).

---

## UI

A single calm screen (Material 3, slate-teal accent, soft off-white canvas,
bordered cards, generous spacing):

- **Status** — root check with a colored indicator
- **Target & mode** — interface (`-i`), BSSID (`-b`), PIN (`-p`), and attack
  mode (`Auto` / Pixie-Dust `-K` / Bruteforce `-B` / Push-button `--pbc`)
- **Advanced options** — a collapsible panel exposing the payload download URL
  plus **every** remaining OneShot parameter: delay (`-d`), vuln-list
  (`--vuln-list`), and toggles for `-F`, `-X`, `-w`, `--iface-down`, `-l`,
  `-r`, `--mtk-wifi`, `-v`
- **Setup** — payload status with a download progress bar (automatic; a
  re-download button is available as a fallback)
- **Console** — a live, monospace **command preview** plus a dark,
  auto-scrolling, color-coded log with Start / Stop

On launch the app **automatically** checks root and downloads + installs the
payload if it isn't already present. All settings are **persisted** (via
`shared_preferences`) and restored on next launch.

---

## Project layout

```
lib/
  main.dart                 app + theme entry
  theme.dart                calm Material 3 theme
  root_shell.dart           run commands via su, stream output
  payload_manager.dart      download payload.zip -> support dir + chmod
  oneshot_settings.dart     all OneShot params + persistence + arg building
  oneshot_controller.dart   state, auto-setup, run/stop (ChangeNotifier)
  screens/home_screen.dart  the UI
  widgets/console_view.dart auto-scrolling log console
scripts/setup_android.sh    generate android/ host + inject permissions
scripts/build_payload.sh    auto-build dist/payload.zip (Termux aarch64) + publish
```

The Android host folder (`android/`) is **not committed** —
`scripts/setup_android.sh` generates it and adds permissions automatically.

---

## Build the APK

```bash
# 0. Install Flutter (https://docs.flutter.dev) and an Android SDK.

# 1. Generate the android/ host + permissions (automatic, idempotent).
./scripts/setup_android.sh

# 2. Fetch packages and build. (No binaries needed here — small APK.)
flutter pub get
flutter build apk --release
#   -> build/app/outputs/flutter-apk/app-release.apk
```

### One-time: publish the payload the app downloads (fixes the runtime 404)
`scripts/build_payload.sh` builds `dist/payload.zip` **fully automatically** —
it pulls the aarch64 binaries (python3, pixiewps, wpa_supplicant, iw + their
libs and the Python stdlib) from the Termux apt repo with dependency
resolution, adds `oneshot.py`, and zips it. No device or manual copying.

```bash
# build only:
./scripts/build_payload.sh

# build AND publish to a GitHub release (so the default URL resolves):
PUBLISH=1 TAG=v0.1.0 ./scripts/build_payload.sh
```

**Or fully automatic via CI:** push a tag and GitHub Actions builds + publishes
the payload for you (no local steps):
```bash
git tag v0.1.0 && git push origin v0.1.0   # triggers .github/workflows/release.yml
```
(Also runnable from the Actions tab via *workflow_dispatch*.)
The app's default download URL is
`https://github.com/AzizDXT/Wifite2-app/releases/latest/download/payload.zip`
(editable in **Advanced options**). The binaries are launched with
`LD_LIBRARY_PATH`/`PYTHONHOME` pointed at the extracted `lib/`.

### Install on the rooted Pixel
```bash
flutter install            # or: adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## Run (everything automatic)

1. Open the app — it **auto-checks root** and **auto-downloads + installs** the
   payload (progress shown in Setup).
2. Free `wlan0` (Wi‑Fi off, or `su -c svc wifi disable`).
3. Pick the interface (`wlan0`) and attack mode → **Start**.
4. Watch the console; **Stop** kills OneShot and its `wpa_supplicant`.

---

## CI/CD

`.github/workflows/ci.yml` runs on every push/PR (and manually via
*workflow_dispatch*):

- **analyze** — `flutter pub get`, format check (informational), `flutter
  analyze`, and `flutter test` (widget smoke test).
- **build-apk** — runs `scripts/setup_android.sh` to generate the host + add
  permissions, builds a debug APK, and uploads it as an artifact. The APK is
  functional once the runtime `payload.zip` is published (see above).

## How it works

On launch `OneShotController.autoSetup()` checks root and, if the payload is
missing, `PayloadManager` downloads `payload.zip` (with progress), unzips it
into the app's private support dir, and `chmod 755` the binaries (Android can't
exec from read-only locations). Start then runs
`su -c "python3 oneshot.py …"` — built from the persisted `OneShotSettings` —
and streams stdout/stderr into the console via `dart:io` `Process`. OneShot
runs as **root**, letting it spawn `wpa_supplicant` and run `pixiewps`.
