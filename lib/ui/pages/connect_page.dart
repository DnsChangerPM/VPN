import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/engine_state.dart';
import '../../services/vpn_controller.dart';
import '../../theme/nimbus_theme.dart';
import '../widgets/orb_button.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = c.s;
    final snap = c.snapshot;
    String label;
    switch (snap.phase) {
      case EnginePhase.connected:
        label = s.disconnect;
      case EnginePhase.disconnected:
      case EnginePhase.error:
        label = s.connect;
      default:
        label = s.connecting.toUpperCase();
    }
    String title;
    switch (snap.phase) {
      case EnginePhase.connected:
        title = s.active;
      case EnginePhase.error:
        title = s.error;
      case EnginePhase.scanning:
        title = s.scanning;
      case EnginePhase.reconnecting:
        title = s.reconnecting;
      case EnginePhase.disconnecting:
        title = s.disconnecting;
      case EnginePhase.connecting:
      case EnginePhase.preparing:
        title = s.connecting;
      case EnginePhase.disconnected:
        title = s.ready;
    }

    return Column(
      children: [
        if (c.update?.available == true)
          Material(
            color: const Color(0xFF163149),
            child: InkWell(
              onTap: c.downloadUpdate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.system_update_alt, color: NimbusColors.cyan),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${s.updateAvailable}: v${c.update!.latest}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          c.downloading
                              ? s.downloading
                              : s.downloadUpdate,
                          style: const TextStyle(color: NimbusColors.cyan),
                        ),
                      ],
                    ),
                    if (c.downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(value: c.downloadProgress),
                      ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: OrbButton(
              phase: snap.phase,
              label: label,
              hint: snap.phase == EnginePhase.disconnected ? s.tapToSecure : title,
              onTap: c.toggle,
            ),
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          snap.message.isEmpty ? s.socksHint : snap.message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: NimbusColors.muted),
        ),
        if (snap.connectedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${s.duration}: ${_uptime(snap.connectedAt!)}',
              style: const TextStyle(color: NimbusColors.muted, fontSize: 12),
            ),
          ),
        TextButton(
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: '127.0.0.1:1819'));
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(s.copied)));
          },
          child: Text(s.copyProxy),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              _metric(s.download, _fmt(snap.downloadBytes)),
              _metric(s.ping, snap.pingMs == null ? '—' : '${snap.pingMs} ms'),
              _metric(s.upload, _fmt(snap.uploadBytes)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            snap.location.isEmpty
                ? (snap.ip.isEmpty ? s.freeNote : snap.ip)
                : '${s.location}: ${snap.location}  ${snap.ip}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: NimbusColors.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _metric(String k, String v) {
    return Expanded(
      child: Column(
        children: [
          Text(k, style: const TextStyle(color: NimbusColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _fmt(int bytes) {
    if (bytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  String _uptime(DateTime start) {
    final d = DateTime.now().difference(start);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }
}
