import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../models/engine_state.dart';
import '../models/settings.dart';
import 'aether_args.dart';

class PlatformEngine {
  static const _channel = MethodChannel('nimbus.vpn/engine');
  static const _events = EventChannel('nimbus.vpn/events');

  Stream<Map<String, dynamic>> events() {
    return _events.receiveBroadcastStream().map((event) {
      if (event is Map) return Map<String, dynamic>.from(event);
      return jsonDecode('$event') as Map<String, dynamic>;
    });
  }

  Future<bool> prepareVpn() async {
    if (!Platform.isAndroid) return true;
    final ok = await _channel.invokeMethod<bool>('prepareVpn');
    return ok ?? false;
  }

  Future<void> start(VpnSettings settings, {Protocol? protocol}) {
    final cfg = {
      ...settings.toJson(),
      'args': AetherLaunch.build(settings, override: protocol),
      'protocol': (protocol ?? settings.protocol).name,
      'socksPort': settings.socksPort,
      'tunMtu': settings.effectiveMtu,
      'killSwitch': settings.killSwitch,
      'bypassLan': settings.bypassLan,
    };
    if (Platform.isAndroid) {
      return _channel.invokeMethod('start', cfg);
    }
    if (Platform.isWindows) {
      return WindowsEngine.instance.start(settings, protocol: protocol);
    }
    throw UnsupportedError('Unsupported platform');
  }

  Future<void> stop() {
    if (Platform.isAndroid) return _channel.invokeMethod('stop');
    if (Platform.isWindows) return WindowsEngine.instance.stop();
    return Future.value();
  }

  Future<Map<String, dynamic>> status() async {
    if (Platform.isAndroid) {
      final map = await _channel.invokeMethod<Map>('status');
      return Map<String, dynamic>.from(map ?? {});
    }
    if (Platform.isWindows) return WindowsEngine.instance.statusMap();
    return {'phase': 'disconnected'};
  }

  Future<List<Map<String, String>>> installedApps() async {
    if (!Platform.isAndroid) return const [];
    final raw = await _channel.invokeMethod<List>('listApps');
    return (raw ?? const [])
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  Future<void> recoverNetwork() async {
    if (Platform.isWindows) return WindowsEngine.instance.recover();
    if (Platform.isAndroid) {
      await _channel.invokeMethod('recover');
    }
  }

  Future<void> installUpdate(String path) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('installApk', {'path': path});
      return;
    }
    if (Platform.isWindows) {
      await Process.start(path, const [], runInShell: true);
    }
  }

  Future<void> openBatterySettings() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('openBattery');
    }
  }

  Future<void> openSystemVpnSettings() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('openVpnSettings');
    }
  }

  Future<bool> isElevated() async {
    if (Platform.isAndroid) return true;
    if (Platform.isWindows) return WindowsEngine.instance.isAdmin();
    return false;
  }

  Future<bool> isWifi() async {
    if (!Platform.isAndroid) return true;
    final ok = await _channel.invokeMethod<bool>('isWifi');
    return ok ?? true;
  }

  Future<bool> verifyApk(String path) async {
    if (!Platform.isAndroid) return true;
    final ok = await _channel.invokeMethod<bool>('verifyApk', {'path': path});
    return ok ?? false;
  }

  Future<void> saveNativePrefs(VpnSettings settings) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('savePrefs', {
      'autoConnect': settings.autoConnect,
      'lanShare': settings.lanShare,
    });
  }
}

class WindowsEngine {
  WindowsEngine._();
  static final instance = WindowsEngine._();

  Process? _aether;
  Process? _tun;
  final _logs = StreamController<String>.broadcast();
  EnginePhase phase = EnginePhase.disconnected;
  String message = '';
  String endpoint = '';
  String protocol = '';
  String? _originalGw;
  int _socksPort = 1819;
  bool _bypassLan = true;
  final _bypass = <String>{};
  final _lanBypass = <String>[];

  Stream<String> get logs => _logs.stream;

  Map<String, dynamic> statusMap() => {
        'phase': phase.name,
        'message': message,
        'endpoint': endpoint,
        'protocol': protocol,
      };

  Future<bool> isAdmin() async {
    try {
      final r = await Process.run('net', ['session'], runInShell: true);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> start(VpnSettings settings, {Protocol? protocol}) async {
    await stop();
    this.protocol = (protocol ?? settings.protocol).name;
    phase = EnginePhase.scanning;
    message = 'Starting Aether core';
    _emit();
    final dir = File(Platform.resolvedExecutable).parent.path;
    final aether = File(p.join(dir, 'aether.exe'));
    if (!aether.existsSync()) {
      throw FileSystemException('aether.exe not found', aether.path);
    }
    _socksPort = settings.socksPort;
    _bypassLan = settings.bypassLan;
    final args = AetherLaunch.build(settings, override: protocol);
    _aether = await Process.start(
      aether.path,
      args,
      workingDirectory: dir,
      environment: {
        ...Platform.environment,
        ...AetherLaunch.environment(settings),
        'AETHER_PROTOCOL': this.protocol == 'mim' ? 'masque' : this.protocol,
      },
    );
    _aether!.stdout.transform(utf8.decoder).listen(_onLog);
    _aether!.stderr.transform(utf8.decoder).listen(_onLog);
    _aether!.exitCode.then((code) {
      if (phase == EnginePhase.connected ||
          phase == EnginePhase.connecting ||
          phase == EnginePhase.scanning) {
        phase = EnginePhase.error;
        message = 'Aether exited ($code)';
        _emit();
      }
    });

    final ready = await _waitSocks();
    if (!ready) {
      phase = EnginePhase.error;
      message = 'SOCKS5 listener did not start';
      _emit();
      await stop();
      return;
    }

    if (settings.mode == ConnectionMode.vpn) {
      final admin = await isAdmin();
      if (!admin) {
        phase = EnginePhase.connected;
        message =
            'SOCKS5 127.0.0.1:$_socksPort (VPN needs Administrator)';
        _emit();
        return;
      }
      await _startTun(dir, settings);
    }
    phase = EnginePhase.connected;
    message = settings.mode == ConnectionMode.vpn
        ? 'System VPN active'
        : 'SOCKS5 127.0.0.1:$_socksPort';
    _emit();
  }

  Future<void> stop() async {
    phase = EnginePhase.disconnecting;
    _emit();
    try {
      _tun?.kill(ProcessSignal.sigterm);
    } catch (_) {}
    try {
      _aether?.kill(ProcessSignal.sigterm);
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      _tun?.kill(ProcessSignal.sigkill);
    } catch (_) {}
    try {
      _aether?.kill(ProcessSignal.sigkill);
    } catch (_) {}
    _tun = null;
    _aether = null;
    await _restoreRoutes();
    phase = EnginePhase.disconnected;
    message = '';
    endpoint = '';
    _emit();
  }

  Future<void> recover() async {
    await stop();
    await Process.run('ipconfig', ['/flushdns'], runInShell: true);
    await Process.run(
      'netsh',
      ['interface', 'set', 'interface', 'Nimbus', 'admin=disable'],
      runInShell: true,
    );
  }

  Future<bool> _waitSocks() async {
    for (var i = 0; i < 90; i++) {
      try {
        final s = await Socket.connect('127.0.0.1', _socksPort,
            timeout: const Duration(seconds: 1));
        s.destroy();
        return true;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    return false;
  }

  void _onLog(String chunk) {
    for (final line in chunk.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) continue;
      _logs.add(line);
      final ip = _extractIp(line);
      if (ip != null) {
        endpoint = ip;
        _bypass.add(ip);
      }
      final lower = line.toLowerCase();
      if (lower.contains('scan')) phase = EnginePhase.scanning;
      if (lower.contains('reconnect')) phase = EnginePhase.reconnecting;
      if (lower.contains('listening') || lower.contains('socks5')) {
        if (phase != EnginePhase.connected) phase = EnginePhase.connecting;
      }
      _emit();
    }
  }

  static final _ipRe = RegExp(r'\b(\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?\b');

  String? _extractIp(String line) {
    if (!RegExp(r'peer|endpoint|gateway|connected|using', caseSensitive: false)
        .hasMatch(line)) {
      return null;
    }
    final m = _ipRe.firstMatch(line);
    if (m == null) return null;
    final ip = m.group(1)!;
    if (ip.startsWith('127.') || ip.startsWith('198.18.') || ip == '0.0.0.0') {
      return null;
    }
    return ip;
  }

  Future<void> _captureGateway() async {
    final r = await Process.run('route', ['print', '0.0.0.0'], runInShell: true);
    final text = '${r.stdout}';
    final re = RegExp(
        r'0\.0\.0\.0\s+0\.0\.0\.0\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+\.\d+\.\d+)');
    final m = re.firstMatch(text);
    if (m != null) {
      _originalGw = m.group(1);
    }
  }

  Future<void> _startTun(String dir, VpnSettings settings) async {
    await _captureGateway();
    final tun2socks = File(p.join(dir, 'tun2socks.exe'));
    if (!tun2socks.existsSync()) {
      message = 'tun2socks.exe missing; SOCKS5 only';
      return;
    }
    _tun = await Process.start(
      tun2socks.path,
      [
        '-device',
        'tun://Nimbus',
        '-proxy',
        'socks5://127.0.0.1:$_socksPort',
        '-loglevel',
        'info',
      ],
      workingDirectory: dir,
    );
    _tun!.stdout.transform(utf8.decoder).listen(_onLog);
    _tun!.stderr.transform(utf8.decoder).listen(_onLog);
    await Future<void>.delayed(const Duration(seconds: 2));
    await Process.run(
      'netsh',
      [
        'interface',
        'ip',
        'set',
        'address',
        'name=Nimbus',
        'source=static',
        'addr=198.18.0.1',
        'mask=255.255.255.0',
      ],
      runInShell: true,
    );
    await Process.run(
      'netsh',
      ['interface', 'ip', 'set', 'dns', 'name=Nimbus', 'static', '1.1.1.1'],
      runInShell: true,
    );
    const ranges = [
      '162.159.192.0/24',
      '162.159.193.0/24',
      '162.159.195.0/24',
      '188.114.96.0/24',
      '188.114.97.0/24',
      '188.114.98.0/24',
      '188.114.99.0/24',
      '162.159.36.0/24',
      '162.159.46.0/24',
    ];
    if (_originalGw != null) {
      for (final ip in _bypass) {
        await Process.run(
            'route', ['add', ip, 'mask', '255.255.255.255', _originalGw!],
            runInShell: true);
      }
      for (final cidr in ranges) {
        final parts = cidr.split('/');
        final mask = parts[1] == '24' ? '255.255.255.0' : '255.255.255.255';
        await Process.run('route', ['add', parts[0], 'mask', mask, _originalGw!],
            runInShell: true);
      }
    }
    await Process.run(
      'route',
      ['add', '0.0.0.0', 'mask', '0.0.0.0', '198.18.0.1', 'metric', '5'],
      runInShell: true,
    );
    if (_bypassLan && _originalGw != null) {
      const lan = [
        ['10.0.0.0', '255.0.0.0'],
        ['172.16.0.0', '255.240.0.0'],
        ['192.168.0.0', '255.255.0.0'],
      ];
      for (final row in lan) {
        await Process.run(
            'route', ['add', row[0], 'mask', row[1], _originalGw!],
            runInShell: true);
        _lanBypass.add(row[0]);
      }
    }
  }

  Future<void> _restoreRoutes() async {
    await Process.run(
        'route', ['delete', '0.0.0.0', 'mask', '0.0.0.0', '198.18.0.1'],
        runInShell: true);
    if (_originalGw != null) {
      for (final ip in _bypass) {
        await Process.run('route', ['delete', ip], runInShell: true);
      }
    }
    if (_originalGw != null) {
      for (final ip in _lanBypass) {
        await Process.run('route', ['delete', ip], runInShell: true);
      }
    }
    await Process.run('netsh', ['interface', 'set', 'interface', 'Nimbus', 'admin=disable'],
        runInShell: true);
    _bypass.clear();
    _lanBypass.clear();
  }

  void _emit() {
    // Status is polled from WindowsEngine.instance.statusMap via controller.
  }
}
