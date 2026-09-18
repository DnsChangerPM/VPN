import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/engine_state.dart';
import '../../models/settings.dart';
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
              mercury: c.settings.orbStyle == OrbStyle.mercury,
              onTap: c.toggle,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: snap.phase == EnginePhase.connected
                ? const Color(0x3327D7F2)
                : snap.phase == EnginePhase.error
                    ? const Color(0x33FF5D67)
                    : NimbusColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NimbusColors.line),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: snap.phase == EnginePhase.connected
                  ? NimbusColors.cyan
                  : snap.phase == EnginePhase.error
                      ? NimbusColors.coral
                      : NimbusColors.muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          snap.message.isEmpty ? s.socksHint(c.settings.socksPort) : snap.message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: NimbusColors.muted),
        ),
        // Device VPN was asked for but this instance is not elevated: one tap
        // does the UAC relaunch instead of leaving the user to find the exe,
        // close the app and right-click it.
        if (c.needsElevation)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonalIcon(
              onPressed: c.restartAsAdmin,
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: Text(s.restartAsAdmin),
            ),
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
            Clipboard.setData(
              ClipboardData(text: '127.0.0.1:${c.settings.socksPort}'),
            );
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
            snap.isActive && snap.location.isEmpty && snap.ip.isEmpty
                ? s.detecting
                : snap.location.isEmpty
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
