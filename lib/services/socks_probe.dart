import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class SocksProbe {
  static Future<({String body, int pingMs})> cloudflareTrace({
    String host = '127.0.0.1',
    int port = 1819,
  }) async {
    final sw = Stopwatch()..start();
    final socket = await Socket.connect(host, port,
        timeout: const Duration(seconds: 8));
    final stash = <int>[];
    final iter = StreamIterator<List<int>>(socket);

    Future<Uint8List> readN(int n) async {
      while (stash.length < n) {
        if (!await iter.moveNext().timeout(const Duration(seconds: 8))) {
          throw const SocketException('SOCKS short read');
        }
        stash.addAll(iter.current);
      }
      final out = Uint8List.fromList(stash.take(n).toList());
      stash.removeRange(0, n);
      return out;
    }

    try {
      socket.add(Uint8List.fromList([0x05, 0x01, 0x00]));
      await socket.flush();
      final greet = await readN(2);
      if (greet[0] != 0x05 || greet[1] != 0x00) {
        throw const SocketException('SOCKS5 handshake failed');
      }
      final target = utf8.encode('www.cloudflare.com');
      final req = BytesBuilder()
        ..add([0x05, 0x01, 0x00, 0x03, target.length])
        ..add(target)
        ..add([0x01, 0xBB]);
      socket.add(req.toBytes());
      await socket.flush();
      final reply = await readN(4);
      if (reply[1] != 0x00) {
        throw SocketException('SOCKS connect status ${reply[1]}');
      }
      if (reply[3] == 0x01) {
        await readN(6);
      } else if (reply[3] == 0x04) {
        await readN(18);
      } else if (reply[3] == 0x03) {
        final n = (await readN(1))[0];
        await readN(n + 2);
      }
      socket.add(utf8.encode(
        'GET /cdn-cgi/trace HTTP/1.1\r\nHost: www.cloudflare.com\r\nConnection: close\r\n\r\n',
      ));
      await socket.flush();
      final chunks = BytesBuilder()..add(stash);
      stash.clear();
      while (await iter.moveNext().timeout(const Duration(seconds: 12))) {
        chunks.add(iter.current);
        if (chunks.length > 8192) break;
        final text = utf8.decode(chunks.toBytes(), allowMalformed: true);
        if (text.contains('\r\n\r\n') && text.contains('ip=')) break;
      }
      sw.stop();
      final text = utf8.decode(chunks.takeBytes(), allowMalformed: true);
      final body = text.contains('\r\n\r\n')
          ? text.substring(text.indexOf('\r\n\r\n') + 4)
          : text;
      return (body: body, pingMs: sw.elapsedMilliseconds);
    } finally {
      await iter.cancel();
      socket.destroy();
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
