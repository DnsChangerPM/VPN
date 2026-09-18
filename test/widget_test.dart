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
}
