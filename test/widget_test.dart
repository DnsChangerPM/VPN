import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidrauvpn/models/settings.dart';
import 'package:voidrauvpn/services/core_args.dart';
import 'package:voidrauvpn/services/update_service.dart';

void main() {
  test('MASQUE env carries protocol, scan, socks and config', () {
    final env = CoreLaunch.environment(
      VpnSettings(protocol: Protocol.masque, scan: ScanMode.turbo),
      configPath: '/tmp/aether.toml',
    );
    expect(env['AETHER_PROTOCOL'], 'masque');
    expect(env['AETHER_SCAN'], 'turbo');
    expect(env['AETHER_SOCKS'], '127.0.0.1:1819');
    expect(env['AETHER_CONFIG'], '/tmp/aether.toml');
    expect(env['AETHER_NOIZE'], 'balanced');
    expect(env['AETHER_LOG_LEVEL'], 'info');
    expect(env['AETHER_MASQUE_HTTP2'], '0');
  });

  test('unknown obfuscation falls back to a documented profile', () {
    expect(CoreLaunch.noizeFor(Protocol.gool, 'auto'), 'balanced');
    expect(CoreLaunch.noizeFor(Protocol.masque, 'auto'), 'balanced');
    expect(CoreLaunch.noizeFor(Protocol.masque, 'aggressive'), 'aggressive');
  });

  test('HTTP/2 carrier enables fragment env only when requested', () {
    final h2Frag = CoreLaunch.environment(
      VpnSettings(
        protocol: Protocol.masque,
        transport: MasqueTransport.h2,
        fragment: true,
      ),
      configPath: '/tmp/aether.toml',
    );
    expect(h2Frag['AETHER_MASQUE_HTTP2'], '1');
    expect(h2Frag['AETHER_MASQUE_H2_FRAGMENT'], '1');
    final h3 = CoreLaunch.environment(
      VpnSettings(protocol: Protocol.masque),
      configPath: '/tmp/aether.toml',
    );
    expect(h3.containsKey('AETHER_MASQUE_H2_FRAGMENT'), isFalse);
  });

  test('wg and gool carry keepalive; masque carries MTU', () {
    final wg = CoreLaunch.environment(
      VpnSettings(protocol: Protocol.wg, keepalive: 15),
      configPath: '/tmp/aether.toml',
    );
    expect(wg['AETHER_PROTOCOL'], 'wg');
    expect(wg['AETHER_WG_KEEPALIVE'], '15');
    expect(wg.containsKey('AETHER_MASQUE_MTU'), isFalse);
    final masque = CoreLaunch.environment(
      VpnSettings(protocol: Protocol.masque, tunMtu: 2000),
      configPath: '/tmp/aether.toml',
    );
    expect(masque['AETHER_MASQUE_MTU'], '1400');
    expect(masque.containsKey('AETHER_WG_KEEPALIVE'), isFalse);
  });

  test('IP version env tokens match the core grammar', () {
    String token(IpVersion v) => CoreLaunch.environment(
          VpnSettings(ipVersion: v),
          configPath: '/tmp/aether.toml',
        )['AETHER_IP']!;
    expect(token(IpVersion.v4), 'v4');
    expect(token(IpVersion.v6), 'v6');
    expect(token(IpVersion.dual), 'both');
  });

  test('peer goes to the right env var per protocol', () {
    final masque = CoreLaunch.environment(
      VpnSettings(protocol: Protocol.masque, endpoint: '162.159.192.1:443'),
      configPath: '/tmp/aether.toml',
    );
    expect(masque['AETHER_PEER'], '162.159.192.1:443');
    expect(masque.containsKey('AETHER_WG_PEER'), isFalse);
    final wg = CoreLaunch.environment(
      VpnSettings(protocol: Protocol.wg, endpoint: '162.159.192.1:2408'),
      configPath: '/tmp/aether.toml',
    );
    expect(wg['AETHER_WG_PEER'], '162.159.192.1:2408');
    expect(wg.containsKey('AETHER_PEER'), isFalse);
  });

  test('smart protocol maps to masque for the engine override', () {
    final env = CoreLaunch.environment(
      VpnSettings(protocol: Protocol.smart),
      override: Protocol.smart,
      configPath: '/tmp/aether.toml',
    );
    expect(env['AETHER_PROTOCOL'], 'masque');
  });

  test('environment lines serialise as KEY=VALUE', () {
    final lines = CoreLaunch.environmentLines(
      VpnSettings(protocol: Protocol.gool),
      configPath: 'aether.toml',
    );
    expect(lines, contains('AETHER_PROTOCOL=gool'));
    expect(lines, contains('AETHER_CONFIG=aether.toml'));
    expect(lines.every((l) => l.contains('=')), isTrue);
  });

  test('LAN share only widens the bind on Windows', () {
    final env = CoreLaunch.environment(
      VpnSettings(lanShare: true, socksPort: 1900),
      configPath: '/tmp/aether.toml',
    );
    expect(
      env['AETHER_SOCKS'],
      Platform.isWindows ? '0.0.0.0:1900' : '127.0.0.1:1900',
    );
  });

  test('settings roundtrip', () {
    final s = VpnSettings(protocol: Protocol.mim, lanShare: true);
    final copy = VpnSettings.fromJson(s.toJson());
    expect(copy.protocol, Protocol.mim);
    expect(copy.socksBind, '127.0.0.1:1819');
  });

  test('smart ladder walks transports', () {
    expect(CoreLaunch.smartLadder(VpnSettings()).length, greaterThan(3));
  });

  test('SHA256SUMS parser', () {
    const body = '''
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  VoidrauVPN-v1.2.3-Android-Universal.apk
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *VoidrauVPN-v1.2.3-Windows-x64-Installer.exe
''';
    final map = UpdateService.parseSha256Sums(body);
    expect(map['voidrauvpn-v1.2.3-android-universal.apk'], startsWith('aaaa'));
    expect(map['voidrauvpn-v1.2.3-windows-x64-installer.exe'], startsWith('bbbb'));
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
