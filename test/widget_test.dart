import 'package:flutter_test/flutter_test.dart';
import 'package:nimbus/models/settings.dart';
import 'package:nimbus/services/aether_args.dart';

void main() {
  test('MASQUE args include bind and scan', () {
    final args = AetherLaunch.build(
      VpnSettings(protocol: Protocol.masque, scan: ScanMode.turbo),
    );
    expect(args, contains('--masque'));
    expect(args, contains('--scan'));
    expect(args, contains('turbo'));
    expect(args, contains('--bind'));
    expect(args, contains('127.0.0.1:1819'));
    expect(args, contains('--noize'));
    expect(args, contains('firewall'));
  });

  test('gool uses WireGuard-style noize default', () {
    expect(AetherLaunch.noizeFor(Protocol.gool, 'auto'), 'balanced');
    expect(AetherLaunch.noizeFor(Protocol.masque, 'auto'), 'firewall');
  });

  test('HTTP/2 adds fragment when requested', () {
    final args = AetherLaunch.build(
      VpnSettings(
        protocol: Protocol.masque,
        transport: MasqueTransport.h2,
        fragment: true,
      ),
    );
    expect(args, contains('--h2'));
    expect(args, contains('--fragment'));
  });

  test('settings roundtrip', () {
    final s = VpnSettings(protocol: Protocol.mim, lanShare: true);
    final copy = VpnSettings.fromJson(s.toJson());
    expect(copy.protocol, Protocol.mim);
    expect(copy.socksBind, '0.0.0.0:1819');
  });

  test('smart ladder walks transports', () {
    expect(AetherLaunch.smartLadder(VpnSettings()).length, greaterThan(3));
  });

  test('wg and gool pass keepalive', () {
    final wg = AetherLaunch.build(VpnSettings(protocol: Protocol.wg, keepalive: 15));
    expect(wg, containsAllInOrder(['--keepalive', '15']));
    final gool = AetherLaunch.build(VpnSettings(protocol: Protocol.gool));
    expect(gool, contains('--gool'));
    expect(gool, contains('--keepalive'));
  });

  test('custom socks bind and env MTU', () {
    final s = VpnSettings(socksPort: 1900, lanShare: true, tunMtu: 2000, protocol: Protocol.masque);
    expect(s.socksBind, '0.0.0.0:1900');
    expect(s.effectiveMtu, 1400);
    final args = AetherLaunch.build(s);
    expect(args, contains('0.0.0.0:1900'));
    expect(AetherLaunch.environment(s)['AETHER_MASQUE_MTU'], '1400');
    expect(AetherLaunch.environment(s)['AETHER_LOG'], 'info');
  });

  test('advanced settings roundtrip', () {
    final s = VpnSettings(
      bypassLan: false,
      ipv6Tunnel: true,
      watchdog: false,
      autoDownload: true,
      orbStyle: OrbStyle.classic,
      socksPort: 2020,
      keepalive: 9,
      tunMtu: 1280,
      stallTimeout: 45,
      logLevel: 'debug',
    );
    final copy = VpnSettings.fromJson(s.toJson());
    expect(copy.bypassLan, false);
    expect(copy.ipv6Tunnel, true);
    expect(copy.watchdog, false);
    expect(copy.autoDownload, true);
    expect(copy.orbStyle, OrbStyle.classic);
    expect(copy.socksPort, 2020);
    expect(copy.keepalive, 9);
    expect(copy.tunMtu, 1280);
    expect(copy.stallTimeout, 45);
    expect(copy.logLevel, 'debug');
  });
}
