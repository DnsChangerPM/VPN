# Nimbus VPN

Independent **Flutter** client for the official [CluvexStudio/Aether](https://github.com/CluvexStudio/Aether) core.

The UI and feature set follow [hamvex/AetherGUI](https://github.com/hamvex/AetherGUI) (Aethon): device VPN or local SOCKS5, Smart Connect, MASQUE HTTP/3 & HTTP/2, WireGuard, gool, MASQUE×2, scan modes, obfuscation, split tunneling, diagnostics, Persian/English, and GitHub Releases update checks.

Nimbus is **not** affiliated with CluvexStudio. Aether is a separate project with its own license and trademark.

[English](#english) · [فارسی](#فارسی)

---

## English

### What you get

| | Android | Windows |
| --- | --- | --- |
| UI | Flutter | Flutter (compact 420×780 window) |
| Core | Aether **v2.0.0** `libaether.so` | Aether **v2.0.0** `aether.exe` |
| Device VPN | `VpnService` + [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) 2.17.1 | WinTUN + tun2socks **or** hev-socks5-tunnel (Administrator) |
| Proxy | SOCKS5 `127.0.0.1:1819` (configurable) | SOCKS5 `127.0.0.1:1819` (configurable) + system proxy auto on/off |
| Extras | QS tile, home widget, bypass LAN, MTU/keepalive/watchdog | Bypass LAN routes, keepalive, MTU, watchdog |
| Minimum OS | **Android 7.0** (API 24) | **Windows 8.1** (6.3) through 11, x64 |
| Updates | GitHub Releases API | GitHub Releases API |

### Download

GitHub Actions → **Release APK and EXE** → **Run workflow**. The form asks for:

- **App version** (required, example `1.2.0`) — this is the version baked into the APK/EXE and the GitHub Release tag
- **Release notes** (optional)
- **Pre-release** (optional)

Pushing a `v1.2.0` tag also publishes. Artifacts:

- `Nimbus-VPN-vX.Y.Z-Android-Universal.apk`
- `Nimbus-VPN-vX.Y.Z-Android-arm64-v8a.apk` / `armeabi-v7a` / `x86_64`
- `Nimbus-VPN-vX.Y.Z-Android.aab`
- `Nimbus-VPN-vX.Y.Z-Windows-x64-Installer.exe`
- `Nimbus-VPN-vX.Y.Z-Windows-x64-Portable.zip`
- `SHA256SUMS.txt`

The in-app updater downloads these files, checks SHA-256 when GitHub provides a digest, and hands the APK/EXE to the system installer.

The in-app updater reads:

```text
https://api.github.com/repos/DnsChangerPM/VPN/releases/latest
```

### Build locally

```bash
# Flutter 3.27+, Android SDK/NDK, Windows 10 SDK for the desktop target
./scripts/bootstrap.sh
bash scripts/fetch_cores.sh
# Android JNI bridge
bash scripts/build_hev.sh
flutter pub get
flutter test
flutter build apk --release
flutter build windows --release   # on Windows
```

Android 7–latest is `minSdk 24`. Windows 8.1 support is requested in the installer (`MinVersion=6.3`) and the runner (`WINVER=0x0603`). Install the [VC++ 2015–2022 x64 redistributable](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist) on older PCs.

### Protocols

Smart Connect tries MASQUE H3 → MASQUE H2 → WireGuard → gool → MASQUE×2 (`--mim`). Scan modes: turbo, balanced, thorough, stealth, ironclad. Obfuscation defaults to `firewall` (MASQUE) and `balanced` (WireGuard/gool).

### Windows device VPN: three bridges

A WinTUN adapter needs a userspace bridge to carry SOCKS5 into it, and no
single bridge covers Windows 8.1 → 11, so Nimbus stages all three next to
`nimbus.exe` and picks per machine (`lib/services/windows_tun.dart`):

| Bridge | File | Used on | Why |
| --- | --- | --- | --- |
| tun2socks v2.6.0 | `tun2socks.exe` | Windows 10/11 | Current release, baseline x86-64 |
| tun2socks v2.5.1 | `tun2socks-legacy.exe` | Windows 7/8/8.1 | Last build with **Go 1.20**; Go ≥ 1.21 requires Windows 10+ and dies before creating the adapter |
| hev-socks5-tunnel 2.17.1 | `hev-socks5-tunnel.exe` + `msys-2.0.dll` | any | C bridge, no Go runtime floor |

Two release-time traps this guards against:

- **`-v3` assets.** GitHub lists `tun2socks-windows-amd64-v3.zip` *before*
  `tun2socks-windows-amd64.zip`. A GOAMD64=v3 binary dies with an illegal
  instruction on any pre-Haswell CPU — most Windows 8.1 hardware.
  `scripts/fetch_cores.sh` reads the embedded Go build info and fails the
  release build if a v3 asset (or a too-new Go for the legacy slot) sneaks in.
- **Silent failure.** If no bridge can create the adapter, the app no longer
  says only *WinTUN adapter "Nimbus" never appeared*; it reports each bridge's
  exit status and last output line, falls back to SOCKS5 + system proxy so the
  machine keeps working, and shows the reason on the Diagnostics page.

If the process is not running as Administrator, WinTUN cannot be created at
all: the Connect and Diagnostics pages offer **Run as Administrator**, which
relaunches Nimbus through the UAC prompt instead of leaving you to find the
exe by hand.

### Windows system proxy

On Windows, Nimbus manages the **system proxy** so connect/disconnect fully
controls the proxy flow — no manual steps, no leftovers:

- **SOCKS5 proxy mode** (and the fallback when a non-elevated device VPN can
  only provide SOCKS) → the system proxy is pointed at `127.0.0.1:<port>`
  automatically.
- **Device VPN** (elevated, TUN adapter active) → the system proxy is turned
  **off** automatically; every app rides the TUN adapter directly, with
  nothing to configure.
- **Disconnect** → the exact pre-Nimbus proxy settings (your own proxy, or
  plain "off") are restored and announced to running apps. If the app was
  hard-closed mid-session instead, the next launch removes any leftover proxy
  pointing at Nimbus' listener.

---

## فارسی

کلاینت مستقل فلاتر برای هسته [Aether](https://github.com/CluvexStudio/Aether) با رابط شبیه [AetherGUI](https://github.com/hamvex/AetherGUI).

- **اندروید ۷ به بالا** و **ویندوز ۸.۱ تا ۱۱**
- هسته Aether ۲.۰.۰
- VPN سراسری یا پروکسی SOCKS5 روی `127.0.0.1:1819`
- در ویندوز، پروکسی سیستمی را خود برنامه مدیریت می‌کند: در حالت پروکسی، خودکار به `127.0.0.1:<پورت>` وصل می‌شود؛ در حالت VPN دستگاه، پروکسی سیستمی خاموش می‌شود و همه برنامه‌ها مستقیم از TUN می‌روند؛ هنگام قطع اتصال، تنظیمات قبلی پروکسی برمی‌گردد
- برای VPN دستگاه در ویندوز سه پل کنار برنامه قرار می‌گیرد و بر اساس نسخه ویندوز انتخاب می‌شود: `tun2socks` برای ویندوز ۱۰ و ۱۱، `tun2socks-legacy` (ساخته‌شده با Go 1.20) برای ویندوز ۷/۸/۸.۱، و `hev-socks5-tunnel` به‌عنوان گزینه سوم. اگر هیچ‌کدام آداپتور WinTUN را نسازند، دلیل دقیق (کد خروج و آخرین پیام هر پل) در صفحه عیب‌یابی نمایش داده می‌شود و برنامه به SOCKS5 + پروکسی سیستمی برمی‌گردد تا اینترنت قطع نشود
- اگر برنامه Administrator نباشد، دکمه «اجرا به‌صورت Administrator» در صفحه اتصال و عیب‌یابی برنامه را با UAC دوباره باز می‌کند
- اتصال هوشمند، MASQUE، WireGuard، gool، MASQUE×2
- اطلاع‌رسانی به‌روزرسانی از GitHub Releases همین مخزن

برای ساخت APK و EXE: در GitHub Actions ورک‌فلو **Release APK and EXE** را Run کنید. قبل از اجرا **نسخه برنامه** (مثلاً `1.0.0`) از شما پرسیده می‌شود. فایل‌ها در Releases ظاهر می‌شوند.

---

## Credits

- [CluvexStudio/Aether](https://github.com/CluvexStudio/Aether) — tunnel core
- [hamvex/AetherGUI](https://github.com/hamvex/AetherGUI) — UX reference
- [heiher/hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) — Android TUN bridge
- [xjasonlyu/tun2socks](https://github.com/xjasonlyu/tun2socks) + [WinTUN](https://www.wintun.net/) — Windows TUN bridge
- [heiher/hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) — Windows TUN bridge for builds where the Go runtime cannot run
