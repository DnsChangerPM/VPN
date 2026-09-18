import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_info.dart';
import '../../services/socks_probe.dart';
import '../../services/vpn_controller.dart';
import '../../theme/nimbus_theme.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = c.s;
    final snap = c.snapshot;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () async {
                try {
                  final r = await SocksProbe.cloudflareTrace(
                    port: c.settings.socksPort,
                  );
                  c.log('trace ping ${r.pingMs} ms');
                  for (final line in r.body.split('\n')) {
                    if (line.trim().isNotEmpty) c.log(line.trim());
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('OK ${r.pingMs} ms')),
                    );
                  }
                } catch (e) {
                  c.log('trace failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: Text(s.testConnection),
            ),
            OutlinedButton(onPressed: c.recover, child: Text(s.recover)),
            IconButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: c.logs.map((e) => e.text).join('\n')),
                );
              },
              icon: const Icon(Icons.copy),
            ),
            IconButton(
              onPressed: c.clearLogs,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _grid([
          _cell(s.protocol, snap.protocol.isEmpty ? '—' : snap.protocol),
          _cell(s.tunnel, snap.phase.name),
          _cell(s.tun, snap.phase.name == 'connected' ? 'Nimbus' : '—'),
          _cell('MTU', '${c.settings.effectiveMtu}'),
          _cell(s.exitIp, snap.ip.isEmpty ? '—' : snap.ip),
          _cell(s.ping, snap.pingMs == null ? '—' : '${snap.pingMs} ms'),
          _cell(s.location, snap.location.isEmpty ? '—' : snap.location),
          _cell(s.coreVersion, 'Aether ${AppInfo.core}'),
          _cell('SOCKS5', c.settings.socksBind),
          _cell(s.download, '${snap.downloadBytes}'),
          _cell(s.upload, '${snap.uploadBytes}'),
          _cell(s.endpoint, snap.endpoint.isEmpty ? 'auto' : snap.endpoint),
        ]),
        const SizedBox(height: 16),
        Text(s.logs, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          height: 360,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NimbusColors.line),
          ),
          child: ListView.builder(
            itemCount: c.logs.length,
            itemBuilder: (context, i) {
              final line = c.logs[i];
              return Text(
                '[${_hhmmss(line.at)}] ${line.text}',
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFFB8D4C8),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _grid(List<Widget> cells) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: cells,
    );
  }

  Widget _cell(String k, String v) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NimbusColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NimbusColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(k, style: const TextStyle(color: NimbusColors.muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
