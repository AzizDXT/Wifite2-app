# Wifite2-app — Android (APK) wrapper for wifite2

An Android app that bundles the [wifite2](https://github.com/kimocoder/wifite2)
Python tool plus the ARM tool-binaries it shells out to, extracts them at
runtime, and runs wifite **as root** against an external monitor-mode adapter —
streaming its output to a live terminal view. This is the NetHunter-style
approach: the APK is a *launcher/container* for wifite, not a reimplementation.

> ⚠️ **Read [LEGAL.md](LEGAL.md) first.** Authorized testing only.

---

## ❗ Hard requirements (read before you build)

An APK **cannot** create wireless capabilities that the hardware/firmware
doesn't expose. For wifite to actually work you need **all** of:

| # | Requirement | Your case (Pixel 2024, rooted) |
|---|-------------|--------------------------------|
| 1 | **Root** (`su`) | ✅ you have it |
| 2 | **Monitor mode + packet injection** | ❌ the Pixel's *internal* Wi‑Fi firmware does **not** support it |
| 3 | **External USB‑C OTG adapter** that does | ⬅️ **you must add this** — e.g. Alfa AWUS036ACM (MT7612U) or an RTL8812AU dongle. It shows up as `wlan1`. |
| 4 | **arm64 tool binaries** bundled in the APK | produced by `scripts/prepare_assets.sh` (see below) |

Without #2/#3 the app will launch and run wifite, but wifite will report it
can't put the interface into monitor mode. **The external adapter is not
optional on a Pixel.**

---

## Project layout

```
app/                         Android (Kotlin) wrapper
  src/main/java/.../RootShell.kt      run commands via su, stream output
  src/main/java/.../AssetInstaller.kt extract assets/payload -> filesDir
  src/main/java/.../MainActivity.kt   UI: check root / install / start / stop
  src/main/assets/payload/            (generated) wifite + bin/ arm64 tools
scripts/prepare_assets.sh    fetch wifite source + remind you about binaries
```

The `payload/` dir is **git-ignored** — it is built locally, not committed.

---

## Build

### 1. Populate the payload
```bash
./scripts/prepare_assets.sh
```
This clones the wifite source into `app/src/main/assets/payload/`. Then **you**
drop the **arm64** binaries it lists into `payload/bin/` (python3, aircrack-ng,
airodump-ng, aireplay-ng, airmon-ng, reaver, wash, hcxdumptool,
hcxpcapngtool, tshark, iw, ip, hashcat…). Easiest sources: a Kali NetHunter
chroot's `/usr/bin`, or `pkg install` under Termux then copy `$PREFIX/bin` +
the libs they link.

### 2. Build the APK
Open in **Android Studio** (Giraffe+) and Run, or from CLI:
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

1. Plug the **USB‑C Wi‑Fi adapter** into the Pixel (OTG).
2. Open the app → **Check Root** (grant the su prompt).
3. **Install Payload** (extracts wifite + binaries to private storage).
4. Set the interface (usually `wlan1`), add optional args, tap **Start**.
5. Watch the live log; **Stop** sends SIGINT so wifite restores the interface.

Tip: confirm the adapter first from a root shell —
`ip link` should list `wlan1`, and `airmon-ng start wlan1` should succeed.

---

## How it works

- `MainActivity` collects the interface/args and asks `RootShell` to run
  `su -c "python3 Wifite.py -i wlan1 --kill …"`, streaming combined
  stdout/stderr into the on-screen terminal.
- `AssetInstaller` copies the bundled `assets/payload` tree into the app's
  private `filesDir` and `chmod +x` the binaries (Android can't execute
  binaries directly from the read-only APK assets).
- wifite runs as **root** (not as the app uid), which is what lets it drive
  `airmon-ng`/`airodump-ng` against the external adapter.

---

## Why not Chaquopy / pure in-process Python?

Chaquopy can embed Python in the APK, but that interpreter runs as the *app's*
uid — it cannot reconfigure network interfaces. wifite fundamentally needs
**root** and external CLI tools, so we run it through `su` instead. The
trade-off is that you must supply matching **arm64** binaries.
