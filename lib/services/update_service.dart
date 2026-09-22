import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../app_info.dart';
import '../models/engine_state.dart';

/// Update handling — all releases are published on the official Telegram channel.
///
/// The app no longer contacts any Git repository. [check] returns the currently
/// running version as both current and latest, so the UI stays up-to-date and
/// the only source of new builds that the user ever sees is the Telegram channel
/// defined in [AppInfo.telegramUrl].
///
/// The forced-update mechanism is kept for offline persistence: if a newer
/// version was previously announced and stored locally, it still blocks the app
/// until the user installs the new build from Telegram. No network call to a
/// repository is performed.
class UpdateService {
  static const telegramUrl = AppInfo.telegramUrl;

  Future<UpdateInfo> check({Duration timeout = const Duration(seconds: 20)}) async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version.isEmpty ? AppInfo.version : info.version;
    // No remote repository check — the Telegram channel is the single source of truth.
    // Returning current==latest means \"up to date\" unless a forced-update flag
    // was already persisted locally.
    return UpdateInfo(
      current: current,
      latest: current,
      notes: '',
      htmlUrl: telegramUrl,
      available: false,
      checkFailed: false,
    );
  }

  static Map<String, String> parseSha256Sums(String body) {
    final map = <String, String>{};
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final m = RegExp(r'^([a-fA-F0-9]{64})\s+\*?(.+)$').firstMatch(line.trim());
      if (m != null) {
        map[m.group(2)!.split(RegExp(r'[/\\]')).last.toLowerCase()] =
            m.group(1)!.toLowerCase();
      }
    }
    return map;
  }

  /// Kept for API compatibility — direct downloads are now done via Telegram.
  /// Any call to this method will throw and the caller should open the Telegram channel.
  Future<File> download({
    required String url,
    String? expectedSha256,
    required void Function(double progress) onProgress,
  }) async {
    // No direct download from a repository. The only distribution point is Telegram.
    throw UnsupportedError(
        'Direct download is disabled — get the new build from $telegramUrl');
  }

  static bool isNewer(String latest, String current) => _isNewer(latest, current);

  static bool _isNewer(String latest, String current) {
    List<int> parts(String v) => v
        .split(RegExp(r'[^0-9]+'))
        .where((e) => e.isNotEmpty)
        .map(int.parse)
        .toList();
    final a = parts(latest);
    final b = parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
