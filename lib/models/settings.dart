enum ConnectionMode { vpn, proxy }

enum Protocol { smart, masque, wg, gool, mim }

enum ScanMode { turbo, balanced, thorough, stealth, ironclad }

enum IpVersion { v4, v6, dual }

enum MasqueTransport { h3, h2 }

enum ThemeChoice { system, dark, light }

enum LanguageChoice { system, en, fa }

enum SplitMode { off, include, exclude }

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
    this.splitMode = SplitMode.off,
    this.splitApps = const [],
    this.theme = ThemeChoice.dark,
    this.language = LanguageChoice.system,
    this.autoUpdate = true,
    this.notifications = true,
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
  SplitMode splitMode;
  List<String> splitApps;
  ThemeChoice theme;
  LanguageChoice language;
  bool autoUpdate;
  bool notifications;

  String get socksBind => lanShare ? '0.0.0.0:1819' : '127.0.0.1:1819';

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
        'splitMode': splitMode.name,
        'splitApps': splitApps,
        'theme': theme.name,
        'language': language.name,
        'autoUpdate': autoUpdate,
        'notifications': notifications,
      };

  factory VpnSettings.fromJson(Map<String, dynamic> json) {
    T parse<T extends Enum>(List<T> values, String key, T fallback) {
      final name = json[key]?.toString();
      return values.firstWhere((e) => e.name == name, orElse: () => fallback);
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
      splitMode: parse(SplitMode.values, 'splitMode', SplitMode.off),
      splitApps: (json['splitApps'] as List?)?.map((e) => '$e').toList() ?? [],
      theme: parse(ThemeChoice.values, 'theme', ThemeChoice.dark),
      language: parse(LanguageChoice.values, 'language', LanguageChoice.system),
      autoUpdate: json['autoUpdate'] != false,
      notifications: json['notifications'] != false,
    );
  }
}
