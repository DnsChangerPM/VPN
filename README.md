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
| Device VPN | `VpnService` + [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) 2.17.1 | WinTUN + tun2socks (Administrator) |
| Proxy | SOCKS5 `127.0.0.1:1819` (configurable) | SOCKS5 `127.0.0.1:1819` (configurable) |
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

---

## فارسی

کلاینت مستقل فلاتر برای هسته [Aether](https://github.com/CluvexStudio/Aether) با رابط شبیه [AetherGUI](https://github.com/hamvex/AetherGUI).

- **اندروید ۷ به بالا** و **ویندوز ۸.۱ تا ۱۱**
- هسته Aether ۲.۰.۰
- VPN سراسری یا پروکسی SOCKS5 روی `127.0.0.1:1819`
- اتصال هوشمند، MASQUE، WireGuard، gool، MASQUE×2
- اطلاع‌رسانی به‌روزرسانی از GitHub Releases همین مخزن

برای ساخت APK و EXE: در GitHub Actions ورک‌فلو **Release APK and EXE** را Run کنید. قبل از اجرا **نسخه برنامه** (مثلاً `1.0.0`) از شما پرسیده می‌شود. فایل‌ها در Releases ظاهر می‌شوند.

---

## Credits

- [CluvexStudio/Aether](https://github.com/CluvexStudio/Aether) — tunnel core
- [hamvex/AetherGUI](https://github.com/hamvex/AetherGUI) — UX reference
- [heiher/hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) — Android TUN bridge
- [xjasonlyu/tun2socks](https://github.com/xjasonlyu/tun2socks) + [WinTUN](https://www.wintun.net/) — Windows TUN bridge
