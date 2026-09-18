import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../models/engine_state.dart';
import '../models/settings.dart';
import 'aether_args.dart';
import 'platform_engine.dart';
import 'socks_probe.dart';
import 'update_service.dart';

class VpnController extends ChangeNotifier {
  VpnController();

  final engine = PlatformEngine();
  final updates = UpdateService();

  VpnSettings settings = VpnSettings();
  EngineSnapshot snapshot = const EngineSnapshot();
  UpdateInfo? update;
  final logs = <LogLine>[];
  final apps = <Map<String, String>>[];
  bool busy = false;
  bool downloading = false;
  double downloadProgress = 0;
  String? downloadedPath;
  String? toast;
  Timer? _updateTimer;
  Timer? _statsTimer;
  Timer? _clock;
  Timer? _watchdogTimer;
  StreamSubscription? _events;
  StreamSubscription? _winLogs;
  bool _wantUp = false;
  int _watchdogTries = 0;
  DateTime? _lastHealthy;

  S get s {
    final sys = PlatformDispatcher.instance.locale.languageCode;
    final code = settings.language == LanguageChoice.system
        ? sys
        : settings.language.name;
    return S(code == 'fa' ? 'fa' : 'en');
  }

  bool get rtl => s.isFa;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings');
    if (raw != null) {
      settings = VpnSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    _events = engine.events().listen(_onEvent, onError: (_) {});
    if (Platform.isWindows) {
      _winLogs = WindowsEngine.instance.logs.listen((line) => _log(line));
    }
    unawaited(engine.installedApps().then((list) {
      apps
        ..clear()
        ..addAll(list);
      notifyListeners();
    }));
    notifyListeners();
    unawaited(refreshUpdate());
    _updateTimer = Timer.periodic(const Duration(hours: 12), (_) {
      if (settings.autoUpdate) unawaited(refreshUpdate());
    });
    if (settings.autoConnect) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await toggle();
    }
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings', jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Future<void> refreshUpdate() async {
    update = await updates.check();
    notifyListeners();
    if (update?.available == true && settings.autoDownload && !downloading) {
      unawaited(downloadUpdate());
    }
  }

  Future<void> openUpdate() async {
    final info = update;
    if (info == null) return;
    await downloadUpdate();
    if (downloadedPath == null && info.htmlUrl != null) {
      await launchUrl(Uri.parse(info.htmlUrl!), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> downloadUpdate() async {
    final info = update;
    if (info == null || downloading) return;
    final url = Platform.isAndroid ? info.apkUrl : info.exeUrl;
    final sha = Platform.isAndroid ? info.apkSha256 : info.exeSha256;
    if (url == null) {
      if (info.htmlUrl != null) {
        await launchUrl(Uri.parse(info.htmlUrl!), mode: LaunchMode.externalApplication);
      }
      return;
    }
    downloading = true;
    downloadProgress = 0;
    notifyListeners();
    try {
      final file = await updates.download(
        url: url,
        expectedSha256: sha,
        onProgress: (p) {
          downloadProgress = p;
          notifyListeners();
        },
      );
      downloadedPath = file.path;
      await engine.installUpdate(file.path);
    } catch (e) {
      _log('update download failed: $e');
      toast = '$e';
    } finally {
      downloading = false;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (busy) return;
    if (snapshot.phase == EnginePhase.connected) {
      await disconnect();
      return;
    }
    await connect();
  }

  Future<void> connect() async {
    if (busy) return;
    _wantUp = true;
    busy = true;
    _set(snapshot.copyWith(
      phase: EnginePhase.preparing,
      message: s.preparing,
    ));
    try {
      if (settings.mode == ConnectionMode.vpn && Platform.isAndroid) {
        final ok = await engine.prepareVpn();
        if (!ok) {
          _set(snapshot.copyWith(
            phase: EnginePhase.error,
            message: s.needVpnPerm,
          ));
          return;
        }
      }
      if (settings.mode == ConnectionMode.vpn && Platform.isWindows) {
        final admin = await engine.isElevated();
        if (!admin) {
          _log(s.needAdmin);
        }
      }
      final ladder = AetherLaunch.smartLadder(settings);
      var lastError = 'connect failed';
      for (var i = 0; i < ladder.length; i++) {
        var proto = ladder[i];
        final attempt = settings.copyWithProtocol(proto);
        if (settings.protocol == Protocol.smart && i == 1) {
          attempt.transport = MasqueTransport.h2;
        }
        _set(snapshot.copyWith(
          phase: EnginePhase.scanning,
          protocol: proto.name,
          message: 'Aether ${proto.name}',
        ));
        try {
          await engine.start(attempt, protocol: proto);
          final up = await _waitConnected();
          if (up) {
            _watchdogTries = 0;
            _lastHealthy = DateTime.now();
            _set(snapshot.copyWith(
              phase: EnginePhase.connected,
              protocol: proto.name,
              message: s.active,
              connectedAt: DateTime.now(),
            ));
            _startStats();
            _clock?.cancel();
            _clock = Timer.periodic(const Duration(seconds: 1), (_) {
              notifyListeners();
            });
            return;
          }
          lastError = snapshot.message.isEmpty ? 'timeout' : snapshot.message;
          await engine.stop();
        } catch (e) {
          lastError = '$e';
          _log('$e');
          await engine.stop();
        }
      }
      _set(snapshot.copyWith(phase: EnginePhase.error, message: lastError));
      _scheduleWatchdog();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _wantUp = false;
    _watchdogTries = 0;
    _watchdogTimer?.cancel();
    busy = true;
    _statsTimer?.cancel();
    _clock?.cancel();
    _set(snapshot.copyWith(phase: EnginePhase.disconnecting, message: s.disconnecting));
    try {
      await engine.stop();
    } finally {
      busy = false;
      _set(const EngineSnapshot());
    }
  }

  Future<bool> _waitConnected() async {
    for (var i = 0; i < 120; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (snapshot.phase == EnginePhase.error) return false;
      if (snapshot.phase == EnginePhase.connected) return true;
      try {
        final st = await engine.status();
        final phase = st['phase']?.toString() ?? '';
        if (phase == 'connected') {
          _set(snapshot.copyWith(
            phase: EnginePhase.connected,
            endpoint: st['endpoint']?.toString() ?? snapshot.endpoint,
            protocol: st['protocol']?.toString() ?? snapshot.protocol,
          ));
          return true;
        }
        if (phase == 'error') return false;
      } catch (_) {}
      if (Platform.isWindows &&
          WindowsEngine.instance.phase == EnginePhase.connected) {
        _set(snapshot.copyWith(phase: EnginePhase.connected));
        return true;
      }
    }
    return false;
  }

  void _startStats() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (snapshot.phase != EnginePhase.connected) return;
      try {
        final probe = await SocksProbe.cloudflareTrace(
          port: settings.socksPort,
        );
        final map = SocksProbe.parseTrace(probe.body);
        _set(snapshot.copyWith(
          pingMs: probe.pingMs,
          ip: map['ip'] ?? snapshot.ip,
          location: [
            map['loc'] ?? '',
            map['colo'] ?? '',
          ].where((e) => e.isNotEmpty).join(' · '),
        ));
        _lastHealthy = DateTime.now();
      } catch (_) {
        final last = _lastHealthy;
        if (settings.watchdog &&
            last != null &&
            DateTime.now().difference(last).inSeconds >= settings.stallTimeout) {
          _log('watchdog: stall ${settings.stallTimeout}s');
          _set(snapshot.copyWith(phase: EnginePhase.error, message: 'stalled'));
          _scheduleWatchdog();
        }
      }
      try {
        final st = await engine.status();
        _set(snapshot.copyWith(
          downloadBytes: int.tryParse('${st['download'] ?? 0}') ??
              snapshot.downloadBytes,
          uploadBytes:
              int.tryParse('${st['upload'] ?? 0}') ?? snapshot.uploadBytes,
          endpoint: st['endpoint']?.toString() ?? snapshot.endpoint,
        ));
      } catch (_) {}
    });
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    if (type == 'log') {
      _log('${event['line'] ?? event['message'] ?? ''}');
      return;
    }
    if (type == 'status') {
      final phase = EnginePhase.values.firstWhere(
        (e) => e.name == event['phase'],
        orElse: () => snapshot.phase,
      );
      _set(snapshot.copyWith(
        phase: phase,
        message: event['message']?.toString() ?? snapshot.message,
        endpoint: event['endpoint']?.toString() ?? snapshot.endpoint,
        protocol: event['protocol']?.toString() ?? snapshot.protocol,
        downloadBytes: int.tryParse('${event['download'] ?? ''}') ??
            snapshot.downloadBytes,
        uploadBytes:
            int.tryParse('${event['upload'] ?? ''}') ?? snapshot.uploadBytes,
      ));
      if (phase == EnginePhase.error) {
        _scheduleWatchdog();
      }
      if (phase == EnginePhase.connected) {
        _watchdogTries = 0;
        _lastHealthy = DateTime.now();
      }
    }
  }

  void _scheduleWatchdog() {
    if (!_wantUp || !settings.watchdog || _watchdogTries >= 5) return;
    _watchdogTries++;
    _watchdogTimer?.cancel();
    final delay = Duration(seconds: 2 * _watchdogTries);
    _watchdogTimer = Timer(delay, () {
      if (_wantUp &&
          snapshot.phase != EnginePhase.connected &&
          snapshot.phase != EnginePhase.connecting &&
          snapshot.phase != EnginePhase.scanning &&
          snapshot.phase != EnginePhase.preparing) {
        unawaited(connect());
      }
    });
  }

  void log(String line) => _log(line);

  void _log(String line) {
    logs.add(LogLine(line));
    if (logs.length > 800) logs.removeRange(0, logs.length - 800);
    notifyListeners();
  }

  void _set(EngineSnapshot next) {
    snapshot = next;
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  Future<void> recover() async {
    await engine.recoverNetwork();
    _log('network recovery requested');
  }

  @override
  void dispose() {
    _events?.cancel();
    _winLogs?.cancel();
    _updateTimer?.cancel();
    _statsTimer?.cancel();
    _clock?.cancel();
    _watchdogTimer?.cancel();
    super.dispose();
  }
}

extension on VpnSettings {
  VpnSettings copyWithProtocol(Protocol protocol) {
    final json = toJson();
    json['protocol'] = protocol.name;
    return VpnSettings.fromJson(json);
  }
}
