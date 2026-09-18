import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/engine_state.dart';

class UpdateService {
  static const owner = 'DnsChangerPM';
  static const repo = 'VPN';
  static final latestUri =
      Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
  static const githubHtml = 'https://github.com/$owner/$repo/releases';

  Future<UpdateInfo> check() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version;
    try {
      final res = await http.get(
        latestUri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'NimbusVPN/$current',
        },
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        return UpdateInfo(current: current, latest: current, htmlUrl: githubHtml);
      }
      if (res.statusCode != 200) {
        throw HttpException('GitHub ${res.statusCode}');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] ?? '').toString();
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      final notes = (json['body'] ?? '').toString();
      final htmlUrl = (json['html_url'] ?? githubHtml).toString();
      String? apk;
      String? exe;
      for (final asset in (json['assets'] as List? ?? const [])) {
        final name = '${(asset as Map)['name']}'.toLowerCase();
        final url = '${asset['browser_download_url']}';
        if (name.endsWith('.apk') && apk == null) apk = url;
        if ((name.endsWith('.exe') || name.contains('installer')) &&
            name.contains('windows') &&
            exe == null) {
          exe = url;
        }
        if (name.endsWith('.exe') && exe == null) exe = url;
      }
      return UpdateInfo(
        current: current,
        latest: latest.isEmpty ? current : latest,
        notes: notes,
        apkUrl: apk,
        exeUrl: exe,
        htmlUrl: htmlUrl,
        available: _isNewer(latest, current),
      );
    } catch (_) {
      return UpdateInfo(current: current, htmlUrl: githubHtml);
    }
  }

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
