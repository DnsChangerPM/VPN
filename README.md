# VoidrauVPN

Free, open-source **Flutter** VPN client for **Android 7+** and **Windows 8.1–11** — device-wide VPN or a local SOCKS5 proxy, powered by a modern multi-protocol tunnel core.

Telegram channel (releases, install files, notes and support): **[t.me/Voidrau](https://t.me/Voidrau)**

[English](#english) · [فارسی](#فارسی)

---

## English

### What you get

| | Android | Windows |
| --- | --- | --- |
| UI | Flutter | Flutter (compact 420×780 window) |
| Device VPN | `VpnService` + userspace TUN bridge | WinTUN adapter + one of three staged bridges |
| Proxy | SOCKS5 `127.0.0.1:1819` (configurable) | SOCKS5 `127.0.0.1:1819` (configurable) + system-proxy automation |
| Protocols | Smart Connect: MASQUE HTTP/3 → MASQUE HTTP/2 → WireGuard → gool → MASQUE×2 | same |
| Extras | Quick Settings tile, home-screen widget, LAN sharing, split tunneling, MTU/keepalive/watchdog, battery-optimization helper | Bypass-LAN routes, system-proxy save/restore, keepalive, MTU, watchdog, one-tap “run as Administrator” |
| Language | Persian & English (RTL aware) | Persian & English |
| Exit info | Country flag + exit IP card after connecting | Country flag + exit IP card after connecting |
| Exit country | Choose it: any IP but Iran, or a preferred country (Germany by default) | same |
| Minimum OS | Android 7.0 (API 24) | Windows 8.1 (6.3), x64 |

### Exit country: pick where you land

The tunnel core chooses its own gateway, so the exit country cannot be
requested as a launch parameter. The client enforces it instead:

- **Configurations → Exit IP country** offers *Any country*, *Any IP but Iran*
  (the default) and *Preferred country* (Germany first, then any country except
  Iran; both lists are editable with flag chips).
- After the core reports `connected`, the exit IP is looked up through the
  tunnel itself (Cloudflare trace, geo API as fallback). If the country does not
  match, the tunnel is torn down and re-dialled — walking the protocol ladder
  and flipping the MASQUE carrier between HTTP/3 and HTTP/2, because a different
  carrier means a different gateway pool.
- The status line reports the search: which countries have already been
  rejected and which attempt is running.
- If the search takes longer than the configured patience (3 minutes by
  default, editable), the app asks instead of spinning on: **Keep scanning** or
  **Connect with the Iran IP**. The second choice switches the rule off and
  redials the gateway that already produced that exit, so it is back in seconds
  rather than after a fresh scan. Choosing *Keep scanning* brings the question
  back after another interval.
- An exit whose country cannot be determined is accepted, so a broken geo
  lookup can never become an endless re-dial loop.

### Mandatory updates

When a new version is published, **older builds stop working immediately**:

- the app checks the release feed on launch, when it returns to the foreground and before every connection;
- as soon as a newer release exists, the tunnel is torn down, connecting is refused and the app switches to a full-screen notice;
- that notice links straight to the Telegram channel for the installer and the release notes — install the new version and the app works again;
- the state is stored locally, so even starting the app offline cannot bring a retired version back to life.

### Where the releases live

Installers and notes are published on the [Telegram channel](https://t.me/Voidrau) and as GitHub Releases of this repository (`https://github.com/AnishtayiN/VoidrauVPN/releases`). The in-app updater reads the latest GitHub Release of this repository.

Build and publish with **GitHub Actions → Release APK and EXE → Run workflow**:

- **App version** (required, e.g. `1.1.0`) — baked into the APK/EXE and used as the release tag
- **Release notes** (optional) — shown on GitHub *and inside the app* on the update screen
- **Pre-release** (optional) — drafts are excluded from the update check

Pushing a `v1.1.0` tag publishes too. Artifacts:

- `VoidrauVPN-vX.Y.Z-Android-Universal.apk`
- `VoidrauVPN-vX.Y.Z-Android-arm64-v8a.apk` / `armeabi-v7a` / `x86_64`
- `VoidrauVPN-vX.Y.Z-Android.aab`
- `VoidrauVPN-vX.Y.Z-Windows-x64-Installer.exe`
- `VoidrauVPN-vX.Y.Z-Windows-x64-Portable.zip`
- `SHA256SUMS.txt`

The updater verifies SHA-256 when GitHub provides a digest, and on Android checks that the downloaded APK carries the same signing certificate as the installed app before handing it to the system installer.

### Build locally

```bash
# Flutter 3.27+, Android SDK/NDK, Windows 10 SDK for the desktop target
./scripts/bootstrap.sh
bash scripts/fetch_cores.sh        # tunnel core + platform sidecars (pinned tags)
bash scripts/build_hev.sh          # Android JNI bridge
flutter pub get
flutter test
flutter build apk --release        # --dart-define=VOIDRAU_VERSION=1.1.0
flutter build windows --release    # on Windows
```

Notes for maintainers:

- `scripts/pins.json` pins every staged binary; the CI job fails if a pin drifts.
- The Android application id is **frozen** (`pm.dnschanger.nimbus`) so a new build upgrades an existing install instead of installing next to it. The user-visible name is `VoidrauVPN` everywhere else.
- The release keystore must stay the same across releases: the updater refuses an APK signed with a different certificate.
- Bundled third-party components and their licenses are listed in [NOTICE.md](NOTICE.md).

### Windows device VPN: three bridges

A WinTUN adapter needs a userspace bridge, and no single bridge covers Windows 8.1 → 11, so the app stages all three next to the executable and picks per machine:

| Bridge | Used on | Why |
| --- | --- | --- |
| current release | Windows 10/11 | baseline x86-64 build |
| legacy build (Go 1.20) | Windows 7/8/8.1 | newer Go runtimes require Windows 10+ and die before creating the adapter |
| C bridge | any | no Go runtime floor |

If no bridge can create the adapter, the app reports each bridge's exit status and last output line, falls back to SOCKS5 + system proxy so the machine keeps working, and shows the reason on the Diagnostics page.

### Windows system proxy

- **SOCKS5 proxy mode** → the system proxy is pointed at `127.0.0.1:<port>` automatically.
- **Device VPN** → the system proxy is turned off; every app rides the TUN adapter.
- **Disconnect** → the exact pre-VoidrauVPN proxy settings are restored. If the app was hard-closed mid-session, the next launch removes any leftover proxy pointing at its listener.

### Troubleshooting

- **Nothing connects.** Try Stealth or Ironclad scan mode, or switch obfuscation to `aggressive`.
- **MASQUE fails on a filtered network.** Smart Connect retries MASQUE over HTTP/2 with TLS fragmentation, which survives QUIC/UDP blocking.
- **Windows device VPN is down.** Run as Administrator (the app offers a one-tap relaunch) and check the Diagnostics page for the bridge error.
- **Android kills the tunnel.** Disable battery optimization for VoidrauVPN (button in Settings → Battery optimization).
- **“This version has been disabled”.** A newer release exists — install it from [t.me/Voidrau](https://t.me/Voidrau).

---

## فارسی

**VoidrauVPN** یک کلاینت وی‌پی‌ان رایگان و متن‌باز با فلاتر برای **اندروید ۷ به بالا** و **ویندوز ۸.۱ تا ۱۱** است؛ با حالت VPN سراسری یا پروکسی SOCKS5 محلی.

کانال تلگرام (فایل نصبی، توضیحات نسخه‌ها و پشتیبانی): **[t.me/Voidrau](https://t.me/Voidrau)**

### امکانات

- اتصال هوشمند: MASQUE روی HTTP/3 → MASQUE روی HTTP/2 → WireGuard → gool → MASQUE×2
- **VPN دستگاه** روی اندروید و ویندوز، یا **پروکسی SOCKS5** روی `127.0.0.1:1819`
- در ویندوز پروکسی سیستمی خودکار مدیریت می‌شود: در حالت پروکسی به پورت محلی وصل می‌شود، در حالت VPN دستگاه خاموش می‌شود و هنگام قطع اتصال تنظیمات قبلی برمی‌گردد
- بعد از اتصال، **پرچم کشور و آی‌پی خروجی** (همان آی‌پی که سایت‌ها می‌بینند) در بالای صفحه نمایش داده می‌شود؛ با یک لمس کپی می‌شود
- **انتخاب کشور آی‌پی خروجی**: «هر آی‌پی غیر ایران» (پیش‌فرض) یا «کشور دلخواه» (آلمان و هر کشور دیگر به‌جز ایران)؛ اگر خروجی مطابق انتخاب شما نباشد، تونل بسته و مسیر دیگری امتحان می‌شود
- اگر جست‌وجوی خروجی بیش از حد تنظیم‌شده (پیش‌فرض ۳ دقیقه) طول بکشد، برنامه می‌پرسد: **ادامه اسکن** یا **اتصال با آی‌پی ایران**
- تونل تفکیکی برنامه‌ها، دور زدن شبکه محلی، اشتراک LAN، DNS خصوصی، MTU، keepalive و نگهبان اتصال
- کاشی تنظیمات سریع و ویجت صفحه اصلی در اندروید
- رابط فارسی و انگلیسی

### به‌روزرسانی اجباری

به‌محض انتشار نسخه جدید، **نسخه‌های قبلی از کار می‌افتند**:

- بررسی انتشار در زمان اجرا، هنگام بازگشت به برنامه و پیش از هر اتصال انجام می‌شود؛
- اگر نسخه جدیدی منتشر شده باشد، تونل فوراً قطع می‌شود، اتصال ممکن نیست و صفحه‌ای تمام‌صفحه با راهنمای نصب نمایش داده می‌شود؛
- آن صفحه مستقیم به کانال تلگرام می‌رود؛ فایل نصبی و توضیحات کامل نسخه آنجا منتشر می‌شود؛
- این وضعیت روی دستگاه ذخیره می‌شود، پس حتی بدون اینترنت هم نسخه قدیمی دوباره فعال نمی‌شود.

### انتشار نسخه

در GitHub Actions ورک‌فلو **Release APK and EXE** را Run کنید؛ **نسخه برنامه** (مثلاً `1.1.0`)، **توضیحات نسخه** (اختیاری — در گیت‌هاب و همچنین در صفحه به‌روزرسانی داخل برنامه نمایش داده می‌شود) و **Pre-release** پرسیده می‌شود. با پوش کردن تگ `v1.1.0` هم انتشار انجام می‌شود.

فایل‌ها: `VoidrauVPN-vX.Y.Z-Android-Universal.apk`، نسخه‌های per-ABI، `VoidrauVPN-vX.Y.Z-Android.aab`، `VoidrauVPN-vX.Y.Z-Windows-x64-Installer.exe`، نسخه Portable و `SHA256SUMS.txt`.

### ساخت محلی

```bash
./scripts/bootstrap.sh
bash scripts/fetch_cores.sh
flutter pub get
flutter test
flutter build apk --release --dart-define=VOIDRAU_VERSION=1.1.0
```

نکته‌ها: شناسه اندروید عمداً ثابت مانده است (`pm.dnschanger.nimbus`) تا نسخه جدید روی نسخه قبلی نصب شود و تنظیمات و امضای برنامه حفظ شود. کلید امضا را بین نسخه‌ها تغییر ندهید؛ برنامه APK با امضای متفاوت را نصب نمی‌کند. فهرست اجزای شخص ثالث در [NOTICE.md](NOTICE.md) است.
