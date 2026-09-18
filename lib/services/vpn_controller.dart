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
import 'windows_proxy.dart';

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
  String? lanEndpoint;
  String? lanUser;
  String? lanPass;

  /// Windows only: is this instance elevated, and which TUN bridge is carrying
  /// the device VPN. Both feed the Diagnostics page and the "run as
  /// Administrator" affordance, so the user can see *why* a full device VPN is
  /// or is not up instead of guessing from one sentence.
  bool elevated = false;
  String windowsLabel = '';
  Timer? _updateTimer;
  Timer? _statsTimer;
  Timer? _clock;
  Timer? _watchdogTimer;
  StreamSubscription? _events;
  StreamSubscription? _winLogs;
  bool _wantUp = false;
  bool _userDisconnect = false;
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
      unawaited(_refreshWindowsFacts());
      // Self-heal: a run that ended hard (window closed, crash) cannot
      // clean up after itself, so it may leave the system proxy pointing at
      // our dead listener. Undo any leftover that is unambiguously ours.
      unawaited(WindowsSystemProxy.instance.restore(
          ourPort: settings.socksPort));
    }
    unawaited(engine.installedApps().then((list) {
      apps
        ..clear()
        ..addAll(list);
      notifyListeners();
    }));
    await engine.saveNativePrefs(settings);
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
    await engine.saveNativePrefs(settings);
    notifyListeners();
  }

  Future<void> refreshUpdate() async {
    update = await updates.check();
    notifyListeners();
    if (update?.available == true && settings.autoDownload && !downloading) {
      final wifi = await engine.isWifi();
      if (wifi) unawaited(downloadUpdate());
    }
  }

  Future<void> openUpdate() async {
    final info = update;
    if (info == null) return;
    await downloadUpdate();
    if (downloadedPath == null && info.htmlUrl != null) {
      await launchUrl(Uri.parse(info.htmlUrl!),
          mode: LaunchMode.externalApplication);
    }
  }

  Future<void> downloadUpdate() async {
    final info = update;
    if (info == null || downloading) return;
    final url = Platform.isAndroid ? info.apkUrl : info.exeUrl;
    final sha = Platform.isAndroid ? info.apkSha256 : info.exeSha256;
    if (url == null) {
      if (info.htmlUrl != null) {
        await launchUrl(Uri.parse(info.htmlUrl!),
            mode: LaunchMode.externalApplication);
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
      if (Platform.isAndroid) {
        final same = await engine.verifyApk(file.path);
        if (!same) {
          await file.delete();
          throw const FileSystemException('APK signing certificate mismatch');
        }
      }
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
    if (snapshot.phase == EnginePhase.connected ||
        snapshot.phase == EnginePhase.error ||
        snapshot.phase == EnginePhase.disconnecting) {
      await disconnect();
      return;
    }
    // Any mid-flight state cancels the in-flight attempt so the orb never
    // becomes a dead spinner: the native/engine stop unwinds the pipeline.
    if (snapshot.isActive || busy) {
      _wantUp = false;
      _userDisconnect = true;
      _watchdogTimer?.cancel();
      _set(snapshot.copyWith(
          phase: EnginePhase.disconnecting, message: s.disconnecting));
      unawaited(engine.stop().whenComplete(() {
        _set(const EngineSnapshot());
      }));
      return;
    }
    await connect();
  }

  Future<void> connect() async {
    if (busy) return;
    _wantUp = true;
    _userDisconnect = false;
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
        await _refreshWindowsFacts();
        if (!elevated) _log('$needAdminText ($windowsLabel)');
      }
      final ladder = AetherLaunch.smartLadder(settings);
      var lastError = 'connect failed';
      for (var i = 0; i < ladder.length; i++) {
        if (!_wantUp) return;
        final proto = ladder[i];
        final attempt = settings.copyWithProtocol(proto);
        // Smart Connect: the second MASQUE attempt rides the HTTP/2 carrier,
        // which is what networks that drop QUIC (UDP 443) let through.
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
        } catch (e) {
          lastError = '$e';
          _log('start ${proto.name}: $e');
          await engine.stop();
          continue;
        }
        final up = await _waitConnected(proto);
        if (up) {
          _watchdogTries = 0;
          _lastHealthy = DateTime.now();
          _set(snapshot.copyWith(
            phase: EnginePhase.connected,
            protocol: snapshot.protocol.isEmpty
                ? proto.name
                : snapshot.protocol,
            message: snapshot.message.isEmpty ? s.active : snapshot.message,
            connectedAt: DateTime.now(),
          ));
          _startStats();
          _clock?.cancel();
          _clock = Timer.periodic(const Duration(seconds: 1), (_) {
            notifyListeners();
          });
          return;
        }
        if (!_wantUp) return;
        lastError = snapshot.phase == EnginePhase.error &&
                snapshot.message.isNotEmpty
            ? snapshot.message
            : (Platform.isWindows &&
                    WindowsEngine.instance.lastError.isNotEmpty
                ? WindowsEngine.instance.lastError
                : 'timeout');
        _log('${proto.name}: $lastError');
        await engine.stop();
      }
      _set(snapshot.copyWith(
        phase: EnginePhase.error,
        message: lastError,
        clearConnectedAt: true,
      ));
      _scheduleWatchdog();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _wantUp = false;
    _userDisconnect = true;
    _watchdogTries = 0;
    _watchdogTimer?.cancel();
    lanEndpoint = lanUser = lanPass = null;
    busy = true;
    _statsTimer?.cancel();
    _clock?.cancel();
    _set(snapshot.copyWith(
        phase: EnginePhase.disconnecting, message: s.disconnecting));
    try {
      await engine.stop();
    } finally {
      busy = false;
      _set(const EngineSnapshot());
    }
  }

  /// Waits for the engine (native Android service or Windows process runner)
  /// to publish `connected`. On Android that state already includes the
  /// native data-plane proof; on Windows the engine proves traffic itself
  /// before flipping the phase.
  Future<bool> _waitConnected(Protocol proto) async {
    // Generous budget: the gateway scan on a filtered network is the slow
    // part (AetherGUI gives MASQUE 60s, then races the h2 carrier). Cutting
    // at 60s while the core is still mid-scan is what produced the endless
    // spinner and ladder churn.
    final budget = Platform.isAndroid
        ? const Duration(seconds: 210)
        : const Duration(seconds: 150);
    final deadline = DateTime.now().add(budget);
    while (DateTime.now().isBefore(deadline)) {
      if (!_wantUp) return false;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      // Native events already flow into _onEvent; polling keeps Windows and
      // missed broadcasts honest.
      if (snapshot.phase == EnginePhase.connected) return true;
      if (snapshot.phase == EnginePhase.error) return false;
      try {
        final st = await engine.status();
        final phase = st['phase']?.toString() ?? '';
        if (phase == 'connected') {
          _set(snapshot.copyWith(
            phase: EnginePhase.connected,
            endpoint: st['endpoint']?.toString() ?? snapshot.endpoint,
            protocol: st['protocol']?.toString() ?? proto.name,
            message:
                st['message']?.toString() ?? snapshot.message,
          ));
          return true;
        }
        if (phase == 'error') {
          final msg = st['message']?.toString() ?? '';
          _set(snapshot.copyWith(
            phase: EnginePhase.error,
            message: msg.isEmpty ? snapshot.message : msg,
          ));
          return false;
        }
        // A transient 'disconnected' (restart teardown between attempts) is
        // not terminal: 'error' ends the attempt, '_wantUp' handles cancel.
        // Progress details for the spinner subtitle.
        final msg = st['message']?.toString() ?? '';
        if (msg.isNotEmpty && msg != snapshot.message) {
          _set(snapshot.copyWith(message: msg));
        }
      } catch (_) {}
      if (Platform.isWindows) {
        final win = WindowsEngine.instance;
        if (win.phase == EnginePhase.connected) {
          _set(snapshot.copyWith(
            phase: EnginePhase.connected,
            endpoint: win.endpoint,
            protocol: win.protocol,
            message: win.message,
          ));
          return true;
        }
        if (win.phase == EnginePhase.error) {
          _set(snapshot.copyWith(
            phase: EnginePhase.error,
            message: win.message,
          ));
          return false;
        }
      }
    }
    _log('connect attempt timed out after ${budget.inSeconds}s');
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
            DateTime.now().difference(last).inSeconds >=
                settings.stallTimeout) {
          _log('watchdog: stall ${settings.stallTimeout}s');
          _set(snapshot.copyWith(phase: EnginePhase.error, message: 'stalled'));
          _scheduleWatchdog(forceReconnect: true);
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
    if (type == 'lan') {
      final raw = event['message']?.toString() ?? '';
      final parts = raw.split('|');
      if (parts.length >= 3) {
        lanEndpoint = parts[0];
        lanUser = parts[1];
        lanPass = parts[2];
        notifyListeners();
      }
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
      if (phase == EnginePhase.connected) {
        _watchdogTries = 0;
        _lastHealthy = DateTime.now();
      }
      if (phase == EnginePhase.error && !_userDisconnect) {
        _scheduleWatchdog();
      }
    }
  }

  void _scheduleWatchdog({bool forceReconnect = false}) {
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
    if (forceReconnect) _log('watchdog: reconnect scheduled in ${delay.inSeconds}s');
  }

  /// Elevation and OS build never change for a running process, but they are
  /// only known after the first probe — and the UI shows them from the start.
  Future<void> _refreshWindowsFacts() async {
    if (!Platform.isWindows) return;
    final win = WindowsEngine.instance;
    elevated = await win.isAdmin();
    windowsLabel = (await win.windowsBuild()).label;
    notifyListeners();
  }

  /// Everything the Diagnostics page shows about the device VPN.
  Map<String, String> get tunInfo {
    if (!Platform.isWindows) return const {};
    return WindowsEngine.instance.tunInfo();
  }

  /// True when a device VPN was asked for but this instance cannot deliver it
  /// because it is not running as Administrator.
  bool get needsElevation =>
      Platform.isWindows &&
      settings.mode == ConnectionMode.vpn &&
      !elevated;

  String get needAdminText => s.needAdmin;

  /// One-tap UAC relaunch: closes this instance and reopens it elevated, so
  /// "restart as Administrator" is not a four-step manual dance.
  Future<void> restartAsAdmin() async {
    if (!Platform.isWindows) return;
    _log('restarting as Administrator…');
    final ok = await WindowsEngine.instance.restartElevated();
    if (!ok) {
      toast = s.elevationRefused;
      notifyListeners();
    }
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
    // Windows: if the app goes away while the tunnel is still up, stop the
    // engine too — kills aether.exe, restores the routes and hands the
    // system proxy back the way we found it.
    if (Platform.isWindows && (snapshot.isActive || busy)) {
      unawaited(WindowsEngine.instance.stop());
    }
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
