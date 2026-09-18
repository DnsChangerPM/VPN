import '../models/settings.dart';

class AetherLaunch {
  static const coreVersion = '2.0.0';

  static String noizeFor(Protocol protocol, String obfuscation) {
    if (obfuscation != 'auto') return obfuscation;
    switch (protocol) {
      case Protocol.masque:
      case Protocol.mim:
      case Protocol.smart:
        return 'firewall';
      case Protocol.wg:
      case Protocol.gool:
        return 'balanced';
    }
  }

  static List<String> build(VpnSettings settings, {Protocol? override}) {
    final protocol = override ?? settings.protocol;
    final args = <String>[
      '--bind',
      settings.socksBind,
      '--scan',
      settings.scan.name,
      '--noize',
      noizeFor(protocol, settings.obfuscation),
    ];

    switch (settings.ipVersion) {
      case IpVersion.v4:
        args.add('-4');
      case IpVersion.v6:
        args.add('-6');
      case IpVersion.dual:
        args.add('--dual');
    }

    switch (protocol) {
      case Protocol.smart:
      case Protocol.masque:
        args.add('--masque');
        if (settings.transport == MasqueTransport.h2) {
          args.add('--h2');
          if (settings.fragment) args.add('--fragment');
        }
      case Protocol.wg:
        args.add('--wg');
        args.addAll(['--keepalive', '${settings.keepalive}']);
      case Protocol.gool:
        args.add('--gool');
        args.addAll(['--keepalive', '${settings.keepalive}']);
      case Protocol.mim:
        args.add('--mim');
        if (settings.transport == MasqueTransport.h2) {
          args.add('--h2');
          if (settings.fragment) args.add('--fragment');
        }
    }

    if (settings.quickReconnect) {
      args.add('--quick-reconnect');
    } else {
      args.add('--no-quick-reconnect');
    }

    final peer = settings.endpoint.trim();
    if (peer.isNotEmpty) {
      args.addAll(['--peer', peer]);
    }
    return args;
  }

  static Map<String, String> environment(VpnSettings settings) => {
        'AETHER_LOG': settings.logLevel,
        'AETHER_MASQUE_MTU': '${settings.effectiveMtu}',
      };

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
