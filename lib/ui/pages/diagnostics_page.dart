import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: () async {
                  try {
                    final r = await SocksProbe.cloudflareTrace();
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
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
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
        ),
      ],
    );
  }

  String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
