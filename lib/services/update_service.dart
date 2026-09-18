import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_info.dart';
import '../models/engine_state.dart';

class UpdateService {
  static const owner = AppInfo.githubOwner;
  static const repo = AppInfo.githubRepo;
  static final latestUri =
      Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
  static const githubHtml = 'https://github.com/$owner/$repo/releases';

  Future<UpdateInfo> check() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version.isEmpty ? AppInfo.version : info.version;
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
      String? apkSha;
      String? exeSha;
      for (final asset in (json['assets'] as List? ?? const [])) {
        final map = Map<String, dynamic>.from(asset as Map);
        final name = '${map['name']}'.toLowerCase();
        final url = '${map['browser_download_url']}';
        final digest = '${map['digest'] ?? ''}'.replaceFirst('sha256:', '');
        if (name.endsWith('.apk') && !name.contains('armv7') && apk == null) {
          apk = url;
          if (digest.length == 64) apkSha = digest;
        }
        if (name.contains('universal') && name.endsWith('.apk')) {
          apk = url;
          if (digest.length == 64) apkSha = digest;
        }
        if (name.endsWith('.exe') && name.contains('windows') && exe == null) {
          exe = url;
          if (digest.length == 64) exeSha = digest;
        }
        if (name.contains('installer') && name.endsWith('.exe')) {
          exe = url;
          if (digest.length == 64) exeSha = digest;
        }
      }
      return UpdateInfo(
        current: current,
        latest: latest.isEmpty ? current : latest,
        notes: notes,
        apkUrl: apk,
        exeUrl: exe,
        apkSha256: apkSha,
        exeSha256: exeSha,
        htmlUrl: htmlUrl,
        available: _isNewer(latest, current),
      );
    } catch (_) {
      return UpdateInfo(current: current, htmlUrl: githubHtml);
    }
  }

  Future<File> download({
    required String url,
    String? expectedSha256,
    required void Function(double progress) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final name = url.split('/').last;
    final file = File(p.join(dir.path, name));
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'NimbusVPN/${AppInfo.version}');
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('download ${res.statusCode}');
      }
      final total = res.contentLength;
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.close();
      if (expectedSha256 != null && expectedSha256.length == 64) {
        final hash = sha256.convert(await file.readAsBytes()).toString();
        if (hash.toLowerCase() != expectedSha256.toLowerCase()) {
          await file.delete();
          throw const FileSystemException('SHA-256 mismatch');
        }
      }
      onProgress(1);
      return file;
    } finally {
      client.close(force: true);
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
