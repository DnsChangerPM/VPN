import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// SOCKS5 data-plane probes.
///
/// Everything here speaks SOCKS5 with a *domain* CONNECT (ATYP=3) so name
/// resolution happens inside the tunnel, exactly the path the TUN bridge
/// forwards for apps. Plain HTTP on port 80 is used so no TLS stack is
/// needed; the previous implementation dialled port 443 and then spoke
/// cleartext HTTP on it, which can never succeed — that is why the stats
/// probe always threw and the watchdog tore down healthy connections.
class SocksProbe {
  /// Independent targets on three different operators, mirroring the
  /// reference client's proven-data-plane gate.
  static const _targets = <List<String>>[
    ['www.cloudflare.com', '/cdn-cgi/trace'],
    ['detectportal.firefox.com', '/success.txt'],
    ['connectivitycheck.gstatic.com', '/generate_204'],
  ];

  /// Proves the tunnel can complete a real HTTP request through SOCKS.
  /// Returns the round-trip in ms for the first target that answers,
  /// or throws when every target failed.
  static Future<int> prove({
    String host = '127.0.0.1',
    int port = 1819,
    int attempts = 2,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      for (final target in _targets) {
        try {
          final result = await httpGet(
            target[0],
            target[1],
            host: host,
            port: port,
            timeout: timeout,
          );
          return result.pingMs;
        } catch (e) {
          lastError = e;
        }
      }
    }
    throw SocketException('tunnel data-plane proof failed: $lastError');
  }

  /// Proves the **device** VPN (not the SOCKS listener) carries traffic: a
  /// plain HTTP GET with no proxy at all. Once the TUN adapter holds the
  /// default route, the OS has nothing else to send it through, so a successful
  /// reply is proof the adapter, the bridge and the routes really work.
  ///
  /// The first target is an IP literal — it must succeed even when DNS inside
  /// the tunnel is broken, so a routing failure and a DNS failure are not
  /// confused with each other. The domain targets then check name resolution
  /// through the tunnel.
  static Future<int> proveDevice({
    Duration timeout = const Duration(seconds: 12),
    int attempts = 2,
  }) async {
    const targets = <List<String>>[
      ['1.1.1.1', '/cdn-cgi/trace'],
      ['www.cloudflare.com', '/cdn-cgi/trace'],
      ['detectportal.firefox.com', '/success.txt'],
    ];
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      for (final target in targets) {
        try {
          return await _directGet(target[0], target[1], timeout: timeout);
        } catch (e) {
          lastError = e;
        }
      }
    }
    throw SocketException('device VPN data-plane proof failed: $lastError');
  }

  static Future<int> _directGet(
    String host,
    String path, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final sw = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      // Never inherit a proxy: the point is to test the adapter itself.
      client.findProxy = (_) => 'DIRECT';
      final request =
          await client.getUrl(Uri.parse('http://$host$path')).timeout(timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(timeout);
      await response.drain<void>().timeout(timeout);
      sw.stop();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw SocketException('HTTP ${response.statusCode} via the TUN device');
      }
      return sw.elapsedMilliseconds;
    } finally {
      client.close(force: true);
    }
  }

  /// Cloudflare trace through the tunnel (ping + exit IP + colo).
  static Future<({String body, int pingMs})> cloudflareTrace({
    String host = '127.0.0.1',
    int port = 1819,
  }) async {
    final r = await httpGet(
      'www.cloudflare.com',
      '/cdn-cgi/trace',
      host: host,
      port: port,
      timeout: const Duration(seconds: 12),
    );
    return (body: r.body, pingMs: r.pingMs);
  }

  /// One SOCKS5 CONNECT + HTTP/1.0 GET against `target:80`.
  static Future<({String body, int pingMs})> httpGet(
    String name,
    String path, {
    String host = '127.0.0.1',
    int port = 1819,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final sw = Stopwatch()..start();
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    final stash = <int>[];
    final iter = StreamIterator<List<int>>(socket);

    Future<Uint8List> readN(int n) async {
      while (stash.length < n) {
        if (!await iter.moveNext().timeout(timeout)) {
          throw const SocketException('SOCKS short read');
        }
        stash.addAll(iter.current);
      }
      final out = Uint8List.fromList(stash.take(n).toList());
      stash.removeRange(0, n);
      return out;
    }

    try {
      // Greeting: version 5, one method, no-auth.
      socket.add(Uint8List.fromList([0x05, 0x01, 0x00]));
      await socket.flush();
      final greet = await readN(2);
      if (greet[0] != 0x05 || greet[1] != 0x00) {
        throw const SocketException('SOCKS5 handshake failed');
      }
      final target = utf8.encode(name);
      final req = BytesBuilder()
        ..add([0x05, 0x01, 0x00, 0x03, target.length])
        ..add(target)
        ..add([0x00, 0x50]); // port 80, plain HTTP
      socket.add(req.toBytes());
      await socket.flush();
      final reply = await readN(4);
      if (reply[1] != 0x00) {
        throw SocketException('SOCKS connect status ${reply[1]}');
      }
      // Drain BND.ADDR per ATYP.
      if (reply[3] == 0x01) {
        await readN(6);
      } else if (reply[3] == 0x04) {
        await readN(18);
      } else if (reply[3] == 0x03) {
        final n = (await readN(1))[0];
        await readN(n + 2);
      }
      socket.add(utf8.encode(
        'GET $path HTTP/1.0\r\nHost: $name\r\nUser-Agent: nimbus-probe\r\n\r\n',
      ));
      await socket.flush();
      final chunks = BytesBuilder()..add(stash);
      stash.clear();
      var statusOk = false;
      while (await iter.moveNext().timeout(timeout)) {
        chunks.add(iter.current);
        final text = utf8.decode(chunks.toBytes(), allowMalformed: true);
        final headEnd = text.indexOf('\r\n\r\n');
        if (headEnd == -1 && chunks.length > 8192) break;
        if (headEnd != -1) {
          final statusLine = text.split('\r\n').first;
          statusOk = statusLine.startsWith('HTTP/') &&
              (statusLine.contains(' 200') ||
                  statusLine.contains(' 204') ||
                  statusLine.contains(' 301') ||
                  statusLine.contains(' 302'));
          final body = text.substring(headEnd + 4);
          if (statusOk &&
              (body.isNotEmpty ||
                  statusLine.contains(' 204') ||
                  chunks.length > 8192)) {
            break;
          }
          if (chunks.length > 16384) break;
        }
      }
      sw.stop();
      if (!statusOk) {
        throw const SocketException('no valid HTTP response through tunnel');
      }
      final text = utf8.decode(chunks.takeBytes(), allowMalformed: true);
      final headEnd = text.indexOf('\r\n\r\n');
      final body = headEnd == -1 ? text : text.substring(headEnd + 4);
      return (body: body, pingMs: sw.elapsedMilliseconds);
    } finally {
      await iter.cancel();
      socket.destroy();
    }
  }

  /// Fast SOCKS5 greeting check: true when the listener completes a
  /// method-selection handshake — not merely accepts TCP. A half-open or
  /// wedged listener passes a bare connect test and then publishes a tunnel
  /// that carries nothing.
  static Future<bool> handshake({
    String host = '127.0.0.1',
    int port = 1819,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      socket.add(Uint8List.fromList([0x05, 0x01, 0x00]));
      await socket.flush();
      final data = await socket.first.timeout(timeout);
      return data.length >= 2 && data[0] == 0x05 && data[1] == 0x00;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  static Map<String, String> parseTrace(String body) {
    final map = <String, String>{};
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final i = line.indexOf('=');
      if (i > 0) map[line.substring(0, i)] = line.substring(i + 1);
    }
    return map;
  }
}
