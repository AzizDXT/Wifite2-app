# OneShot-app — Flutter (APK) wrapper for OneShot

[![CI](https://github.com/AzizDXT/Wifite2-app/actions/workflows/ci.yml/badge.svg)](https://github.com/AzizDXT/Wifite2-app/actions/workflows/ci.yml)

A **Flutter** Android app with a calm, professional UI that bundles the
[OneShot](https://github.com/kimocoder/OneShot) WPS-attack tool plus the arm64
binaries it needs, extracts them at runtime, and runs OneShot **as root** —
streaming its output to a live console. The APK is a *launcher/container* for
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
| 4 | **arm64 binaries** in the APK | `python3`, `wpa_supplicant`, `pixiewps`, `iw` |

> OneShot starts its own `wpa_supplicant`; Android's Wi‑Fi service also owns
> `wlan0`, so free it first (toggle Wi‑Fi off, or `su -c svc wifi disable`).

---

## UI

A single calm screen (Material 3, slate-teal accent, soft off-white canvas,
bordered cards, generous spacing):

- **Status** — root check with a colored indicator
- **Configuration** — interface, optional target BSSID, attack-mode segmented
  control (Pixie-Dust `-K` / Bruteforce `-B` / PBC `--pbc`)
- **Setup** — one-tap payload install (unzips OneShot + binaries)
- **Console** — dark, auto-scrolling, color-coded log with Start / Stop

---

## Project layout

```
lib/
  main.dart                 app + theme entry
  theme.dart                calm Material 3 theme
  root_shell.dart           run commands via su, stream output
  payload_installer.dart    unzip assets/payload.zip -> support dir + chmod
  oneshot_controller.dart   state + command building (ChangeNotifier)
  screens/home_screen.dart  the UI
  widgets/console_view.dart auto-scrolling log console
assets/payload.zip          (generated) OneShot + arm64 binaries — git-ignored
scripts/prepare_assets.sh   builds payload.zip
```

The Android host folder (`android/`) is **not committed** — generate it once
with `flutter create .` (see below).

---

## Build

```bash
# 0. Install Flutter (https://docs.flutter.dev) and an Android SDK.

# 1. Generate the Android host project (creates android/).
flutter create --org run.taleb --project-name oneshot --platforms=android .

# 2. Build the payload (clones OneShot; you supply the arm64 binaries).
./scripts/prepare_assets.sh

# 3. Fetch packages and build.
flutter pub get
flutter build apk --release
#   -> build/app/outputs/flutter-apk/app-release.apk
```

After `flutter create`, add these to
`android/app/src/main/AndroidManifest.xml` (inside `<manifest>`):
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
```

### Install on the rooted Pixel
```bash
flutter install            # or: adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## Run

1. Open the app → **Check** (grant the su prompt).
2. **Install** the payload.
3. Free `wlan0` (Wi‑Fi off, or `su -c svc wifi disable`).
4. Pick the interface (`wlan0`) and attack mode → **Start**.
5. Watch the console; **Stop** kills OneShot and its `wpa_supplicant`.

---

## CI/CD

`.github/workflows/ci.yml` runs on every push/PR (and manually via
*workflow_dispatch*):

- **analyze** — `flutter pub get`, format check (informational), `flutter
  analyze`, and `flutter test` (widget smoke test).
- **build-apk** — generates the `android/` host on the fly, uses a
  **placeholder** `payload.zip`, builds a debug APK, and uploads it as an
  artifact. This is a *compile-check only* — the CI APK has no real binaries
  and won't function. Build a working APK locally with real arm64 binaries
  (see [Build](#build)).

## How it works

`OneShotController` builds `su -c "python3 oneshot.py -i wlan0 -K …"` and
streams stdout/stderr into the console via `dart:io` `Process`.
`PayloadInstaller` unzips the bundled `assets/payload.zip` into the app's
private support dir and `chmod 755` the binaries (Android can't exec directly
from read-only APK assets). OneShot runs as **root**, letting it spawn
`wpa_supplicant` and run `pixiewps`.
