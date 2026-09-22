enum ConnectionMode { vpn, proxy }

enum Protocol { smart, masque, wg, gool, mim }

enum ScanMode { turbo, balanced, thorough, stealth, ironclad }

/// Which exit country a finished tunnel must have before the app accepts it.
///
/// The tunnel core picks its own gateway, so the choice happens on the client:
/// after the core reports `connected`, the exit IP is looked up and the tunnel
/// is torn down and re-dialled when the country does not match.
enum ExitFilter {
  /// Whatever exit the core finds is accepted.
  off,

  /// Any country except [VpnSettings.exitBlocked] (Iran by default).
  nonIran,

  /// [VpnSettings.exitPreferred] first (Germany by default), any other
  /// non-blocked country accepted as a second choice.
  preferred,
}

enum IpVersion { v4, v6, dual }

enum MasqueTransport { h3, h2 }

enum ThemeChoice { system, dark, light }

enum LanguageChoice { system, en, fa }

enum SplitMode { off, include, exclude }

enum OrbStyle { classic, mercury }

class VpnSettings {
  VpnSettings({
    this.mode = ConnectionMode.vpn,
    this.protocol = Protocol.smart,
    this.scan = ScanMode.balanced,
    this.ipVersion = IpVersion.v4,
    this.transport = MasqueTransport.h3,
    this.obfuscation = 'auto',
    this.endpoint = '',
    this.quickReconnect = true,
    this.fragment = false,
    this.autoConnect = false,
    this.killSwitch = true,
    this.privateDns = true,
    this.lanShare = false,
    this.bypassLan = true,
    this.ipv6Tunnel = false,
    this.splitMode = SplitMode.off,
    this.splitApps = const [],
    this.theme = ThemeChoice.dark,
    this.language = LanguageChoice.system,
    this.autoUpdate = true,
    this.autoDownload = false,
    this.notifications = true,
    this.watchdog = true,
    this.orbStyle = OrbStyle.mercury,
    // The out-of-the-box rule is "any IP but Iran" (README, exit_filter_test):
    // an unknown stored name must never silently disable the filter either.
    this.exitFilter = ExitFilter.nonIran,
    this.exitPreferred = const ['DE'],
    this.exitBlocked = const ['IR'],
    this.exitAskAfter = 180,
    this.exitMaxTries = 8,
    this.socksPort = 1819,
    this.keepalive = 5,
    this.tunMtu = 1400,
    this.stallTimeout = 90,
    this.logLevel = 'info',
  });

  ConnectionMode mode;
  Protocol protocol;
  ScanMode scan;
  IpVersion ipVersion;
  MasqueTransport transport;
  String obfuscation;
  String endpoint;
  bool quickReconnect;
  bool fragment;
  bool autoConnect;
  bool killSwitch;
  bool privateDns;
  bool lanShare;
  bool bypassLan;
  bool ipv6Tunnel;
  SplitMode splitMode;
  List<String> splitApps;
  ThemeChoice theme;
  LanguageChoice language;
  bool autoUpdate;
  bool autoDownload;
  bool notifications;
  bool watchdog;
  OrbStyle orbStyle;

  /// Exit-country rule applied after the tunnel is up.
  ExitFilter exitFilter;

  /// ISO-3166 alpha-2 codes wanted first by [ExitFilter.preferred].
  List<String> exitPreferred;

  /// ISO-3166 alpha-2 codes that are never accepted while a filter runs.
  List<String> exitBlocked;

  /// Seconds of exit searching before the app asks what to do next.
  int exitAskAfter;

  /// Re-dials tolerated while searching for a matching exit.
  int exitMaxTries;

  int socksPort;
  int keepalive;
  int tunMtu;
  int stallTimeout;
  String logLevel;

  int get effectiveMtu {
    final cap = switch (protocol) {
      Protocol.gool || Protocol.smart => 1360,
      Protocol.wg => 1420,
      _ => 1400,
    };
    final v = tunMtu < 1280 ? 1280 : tunMtu;
    return v > cap ? cap : v;
  }

  /// The tunnel core always listens on loopback. LAN sharing is an authenticated
  /// relay on Android and `--bind 0.0.0.0` on Windows.
  String get socksBind => '127.0.0.1:$socksPort';

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'protocol': protocol.name,
        'scan': scan.name,
        'ipVersion': ipVersion.name,
        'transport': transport.name,
        'obfuscation': obfuscation,
        'endpoint': endpoint,
        'quickReconnect': quickReconnect,
        'fragment': fragment,
        'autoConnect': autoConnect,
        'killSwitch': killSwitch,
        'privateDns': privateDns,
        'lanShare': lanShare,
        'bypassLan': bypassLan,
        'ipv6Tunnel': ipv6Tunnel,
        'splitMode': splitMode.name,
        'splitApps': splitApps,
        'theme': theme.name,
        'language': language.name,
        'autoUpdate': autoUpdate,
        'autoDownload': autoDownload,
        'notifications': notifications,
        'watchdog': watchdog,
        'orbStyle': orbStyle.name,
        'exitFilter': exitFilter.name,
        'exitPreferred': exitPreferred,
        'exitBlocked': exitBlocked,
        'exitAskAfter': exitAskAfter,
        'exitMaxTries': exitMaxTries,
        'socksPort': socksPort,
        'keepalive': keepalive,
        'tunMtu': tunMtu,
        'stallTimeout': stallTimeout,
        'logLevel': logLevel,
      };

  /// Normalises a stored country list: upper-case ISO-3166 alpha-2 codes only,
  /// duplicates dropped, and an unusable value falls back to [fallback] so a
  /// hand-edited preference can never disable the filter by accident.
  static List<String> codes(Object? raw, List<String> fallback) {
    if (raw is! List) return List<String>.from(fallback);
    final out = <String>[];
    for (final e in raw) {
      final c = '$e'.trim().toUpperCase();
      if (c.length == 2 && !out.contains(c)) out.add(c);
    }
    return out.isEmpty ? List<String>.from(fallback) : out;
  }

  factory VpnSettings.fromJson(Map<String, dynamic> json) {
    T parse<T extends Enum>(List<T> values, String key, T fallback) {
      final name = json[key]?.toString();
      return values.firstWhere((e) => e.name == name, orElse: () => fallback);
    }

    int num(String key, int fallback) {
      final v = json[key];
      if (v is int) return v;
      return int.tryParse('$v') ?? fallback;
    }

    return VpnSettings(
      mode: parse(ConnectionMode.values, 'mode', ConnectionMode.vpn),
      protocol: parse(Protocol.values, 'protocol', Protocol.smart),
      scan: parse(ScanMode.values, 'scan', ScanMode.balanced),
      ipVersion: parse(IpVersion.values, 'ipVersion', IpVersion.v4),
      transport:
          parse(MasqueTransport.values, 'transport', MasqueTransport.h3),
      obfuscation: json['obfuscation']?.toString() ?? 'auto',
      endpoint: json['endpoint']?.toString() ?? '',
      quickReconnect: json['quickReconnect'] != false,
      fragment: json['fragment'] == true,
      autoConnect: json['autoConnect'] == true,
      killSwitch: json['killSwitch'] != false,
      privateDns: json['privateDns'] != false,
      lanShare: json['lanShare'] == true,
      bypassLan: json['bypassLan'] != false,
      ipv6Tunnel: json['ipv6Tunnel'] == true,
      splitMode: parse(SplitMode.values, 'splitMode', SplitMode.off),
      splitApps: (json['splitApps'] as List?)?.map((e) => '$e').toList() ?? [],
      theme: parse(ThemeChoice.values, 'theme', ThemeChoice.dark),
      language: parse(LanguageChoice.values, 'language', LanguageChoice.system),
      autoUpdate: json['autoUpdate'] != false,
      autoDownload: json['autoDownload'] == true,
      notifications: json['notifications'] != false,
      watchdog: json['watchdog'] != false,
      orbStyle: parse(OrbStyle.values, 'orbStyle', OrbStyle.mercury),
      exitFilter: parse(ExitFilter.values, 'exitFilter', ExitFilter.nonIran),
      exitPreferred: codes(json['exitPreferred'], const ['DE']),
      exitBlocked: codes(json['exitBlocked'], const ['IR']),
      exitAskAfter: num('exitAskAfter', 180),
      exitMaxTries: num('exitMaxTries', 8),
      socksPort: num('socksPort', 1819),
      keepalive: num('keepalive', 5),
      tunMtu: num('tunMtu', 1400),
      stallTimeout: num('stallTimeout', 90),
      logLevel: json['logLevel']?.toString() ?? 'info',
    );
  }
}
