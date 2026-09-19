import 'dart:io' show Platform;

import '../models/settings.dart';

/// Builds the tunnel-core launch configuration.
///
/// The core is driven **only through environment variables** and never through
/// CLI flags; that is its documented configuration contract, and env-only
/// keeps the Android and Windows launchers behaviourally identical.
class CoreLaunch {
  static const coreVersion = '2.0.0';

  /// Obfuscation profile given to the core. The core accepts
  /// off|light|balanced|aggressive (plus aliases like gfw/firewall); anything
  /// unknown falls back to its "firewall" preset, so unrecognised values are
  /// harmless, but we always send a documented value.
  static String noizeFor(Protocol protocol, String obfuscation) {
    const known = {'off', 'light', 'balanced', 'aggressive', 'gfw', 'firewall'};
    if (known.contains(obfuscation)) return obfuscation;
    return 'balanced';
  }

  static String _ipToken(IpVersion v) => switch (v) {
        IpVersion.v4 => 'v4',
        IpVersion.v6 => 'v6',
        IpVersion.dual => 'both',
      };

  static Protocol _effective(VpnSettings s, Protocol? override) {
    final p = override ?? s.protocol;
    return p == Protocol.smart ? Protocol.masque : p;
  }

  /// The environment the core runs with:
  ///   AETHER_PROTOCOL / SCAN / IP / NOIZE / SOCKS / CONFIG / QUICK_RECONNECT /
  ///   LOG_LEVEL, then transport-specific keys, then the optional peer.
  /// (The `AETHER_*` names are the core's own interface and must stay.)
  static Map<String, String> environment(
    VpnSettings settings, {
    Protocol? override,

    /// Absolute path of the identity file the core may write (aether.toml).
    /// Must live in a per-user writable directory — never next to the exe
    /// (Program Files is read-only for normal users and a failed identity
    /// write is the most common "spins forever" cause on Windows).
    required String configPath,
    String? tmpDir,
  }) {
    final proto = _effective(settings, override);
    final bind = settings.lanShare && Platform.isWindows
        ? '0.0.0.0:${settings.socksPort}'
        : settings.socksBind;
    final env = <String, String>{
      'AETHER_PROTOCOL': proto.name,
      'AETHER_SCAN': settings.scan.name,
      'AETHER_IP': _ipToken(settings.ipVersion),
      'AETHER_NOIZE': noizeFor(proto, settings.obfuscation),
      'AETHER_SOCKS': bind,
      'AETHER_CONFIG': configPath,
      'AETHER_QUICK_RECONNECT': settings.quickReconnect ? '1' : '0',
      'AETHER_LOG_LEVEL': switch (settings.logLevel) {
        'error' || 'warn' || 'info' || 'debug' || 'trace' => settings.logLevel,
        _ => 'info',
      },
    };
    if (proto == Protocol.masque || proto == Protocol.mim) {
      env['AETHER_MASQUE_HTTP2'] =
          settings.transport == MasqueTransport.h2 ? '1' : '0';
      env['AETHER_MASQUE_MTU'] = '${settings.effectiveMtu}';
      if (settings.transport == MasqueTransport.h2 && settings.fragment) {
        env['AETHER_MASQUE_H2_FRAGMENT'] = '1';
      }
    } else {
      env['AETHER_WG_KEEPALIVE'] = '${settings.keepalive}';
    }
    final peer = settings.endpoint.trim();
    if (peer.isNotEmpty) {
      if (proto == Protocol.masque || proto == Protocol.mim) {
        env['AETHER_PEER'] = peer;
      } else {
        env['AETHER_WG_PEER'] = peer;
      }
    }
    if (tmpDir != null && tmpDir.isNotEmpty) env['TMPDIR'] = tmpDir;
    return env;
  }

  /// Serialised "KEY=VALUE" list for passing through the Android intent.
  static List<String> environmentLines(
    VpnSettings settings, {
    Protocol? override,
    required String configPath,
    String? tmpDir,
  }) {
    return environment(
      settings,
      override: override,
      configPath: configPath,
      tmpDir: tmpDir,
    ).entries.map((e) => '${e.key}=${e.value}').toList();
  }

  /// Smart Connect ladder. masque appears twice: the first attempt keeps the
  /// chosen carrier and the second forces HTTP/2, because networks that drop
  /// QUIC outright only pass the TCP 443 carrier. The native Android service
  /// also races h3→h2 on its own inside the first attempt; running the h2
  /// attempt again later is harmless.
  static List<Protocol> smartLadder(VpnSettings settings) {
    if (settings.protocol != Protocol.smart) {
      return [settings.protocol];
    }
    return const [
      Protocol.masque,
      Protocol.masque,
      Protocol.wg,
      Protocol.gool,
      Protocol.mim,
    ];
  }
}
