import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../models/engine_state.dart';
import '../models/settings.dart';
import 'aether_args.dart';
import 'socks_probe.dart';
import 'windows_proxy.dart';

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
    final proto = protocol ?? settings.protocol;
    final cfg = {
      ...settings.toJson(),
      // The native side drives the core through environment variables only
      // (AetherGUI pattern); it knows its own config/temp paths.
      'env': AetherLaunch.environmentLines(
        settings,
        override: protocol,
        configPath: 'aether.toml',
      ),
      'protocol': (proto == Protocol.smart ? Protocol.masque : proto).name,
      'transport': settings.transport.name,
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

/// Windows: spawns `aether.exe` (env-only config, like the reference GUI),
/// waits for a real SOCKS5 handshake, proves the data plane, then puts a
/// WinTUN + tun2socks full-device tunnel in front when running elevated.
class WindowsEngine {
  WindowsEngine._() {
    // Proxy changes are visible in the same live log as the core's output.
    WindowsSystemProxy.instance.onLog = (line) => _logs.add(line);
  }

  static final instance = WindowsEngine._();

  Process? _aether;
  Process? _tun;
  final _logs = StreamController<String>.broadcast();
  EnginePhase phase = EnginePhase.disconnected;
  String message = '';
  String endpoint = '';
  String protocol = '';
  String lastError = '';
  String? _originalGw;
  int _socksPort = 1819;
  bool _bypassLan = true;
  bool _tunActive = false;
  final _bypass = <String>{};
  final _lanBypass = <String>[];
  final _rangeRoutes = <String>[];
  String _runDir = '';

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

  /// Per-user writable working directory for the core. The identity files
  /// (aether.toml, aether-masque.toml, lastconn) must live here: writing them
  /// next to the exe under Program Files fails for non-admin users and the
  /// core then dies on startup — the classic "connect spins forever".
  String get runtimeDir {
    if (_runDir.isNotEmpty) return _runDir;
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    final dir = Directory(p.join(base, 'Nimbus VPN'));
    dir.createSync(recursive: true);
    _runDir = dir.path;
    return _runDir;
  }

  Future<void> start(VpnSettings settings, {Protocol? protocol}) async {
    await stop();
    final proto = protocol ?? settings.protocol;
    final protoName = proto == Protocol.smart ? 'masque' : proto.name;
    this.protocol = protoName;
    lastError = '';
    phase = EnginePhase.scanning;
    message = 'Starting Aether core';
    _emit();

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final aether = File(p.join(exeDir, 'aether.exe'));
    if (!aether.existsSync()) {
      // Fall back to the sidecar directory used in development.
      final sidecar = File(p.join(Directory.current.path, 'third_party',
          'windows', 'aether.exe'));
      if (!sidecar.existsSync()) {
        throw FileSystemException('aether.exe not found', aether.path);
      }
    }

    _socksPort = settings.socksPort;
    _bypassLan = settings.bypassLan;
    _tunActive = false;
    _bypass.clear();
    _lanBypass.clear();
    _rangeRoutes.clear();

    final env = AetherLaunch.environment(
      settings,
      override: proto,
      configPath: p.join(runtimeDir, 'aether.toml'),
    );
    final aetherPath = aether.existsSync()
        ? aether.path
        : p.join(Directory.current.path, 'third_party', 'windows',
            'aether.exe');
    _aetherExited = false;
    _aether = await Process.start(
      aetherPath,
      const [], // env-only configuration (AetherGUI pattern)
      workingDirectory: runtimeDir,
      environment: {...Platform.environment, ...env},
    );
    _aether!.stdout.transform(utf8.decoder).listen(_onLog);
    _aether!.stderr.transform(utf8.decoder).listen(_onLog);
    _aether!.exitCode.then((code) {
      _aetherExited = true;
      if (phase == EnginePhase.connected ||
          phase == EnginePhase.connecting ||
          phase == EnginePhase.scanning) {
        phase = EnginePhase.error;
        message = lastError.isEmpty ? 'Aether exited ($code)' : lastError;
        _emit();
      }
    });

    final ready = await _waitSocks(const Duration(seconds: 90));
    if (!ready) {
      lastError = lastError.isEmpty
          ? 'SOCKS5 listener did not start (gateway scan found nothing)'
          : lastError;
      phase = EnginePhase.error;
      message = lastError;
      _emit();
      await stop();
      return;
    }

    // Proving traffic is the difference between "connected" and "the core
    // opened a listener for a tunnel that carries nothing" (AetherGUI's
    // proven-data-plane gate).
    phase = EnginePhase.connecting;
    message = 'Verifying the tunnel';
    _emit();
    try {
      await SocksProbe.prove(port: _socksPort);
    } catch (e) {
      lastError = 'tunnel carries no traffic';
      phase = EnginePhase.error;
      message = '$e';
      _emit();
      await stop();
      return;
    }

    // The tunnel is proven. From here on the Windows system proxy follows
    // the app's on/off state: snapshot whatever the user had, then take it
    // (proxy mode) or give it back (device VPN — with a stale manual proxy
    // active, WinINET apps would shortcut the tunnel through the raw SOCKS
    // listener, so a full device VPN must run proxy-free).
    final proxy = WindowsSystemProxy.instance;
    await proxy.rememberOriginal();

    if (settings.mode == ConnectionMode.proxy) {
      await proxy.enableOurs(_socksPort);
      phase = EnginePhase.connected;
      message = 'SOCKS5 127.0.0.1:$_socksPort — system proxy on';
      _emit();
      return;
    }

    final admin = await isAdmin();
    if (!admin) {
      // Honest degradation: no TUN without elevation, so the system proxy
      // is what keeps the machine tunneled. Tell the user exactly what to
      // do instead of silently lying about a TUN.
      await proxy.enableOurs(_socksPort);
      phase = EnginePhase.connected;
      message = 'SOCKS5 127.0.0.1:$_socksPort (system proxy) — restart as Administrator for full VPN';
      _emit();
      return;
    }
    final ok = await _startTun(exeDir, settings);
    if (!ok) {
      await proxy.enableOurs(_socksPort);
      phase = EnginePhase.connected;
      message = lastError.isEmpty
          ? 'SOCKS5 127.0.0.1:$_socksPort (TUN failed, system proxy on)'
          : '$lastError — system proxy on';
      _emit();
      return;
    }
    // Full device tunnel: every app rides the TUN adapter directly, so the
    // system proxy goes back to off — no proxy to set, everything through
    // the VPN device.
    await proxy.clearOurs();
    phase = EnginePhase.connected;
    message = 'System VPN active';
    _emit();
  }

  Future<void> stop() async {
    if (phase == EnginePhase.connected ||
        phase == EnginePhase.connecting ||
        phase == EnginePhase.scanning ||
        phase == EnginePhase.reconnecting) {
      phase = EnginePhase.disconnecting;
      _emit();
    }
    final aether = _aether;
    final tun = _tun;
    _aether = null;
    _tun = null;
    void kill(Process? proc) {
      if (proc == null) return;
      try {
        proc.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }

    kill(tun);
    kill(aether);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      tun?.kill(ProcessSignal.sigkill);
    } catch (_) {}
    try {
      aether?.kill(ProcessSignal.sigkill);
    } catch (_) {}
    await _restoreRoutes();
    // Disconnect means proxy flow stops too: hand the system proxy back to
    // whatever it was before Nimbus, so the machine is left direct (or with
    // the user's own proxy) instead of pointing at a dead listener.
    await WindowsSystemProxy.instance.restore(ourPort: _socksPort);
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

  bool _aetherExited = false;

  /// Waits for the SOCKS5 listener to answer a real method-selection
  /// greeting, failing fast when the core exits (bad flags, unwritable
  /// identity path, no route) instead of hanging the whole budget.
  Future<bool> _waitSocks(Duration budget) async {
    final deadline = DateTime.now().add(budget);
    while (DateTime.now().isBefore(deadline)) {
      if (_aether == null || _aetherExited) return false;
      final ok = await SocksProbe.handshake(
          port: _socksPort, timeout: const Duration(seconds: 2));
      if (ok) return true;
      await Future<void>.delayed(const Duration(milliseconds: 400));
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
      if (lower.contains('error') ||
          lower.contains('failed') ||
          lower.contains('refused')) {
        lastError = line;
      }
      if (lower.contains('scan') ||
          lower.contains('hunting') ||
          lower.contains('identity ready')) {
        if (phase != EnginePhase.connected) phase = EnginePhase.scanning;
      }
      if (lower.contains('reconnect')) phase = EnginePhase.reconnecting;
      if (lower.contains('validated') || lower.contains('handshake')) {
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

  Future<bool> _startTun(String dir, VpnSettings settings) async {
    await _captureGateway();
    final tun2socks = File(p.join(dir, 'tun2socks.exe'));
    final wintun = File(p.join(dir, 'wintun.dll'));
    if (!tun2socks.existsSync() || !wintun.existsSync()) {
      lastError = 'tun2socks.exe/wintun.dll missing; running SOCKS5 only';
      _logLine(lastError);
      return false;
    }
    try {
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
    } catch (e) {
      lastError = 'tun2socks failed to start: $e';
      return false;
    }

    // Wait for the WinTUN adapter to materialise, do not assume 2 seconds.
    var adapterUp = false;
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final r = await Process.run(
        'netsh',
        ['interface', 'ip', 'show', 'interfaces'],
        runInShell: true,
      );
      if ('${r.stdout}'.contains('Nimbus')) {
        adapterUp = true;
        break;
      }
    }
    if (!adapterUp) {
      lastError = 'WinTUN adapter "Nimbus" never appeared';
      _logLine(lastError);
      return false;
    }

    final addr = await Process.run(
      'netsh',
      [
        'interface', 'ip', 'set', 'address',
        'name=Nimbus',
        'source=static',
        'addr=198.18.0.1',
        'mask=255.255.255.252',
      ],
      runInShell: true,
    );
    if (addr.exitCode != 0) {
      lastError = 'netsh set address failed: ${addr.stdout}${addr.stderr}';
      _logLine(lastError);
      return false;
    }
    await Process.run(
      'netsh',
      ['interface', 'ip', 'set', 'dns', 'name=Nimbus', 'static', '1.1.1.1'],
      runInShell: true,
    );
    await Process.run(
      'netsh',
      [
        'interface', 'ip', 'add', 'dns', 'name=Nimbus', '1.0.0.1', 'index=2'
      ],
      runInShell: true,
    );

    // Bypass the tunnel's own upstreams first — missing one is the difference
    // between a tunnel and a routing loop. The ranges are the full WARP
    // candidate space the core can scan (aether/src/prober.rs), collapsed
    // into the documented /20 ingress blocks plus the DoH ranges.
    const warpRanges = [
      ['162.159.192.0', '255.255.240.0'], // 162.159.192-207, every MASQUE CIDR
      ['188.114.96.0', '255.255.240.0'], // 188.114.96-111
      ['162.159.36.0', '255.255.255.0'],
      ['162.159.46.0', '255.255.255.0'],
    ];
    final custom = settings.endpoint.trim();
    if (custom.isNotEmpty) {
      final ip = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})').firstMatch(custom);
      if (ip != null) _bypass.add(ip.group(1)!);
    }
    if (_originalGw != null) {
      for (final ip in _bypass) {
        await Process.run(
            'route', ['add', ip, 'mask', '255.255.255.255', _originalGw!],
            runInShell: true);
      }
      _rangeRoutes.clear();
      for (final row in warpRanges) {
        await Process.run(
            'route', ['add', row[0], 'mask', row[1], _originalGw!],
            runInShell: true);
        _rangeRoutes.add(row[0]);
      }
    }
    final def = await Process.run(
      'route',
      ['add', '0.0.0.0', 'mask', '0.0.0.0', '198.18.0.1', 'metric', '5'],
      runInShell: true,
    );
    if (def.exitCode != 0) {
      lastError = 'default route install failed';
      _logLine('route add 0.0.0.0: ${def.stdout}${def.stderr}');
      return false;
    }
    _tunActive = true;
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
    return true;
  }

  Future<void> _restoreRoutes() async {
    if (_tunActive) {
      await Process.run(
          'route', ['delete', '0.0.0.0', 'mask', '0.0.0.0', '198.18.0.1'],
          runInShell: true);
    }
    for (final dest in _rangeRoutes) {
      await Process.run('route', ['delete', dest], runInShell: true);
    }
    if (_originalGw != null) {
      for (final ip in _bypass) {
        await Process.run('route', ['delete', ip], runInShell: true);
      }
      for (final ip in _lanBypass) {
        await Process.run('route', ['delete', ip], runInShell: true);
      }
    }
    await Process.run(
        'netsh', ['interface', 'set', 'interface', 'Nimbus', 'admin=disable'],
        runInShell: true);
    _bypass.clear();
    _lanBypass.clear();
    _rangeRoutes.clear();
    _tunActive = false;
  }

  void _logLine(String line) => _logs.add(line);

  void _emit() {
    // Status is polled from WindowsEngine.instance.statusMap via controller.
  }
}
