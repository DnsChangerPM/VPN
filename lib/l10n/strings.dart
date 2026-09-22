class S {
  S(this.languageCode);
  final String languageCode;
  bool get isFa => languageCode == 'fa';

  String get appName => 'VoidrauVPN';
  String get brandSubtitle => isFa ? 'شبکه خصوصی' : 'Private network';
  String get navConnect => isFa ? 'اتصال' : 'Connect';
  String get navConfig => isFa ? 'پیکربندی' : 'Configurations';
  String get navSettings => isFa ? 'تنظیمات' : 'Settings';
  String get navDiag => isFa ? 'عیب‌یابی' : 'Diagnostics';
  String get navAbout => isFa ? 'درباره' : 'About';

  String get connect => isFa ? 'اتصال' : 'CONNECT';
  String get disconnect => isFa ? 'قطع اتصال' : 'DISCONNECT';
  String get tapToSecure => isFa ? 'برای امنیت لمس کنید' : 'Tap to secure';
  String get ready => isFa ? 'آماده اتصال' : 'Ready';
  String get active => isFa ? 'محافظت فعال' : 'Protected';
  String get connecting => isFa ? 'در حال اتصال…' : 'Connecting…';
  String get scanning => isFa ? 'در حال اسکن…' : 'Scanning…';
  String get reconnecting => isFa ? 'اتصال مجدد…' : 'Reconnecting…';
  String get disconnecting => isFa ? 'در حال قطع…' : 'Disconnecting…';
  String get error => isFa ? 'خطای اتصال' : 'Connection error';
  String get preparing => isFa ? 'آماده‌سازی مسیر امن' : 'Preparing a secure route';

  String get download => isFa ? 'دانلود' : 'Download';
  String get upload => isFa ? 'آپلود' : 'Upload';
  String get ping => isFa ? 'پینگ' : 'Ping';
  String get location => isFa ? 'موقعیت' : 'Location';

  String get mode => isFa ? 'حالت اتصال' : 'Connection mode';
  String get deviceVpn => isFa ? 'VPN دستگاه' : 'Device VPN';
  String get socksProxy => isFa ? 'پروکسی SOCKS5' : 'SOCKS5 proxy';
  String get protocol => isFa ? 'پروتکل' : 'Protocol';
  String get scan => isFa ? 'حالت اسکن' : 'Scan mode';
  String get obfuscation => isFa ? 'استتار' : 'Obfuscation';
  String get transport => isFa ? 'انتقال MASQUE' : 'MASQUE transport';
  String get endpoint => isFa ? 'نقطه پایانی سفارشی' : 'Custom endpoint';
  String get ipVersion => isFa ? 'نسخه IP' : 'IP version';
  String get autoReconnect => isFa ? 'اتصال مجدد خودکار' : 'Quick reconnect';
  String get autoReconnectHelp => isFa
      ? 'استفاده از آخرین دروازه سالم'
      : 'Reuse the last known-good gateway';
  String get fragment => isFa ? 'فرگمنت TLS' : 'TLS fragmentation';
  String get fragmentHelp => isFa
      ? 'فقط برای MASQUE روی HTTP/2'
      : 'MASQUE HTTP/2 ClientHello splitting';
  String get autoConnect => isFa ? 'اتصال هنگام شروع' : 'Connect at launch';
  String get killSwitch => isFa ? 'مسدودسازی هنگام خطا' : 'Fail closed';
  String get killSwitchHelp =>
      isFa ? 'قطع ترافیک تا بازیابی تونل' : 'Block traffic while recovering';
  String get privateDns => isFa ? 'DNS خصوصی' : 'Private DNS';
  String get lanShare => isFa ? 'اشتراک در شبکه محلی' : 'Allow LAN clients';
  String get lanShareHelp => isFa
      ? 'گوش دادن SOCKS روی همه رابط‌ها — فقط شبکه مورد اعتماد'
      : 'Bind SOCKS on all interfaces — trusted LAN only';
  String get splitTitle => isFa ? 'تونل تفکیکی' : 'Split tunneling';
  String get splitHelp => isFa
      ? 'انتخاب برنامه‌هایی که از VPN استفاده کنند'
      : 'Choose which apps use the VPN';
  String get splitOff => isFa ? 'همه برنامه‌ها' : 'All apps';
  String get splitInclude => isFa ? 'فقط انتخاب‌شده' : 'Only selected';
  String get splitExclude => isFa ? 'به‌جز انتخاب‌شده' : 'Bypass selected';

  String get appearance => isFa ? 'ظاهر' : 'Appearance';
  String get themeSystem => isFa ? 'سیستم' : 'System';
  String get themeDark => isFa ? 'تیره' : 'Dark';
  String get themeLight => isFa ? 'روشن' : 'Light';
  String get language => isFa ? 'زبان' : 'Language';
  String get notifications => isFa ? 'اعلان‌ها' : 'Notifications';
  String get updates => isFa ? 'به‌روزرسانی' : 'Updates';
  String get autoUpdates => isFa ? 'بررسی خودکار' : 'Automatic checks';
  String get autoUpdatesHelp => isFa
      ? 'هنگام اجرا، بازگشت به برنامه و پیش از هر اتصال بررسی می‌شود'
      : 'Checked on launch, on resume and before every connection';
  String get currentVersion => isFa ? 'نسخه فعلی' : 'Current version';
  String get latestVersion => isFa ? 'آخرین نسخه' : 'Latest version';
  String get checkUpdates => isFa ? 'بررسی به‌روزرسانی' : 'Check for updates';
  String get downloadUpdate => isFa ? 'دانلود به‌روزرسانی' : 'Download update';
  String get openRelease => isFa ? 'مشاهده در تلگرام' : 'Open Telegram channel';
  String get upToDate => isFa ? 'برنامه به‌روز است' : 'You are up to date';
  String get updateAvailable => isFa ? 'نسخه جدید آماده است' : 'Update available';
  String get updateFailed => isFa ? 'بررسی ناموفق بود' : 'Update check failed';
  String get checking => isFa ? 'در حال بررسی…' : 'Checking…';
  String get updateChannel => isFa ? 'کانال انتشار نسخه‌ها' : 'Release channel';

  String get logs => isFa ? 'گزارش زنده' : 'Live log';
  String get clearLogs => isFa ? 'پاک کردن' : 'Clear';
  String get copyLogs => isFa ? 'کپی' : 'Copy';
  String get testConnection => isFa ? 'تست اتصال' : 'Test connection';
  String get recover => isFa ? 'بازیابی شبکه' : 'Recover network';

  String get aboutTitle => isFa ? 'درباره' : 'About';
  String get aboutCore => isFa ? 'هسته تونل' : 'Tunnel core';
  String get aboutCoreCredit => isFa
      ? 'موتور داخلی برنامه — MASQUE، WireGuard، gool و MASQUE×2.'
      : 'The engine built into the app — MASQUE, WireGuard, gool and MASQUE×2.';
  String get aboutApp => isFa ? 'برنامه: VoidrauVPN' : 'Application: VoidrauVPN';
  String get aboutAppCredit => isFa
      ? 'کلاینت فلاتر برای ویندوز ۸.۱ تا ۱۱ و اندروید ۷ به بالا.'
      : 'Flutter client for Windows 8.1–11 and Android 7+.';
  String get aboutChannel => isFa ? 'کانال تلگرام' : 'Telegram channel';
  String get aboutChannelCredit => isFa
      ? 'نسخه‌های جدید، توضیحات انتشار و پشتیبانی در کانال تلگرام منتشر می‌شود.'
      : 'New versions, release notes and support are posted on the Telegram channel.';
  String get telegram => isFa ? 'کانال تلگرام' : 'Telegram channel';
  String get telegramShort => 'Telegram';
  String get openTelegram => isFa ? 'باز کردن کانال تلگرام' : 'Open Telegram channel';
  String get reset => isFa ? 'بازنشانی پیش‌فرض' : 'Reset defaults';
  String get apply => isFa ? 'اعمال' : 'Apply';
  String socksHint(int port) => isFa
      ? 'پروکسی محلی: 127.0.0.1:$port'
      : 'Local proxy: 127.0.0.1:$port';
  String get statusReady => isFa ? 'آماده' : 'Ready';
  String get lanUser => isFa ? 'کاربر LAN' : 'LAN user';
  String get lanPass => isFa ? 'رمز LAN' : 'LAN password';
  String get logLevel => isFa ? 'سطح گزارش' : 'Log level';
  String get detecting => isFa ? 'در حال تشخیص موقعیت…' : 'Detecting location…';
  String get needVpnPerm => isFa
      ? 'اجازه VPN سیستم لازم است'
      : 'System VPN permission is required';
  String get needAdmin => isFa
      ? 'برای VPN سراسری ویندوز، برنامه را به‌صورت Administrator اجرا کنید'
      : 'System-wide Windows VPN needs Administrator rights';
  String get deviceVpnHint => isFa
      ? 'برای VPN دستگاه (عبور همه برنامه‌ها از تونل)، برنامه باید Administrator باشد'
      : 'A device VPN (every app through the tunnel) needs VoidrauVPN to run as Administrator';
  String get restartAsAdmin => isFa
      ? 'اجرا به‌صورت Administrator'
      : 'Run as Administrator';
  String get elevationRefused => isFa
      ? 'ارتقای دسترسی انجام نشد — پنجره UAC رد شد یا در دسترس نیست'
      : 'Elevation did not happen — the UAC prompt was declined or unavailable';
  String get windowsVersion => isFa ? 'ویندوز' : 'Windows';
  String get elevated => isFa ? 'دسترسی Administrator' : 'Administrator';
  String get tunBackend => isFa ? 'پل TUN' : 'TUN bridge';
  String get tunAdapter => isFa ? 'آداپتور WinTUN' : 'WinTUN adapter';
  String get tunBlocked => isFa
      ? 'چرا VPN دستگاه بالا نیامد'
      : 'Why the device VPN is down';
  String get yes => isFa ? 'بله' : 'Yes';
  String get no => isFa ? 'خیر' : 'No';
  String get selectApps => isFa ? 'انتخاب برنامه‌ها' : 'Select applications';
  String get searchApps => isFa ? 'جست‌وجوی برنامه‌ها' : 'Search applications';
  String get selected => isFa ? 'انتخاب‌شده' : 'selected';
  String get selectAll => isFa ? 'انتخاب همه' : 'Select all';
  String get clearAll => isFa ? 'پاک کردن همه' : 'Clear all';
  String get addExe => isFa ? 'افزودن مسیر برنامه' : 'Add executable path';
  String get duration => isFa ? 'مدت اتصال' : 'Duration';
  String get copyProxy => isFa ? 'کپی آدرس پروکسی' : 'Copy proxy address';
  String get copied => isFa ? 'کپی شد' : 'Copied';
  String get tun => isFa ? 'رابط TUN' : 'TUN interface';
  String get exitIp => isFa ? 'آی‌پی خروجی' : 'Exit IP';
  String get exitCountry => isFa ? 'کشور خروجی' : 'Exit country';
  String get tunnelIp => isFa ? 'آی‌پی تونل' : 'VPN IP';
  String get ipCopied => isFa ? 'آی‌پی کپی شد' : 'IP copied';
  String get copyIp => isFa ? 'کپی آی‌پی' : 'Copy IP';
  String get coreVersion => isFa ? 'هسته تونل' : 'Tunnel core';
  String get tunnel => isFa ? 'تونل' : 'Tunnel';
  String get refresh => isFa ? 'نوسازی' : 'Refresh';
  String get downloading => isFa ? 'در حال دانلود…' : 'Downloading…';
  String get install => isFa ? 'نصب' : 'Install';
  String get verifying => isFa ? 'در حال بررسی صحت فایل…' : 'Verifying file…';
  String get shaMismatch => isFa ? 'هش فایل مطابقت ندارد' : 'File hash mismatch';
  String get lanAddress => isFa ? 'آدرس اشتراک LAN' : 'LAN listen address';
  String get battery => isFa ? 'بهینه‌سازی باتری' : 'Battery optimization';
  String get batteryHelp => isFa
      ? 'برای اتصال پایدار، بهینه‌سازی باتری را برای VoidrauVPN خاموش کنید'
      : 'Disable battery optimization so the tunnel can stay up';
  String get vpnSettings => isFa ? 'تنظیمات VPN سیستم' : 'System VPN settings';
  String get scanTurbo => isFa ? 'سریع' : 'Turbo';
  String get scanBalanced => isFa ? 'متعادل' : 'Balanced';
  String get scanThorough => isFa ? 'عمیق' : 'Thorough';
  String get scanStealth => isFa ? 'پنهان' : 'Stealth';
  String get scanIronclad => isFa ? 'قطعی' : 'Ironclad';
  String get freeNote => isFa
      ? 'کاملاً رایگان و متن‌باز. بدون حساب کاربری و بدون محدودیت ترافیک.'
      : 'Free and open source. No account and no traffic quota.';
  String get bypassLan => isFa ? 'دور زدن شبکه محلی' : 'Bypass LAN';
  String get bypassLanHelp => isFa
      ? 'ترافیک 192.168/10/172.16 از تونل نرود'
      : 'Keep RFC1918 LAN off the tunnel';
  String get ipv6Tunnel => isFa ? 'تونل IPv6' : 'Tunnel IPv6';
  String get watchdog => isFa ? 'نگهبان اتصال' : 'Connection watchdog';
  String get watchdogHelp => isFa
      ? 'اگر هسته افتاد، خودش دوباره وصل شود'
      : 'Reconnect automatically if the core drops';
  String get advanced => isFa ? 'پیشرفته' : 'Advanced';
  String get socksPort => isFa ? 'پورت SOCKS' : 'SOCKS port';
  String get keepalive => isFa ? 'Keepalive (ثانیه)' : 'Keepalive (seconds)';
  String get tunMtu => 'TUN MTU';
  String get stallTimeout => isFa ? 'مهلت ایست (ثانیه)' : 'Stall timeout (seconds)';
  String get orbStyle => isFa ? 'سبک دکمه اتصال' : 'Orb style';
  String get orbClassic => isFa ? 'کلاسیک' : 'Classic';
  String get orbMercury => isFa ? 'جیوه زنده' : 'Living mercury';
  String get autoDownload => isFa ? 'دانلود خودکار به‌روزرسانی' : 'Auto-download updates';
  String get qsTile => isFa
      ? 'کاشی تنظیمات سریع و ویجت صفحه اصلی را از لانچر اضافه کنید'
      : 'Add the Quick Settings tile and home widget from your launcher';

  // ── forced update ──────────────────────────────────────────────────────────
  String get updateRequiredTitle => isFa
      ? 'نسخه جدید منتشر شده است'
      : 'A new version is out';
  String get updateRequiredHeadline => isFa
      ? 'این نسخه غیرفعال شده است'
      : 'This version has been disabled';
  String get updateRequiredBody => isFa
      ? 'به‌محض انتشار نسخه جدید، نسخه‌های قبلی از کار می‌افتند. برای ادامه استفاده، نسخه جدید VoidrauVPN را نصب کنید.'
      : 'As soon as a new release is published, older versions stop working. Install the new VoidrauVPN build to keep using it.';
  String get updateRequiredTelegramLead => isFa
      ? 'فایل نصبی و توضیحات کامل نسخه جدید در کانال تلگرام منتشر می‌شود:'
      : 'The installer and the full release notes are published on the Telegram channel:';
  String get updateStep1 => isFa
      ? 'وارد کانال تلگرام شوید'
      : 'Open the Telegram channel';
  String get updateStep2 => isFa
      ? 'آخرین نسخه VoidrauVPN را از کانال دانلود کنید'
      : 'Download the latest VoidrauVPN build from the channel';
  String get updateStep3 => isFa
      ? 'فایل را نصب کنید و برنامه را دوباره باز کنید'
      : 'Install it and reopen the app';
  String get releaseNotes => isFa ? 'توضیحات نسخه' : 'Release notes';
  String get checkAgain => isFa ? 'بررسی مجدد' : 'Check again';
  String get updatedToContinue => isFa
      ? 'پس از نصب نسخه جدید، اتصال دوباره فعال می‌شود'
      : 'Connecting is re-enabled once the new version is installed';
  String get directDownload => isFa
      ? 'دانلود از کانال تلگرام'
      : 'Download from Telegram channel';
  String get downloadFromChannel => isFa
      ? 'نصب از کانال تلگرام'
      : 'Install from the Telegram channel';
  String get versionOutdated => isFa ? 'نسخه قدیمی' : 'Outdated version';

  // ── exit country ─────────────────────────────────────────────────────────
  String get exitFilter => isFa ? 'کشور آی‌پی خروجی' : 'Exit IP country';
  String get exitFilterHelp => isFa
      ? 'پس از اتصال، کشور آی‌پی خروجی بررسی می‌شود؛ اگر مطابق انتخاب شما نبود، تونل بسته و مسیر دیگری امتحان می‌شود.'
      : 'After connecting, the exit IP\'s country is checked; if it is not the one you want, the tunnel is redialled on another route.';
  String get exitOff => isFa ? 'هر کشوری' : 'Any country';
  String get exitNonIran => isFa ? 'هر آی‌پی غیر ایران' : 'Any IP but Iran';
  String get exitPreferred => isFa ? 'کشور دلخواه' : 'Preferred country';
  String get exitAny => isFa ? 'هر کشوری' : 'any country';
  String get exitAnyExcept => isFa ? 'هر کشور به‌جز' : 'any country except';
  String get exitPreferredCountries =>
      isFa ? 'کشورهای ترجیحی' : 'Preferred countries';
  String get exitBlockedCountries => isFa ? 'کشورهای حذف‌شده' : 'Excluded countries';
  String get exitAskAfter => isFa ? 'پرسش پس از (دقیقه)' : 'Ask after (minutes)';
  String exitSearching(String rule, String seen, int tries, int maxTries) {
    final t = '$tries/$maxTries';
    if (isFa) {
      return seen.isEmpty
          ? 'جست‌وجوی خروجی $rule — تلاش $t'
          : 'خروجی $rule می‌خواهیم؛ تاکنون: $seen — تلاش $t';
    }
    return seen.isEmpty
        ? 'Looking for an exit in $rule — attempt $t'
        : 'Wanted exit: $rule; seen so far: $seen — attempt $t';
  }

  String exitPromptTitle(String rule) => isFa
      ? 'هنوز دنبال آی‌پی $rule هستیم'
      : 'Still looking for an IP in $rule';
  String exitPromptBody(int minutes, String rule, int tries) => isFa
      ? '$minutes دقیقه است که برای خروجی «$rule» اسکن می‌کنیم ($tries تلاش). ادامه بدهیم یا به همان آی‌پی ایران وصل شویم؟'
      : 'We have been scanning for $minutes minutes for an exit matching "$rule" ($tries attempts). Keep looking, or connect with the Iran IP instead?';
  String get exitKeepScanning => isFa ? 'ادامه اسکن' : 'Keep scanning';
  String get exitUseIran => isFa ? 'اتصال با آی‌پی ایران' : 'Connect with the Iran IP';
  String exitNotFound(String rule) => isFa
      ? 'خروجی $rule پیدا نشد — کشور آی‌پی خروجی را در پیکربندی تغییر دهید'
      : 'No exit matching $rule was found — change the exit IP country in Configurations';

  // ── WireGuard hint (first launch) ────────────────────────────────────────
  String get wgHintTitle => isFa
      ? 'پیشنهاد برای اینترنت ایران'
      : 'Recommendation for Iran';
  String get wgHintBody => isFa
      ? 'برای اینترنت ایران، پروتکل WireGuard معمولاً پایدارتر و سریع‌تره:\n\n'
          '• مصرف باتری و دیتای کمتر نسبت به MASQUE\n'
          '• اتصال سریع‌تر و پینگ پایین‌تر\n'
          '• عبور بهتر از فیلترینگ‌های سنگین\n'
          '• مناسب برای تماس، بازی و استریم\n\n'
          'حالت پیش‌فرض برنامه روی «هر کشوری» (Any Country) تنظیم شده تا سریع وصل بشه. '
          'اگر می‌خوای بهترین تجربه رو برای نت ایران داشته باشی، پروتکل رو روی WireGuard بذار.\n\n'
          'می‌تونی بعداً از بخش پیکربندی هم پروتکل رو تغییر بدی.'
      : 'For Iranian networks, WireGuard is usually more stable and faster:\n\n'
          '• Lower battery and data usage than MASQUE\n'
          '• Faster handshake and lower ping\n'
          '• Better bypass on heavily filtered networks\n'
          '• Great for calls, gaming and streaming\n\n'
          'Default exit is set to \"Any Country\" for fastest connection. '
          'If you want the best experience on Iran networks, switch protocol to WireGuard.\n\n'
          'You can change protocol anytime in Configurations.';
  String get wgHintUseWg => isFa ? 'استفاده از وایرگارد' : 'Use WireGuard';
  String get wgHintSkip => isFa ? 'رد کردن' : 'Skip';
  String get wgHintDontShow => isFa ? 'دیگه نشون نده' : "Don't show again";
  String get wgHintApplied => isFa
      ? 'پروتکل روی WireGuard تنظیم شد'
      : 'Protocol set to WireGuard';
}
