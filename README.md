# OneShot-app — Android (APK) wrapper for OneShot

An Android app that bundles the [OneShot](https://github.com/kimocoder/OneShot)
WPS-attack tool plus the arm64 binaries it needs, extracts them at runtime, and
runs OneShot **as root**, streaming its output to a live terminal view. The APK
is a *launcher/container* for OneShot, not a reimplementation.

> ⚠️ **Read [LEGAL.md](LEGAL.md) first.** Authorized testing only.

---

## Why OneShot is a good fit for a rooted Pixel

Unlike wifite/aircrack, **OneShot does NOT need monitor mode or packet
injection.** It performs the Pixie-Dust / WPS attacks through
`wpa_supplicant` on a normal *managed* interface — so the phone's **internal
`wlan0` works**, no external USB adapter required.

| # | Requirement | Pixel 2024 (rooted) |
|---|-------------|---------------------|
| 1 | **Root** (`su`) | ✅ you have it |
| 2 | Monitor mode / injection | ❌ not needed by OneShot |
| 3 | External USB adapter | ❌ not required (internal `wlan0` is fine) |
| 4 | **arm64 binaries** in the APK | python3, wpa_supplicant, pixiewps, iw — added by `scripts/prepare_assets.sh` |

> Note: OneShot starts its *own* `wpa_supplicant` on the interface. Android's
> system Wi‑Fi service also controls `wlan0`, so you may need to free it first
> (e.g. toggle Wi‑Fi off, or `su -c svc wifi disable`) before tapping Start.

---

## Project layout

```
app/                         Android (Kotlin) wrapper
  src/main/java/.../RootShell.kt      run commands via su, stream output
  src/main/java/.../AssetInstaller.kt extract assets/payload -> filesDir
  src/main/java/.../MainActivity.kt   UI: check root / install / start / stop
  src/main/assets/payload/            (generated) oneshot.py + bin/ arm64 tools
scripts/prepare_assets.sh    fetch OneShot source + remind you about binaries
```

The `payload/` dir is **git-ignored** — built locally, not committed.

---

## Build

### 1. Populate the payload
```bash
./scripts/prepare_assets.sh
```
This clones the OneShot source into `app/src/main/assets/payload/`. Then **you**
drop the **arm64** binaries it lists into `payload/bin/` (`python3`,
`wpa_supplicant`, `pixiewps`, `iw`). Easiest source: install them under Termux
(`pkg install python pixiewps wpa-supplicant iw`) and copy `$PREFIX/bin/*` plus
the `$PREFIX/lib/*.so` they link against.

### 2. Build the APK
Open in **Android Studio** and Run, or from CLI:
```bash
./gradlew assembleDebug
# -> app/build/outputs/apk/debug/app-debug.apk
```
(If there's no `gradlew`, run `gradle wrapper` once, or build via Android Studio.)

### 3. Install on the rooted Pixel
```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

---

## Run

1. Open the app → **Check Root** (grant the su prompt).
2. **Install Payload** (extracts OneShot + binaries to private storage).
3. (If needed) free `wlan0`: turn Wi‑Fi off or `su -c svc wifi disable`.
4. Interface `wlan0`, set flags (default `-K` = Pixie Dust), tap **Start**.
5. Watch the live log; **Stop** kills OneShot and its `wpa_supplicant`.

Common flag combos (put in the Flags field):
- `-K` — interactive Pixie-Dust (pick a target from the scan)
- `-b AA:BB:CC:DD:EE:FF -K` — Pixie-Dust a specific BSSID
- `-b AA:BB:CC:DD:EE:FF -B` — online WPS PIN bruteforce
- `--pbc` — WPS push-button connect

---

## How it works

- `MainActivity` builds `su -c "python3 oneshot.py -i wlan0 -K …"` and streams
  combined stdout/stderr into the on-screen terminal.
- `AssetInstaller` copies the bundled `assets/payload` tree into the app's
  private `filesDir` and `chmod +x` the binaries (Android can't execute
  binaries directly from the read-only APK assets).
- OneShot runs as **root**, which lets it spawn `wpa_supplicant` and run
  `pixiewps` against the target.

---

## Why not Chaquopy / pure in-process Python?

Chaquopy embeds Python in the APK, but that interpreter runs as the *app's*
uid and can't drive `wpa_supplicant` on the interface. OneShot needs **root**
plus the `wpa_supplicant`/`pixiewps`/`iw` CLIs, so we run it through `su` and
ship matching **arm64** binaries.
