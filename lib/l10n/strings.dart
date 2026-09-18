class S {
  S(this.languageCode);
  final String languageCode;
  bool get isFa => languageCode == 'fa';

  String get appName => 'Nimbus VPN';
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
      ? 'هر بار اجرا و هر ۱۲ ساعت از GitHub Releases'
      : 'On launch and every 12 hours from GitHub Releases';
  String get currentVersion => isFa ? 'نسخه فعلی' : 'Current version';
  String get latestVersion => isFa ? 'آخرین نسخه' : 'Latest version';
  String get checkUpdates => isFa ? 'بررسی به‌روزرسانی' : 'Check for updates';
  String get downloadUpdate => isFa ? 'دانلود به‌روزرسانی' : 'Download update';
  String get openRelease => isFa ? 'مشاهده در GitHub' : 'Open GitHub release';
  String get upToDate => isFa ? 'برنامه به‌روز است' : 'You are up to date';
  String get updateAvailable => isFa ? 'نسخه جدید آماده است' : 'Update available';
  String get updateFailed => isFa ? 'بررسی ناموفق بود' : 'Update check failed';
  String get checking => isFa ? 'در حال بررسی…' : 'Checking…';

  String get logs => isFa ? 'گزارش زنده' : 'Live log';
  String get clearLogs => isFa ? 'پاک کردن' : 'Clear';
  String get copyLogs => isFa ? 'کپی' : 'Copy';
  String get testConnection => isFa ? 'تست اتصال' : 'Test connection';
  String get recover => isFa ? 'بازیابی شبکه' : 'Recover network';

  String get aboutTitle => isFa ? 'درباره' : 'About';
  String get aboutCore => isFa ? 'هسته: Aether' : 'Core: Aether';
  String get aboutCoreCredit => isFa
      ? 'موتور شبکه رسمی CluvexStudio/Aether — MASQUE، WireGuard، gool و MASQUE×2.'
      : 'Official CluvexStudio/Aether engine — MASQUE, WireGuard, gool and MASQUE×2.';
  String get aboutApp => isFa ? 'برنامه: Nimbus VPN' : 'Application: Nimbus VPN';
  String get aboutAppCredit => isFa
      ? 'کلاینت مستقل فلاتر برای ویندوز ۸.۱ تا ۱۱ و اندروید ۷ به بالا. الهام‌گرفته از AetherGUI.'
      : 'Independent Flutter client for Windows 8.1–11 and Android 7+. Inspired by AetherGUI.';
  String get telegram => 'Telegram';
  String get reset => isFa ? 'بازنشانی پیش‌فرض' : 'Reset defaults';
  String get apply => isFa ? 'اعمال' : 'Apply';
  String get socksHint => isFa
      ? 'پروکسی محلی: 127.0.0.1:1819'
      : 'Local proxy: 127.0.0.1:1819';
  String get needVpnPerm => isFa
      ? 'اجازه VPN سیستم لازم است'
      : 'System VPN permission is required';
  String get needAdmin => isFa
      ? 'برای VPN سراسری ویندوز، برنامه را به‌صورت Administrator اجرا کنید'
      : 'System-wide Windows VPN needs Administrator rights';
}
