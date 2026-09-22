import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../services/links.dart';
import '../../services/vpn_controller.dart';
import '../../theme/voidrau_theme.dart';
import '../widgets/telegram_button.dart';

/// About screen: the app and the official Telegram channel.
/// No repository link is shown — all releases are on Telegram.
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
                'v${controller.update?.current ?? AppInfo.version} · ${s.aboutCore} ${AppInfo.core}',
                style: const TextStyle(color: VoidrauColors.muted),
              ),
              const SizedBox(height: 8),
              Text(s.freeNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: VoidrauColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── the application ──
        Text(s.aboutApp, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(s.aboutAppCredit,
            style: const TextStyle(color: VoidrauColors.muted, height: 1.45)),
        const Divider(height: 28),

        // ── the official channel ──
        Text(s.aboutChannel, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(s.aboutChannelCredit,
            style: const TextStyle(color: VoidrauColors.muted, height: 1.45)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: TelegramButton(size: 32, onPressed: () => Links.openTelegram()),
          title: const Text(AppInfo.telegramHandle,
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(AppInfo.telegramUrl.replaceFirst('https://', '')),
          onTap: () => Links.openTelegram(),
          trailing: const Icon(Icons.open_in_new, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          s.isFa
              ? 'تمام نسخه‌های جدید، فایل نصبی و توضیحات انتشار فقط در کانال تلگرام منتشر می‌شود: ${AppInfo.telegramHandle}'
              : 'All new builds, installers and release notes are published only on the Telegram channel: ${AppInfo.telegramHandle}',
          style: const TextStyle(color: VoidrauColors.muted, height: 1.45, fontSize: 12),
        ),
        const Divider(height: 28),

        // ── the tunnel core ──
        Text(s.aboutCore, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(s.aboutCoreCredit,
            style: const TextStyle(color: VoidrauColors.muted, height: 1.45)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('${s.coreVersion} v${AppInfo.core}'),
            _chip('Android 7+'),
            _chip('Windows 8.1+'),
            _chip('MIT'),
          ],
        ),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: VoidrauColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VoidrauColors.line),
      ),
      child: Text(text,
          style: const TextStyle(color: VoidrauColors.muted, fontSize: 12)),
    );
  }
}
