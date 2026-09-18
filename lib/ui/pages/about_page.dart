import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../services/vpn_controller.dart';
import '../../theme/nimbus_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: [
        Center(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/branding/icon.png', width: 96, height: 96),
              ),
              const SizedBox(height: 12),
              Text(s.appName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(
                'v${controller.update?.current ?? AppInfo.version} · Aether ${AppInfo.core}',
                style: const TextStyle(color: NimbusColors.muted),
              ),
              const SizedBox(height: 8),
              Text(s.freeNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NimbusColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(s.aboutCore, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(s.aboutCoreCredit, style: const TextStyle(color: NimbusColors.muted, height: 1.45)),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://github.com/CluvexStudio/Aether'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('github.com/CluvexStudio/Aether'),
        ),
        const SizedBox(height: 16),
        Text(s.aboutApp, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(s.aboutAppCredit, style: const TextStyle(color: NimbusColors.muted, height: 1.45)),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://github.com/DnsChangerPM/VPN'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('github.com/DnsChangerPM/VPN'),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://github.com/hamvex/AetherGUI'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Inspired by hamvex/AetherGUI'),
        ),
      ],
    );
  }
}
