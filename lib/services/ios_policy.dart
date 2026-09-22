import '../models/settings.dart';

/// iOS capabilities are intentionally narrower than Android's. Keep this pure
/// so imported/stored settings and unsupported UI options can be regression tested.
class IosPolicy {
  static void normalize(VpnSettings settings) {
    settings.mode = ConnectionMode.vpn;
    settings.lanShare = false;
    settings.splitMode = SplitMode.off;
    settings.splitApps = const [];
    settings.privateDns = true; // Tunnel-scoped DNS, never the physical interface.
    settings.autoDownload = false;
    settings.autoUpdate = false; // TestFlight / App Store owns distribution.
  }

  static String help(bool fa) => fa
      ? 'در iOS اتصال از طریق افزونهٔ VPN سیستم انجام می‌شود. حالت پروکسی مستقل، اشتراک LAN و انتخاب اپ‌ها پشتیبانی نمی‌شوند. DNS از تونل عبور می‌کند. قطع اضطراری تابع محدودیت‌های iOS است و Always-On سازمانی نیست. اتصال خودکار فقط هنگام بازکردن اپ اجرا می‌شود.'
      : 'iOS uses a system VPN extension. Standalone proxy, LAN sharing and per-app selection are unavailable. DNS uses the tunnel. Kill switch follows iOS restrictions; it is not supervised Always-On VPN. Auto-connect runs when opening the app.';
}
