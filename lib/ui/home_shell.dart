import 'package:flutter/material.dart';

import '../app_info.dart';
import '../l10n/strings.dart';
import '../services/links.dart';
import '../models/engine_state.dart';
import '../services/vpn_controller.dart';
import '../theme/voidrau_theme.dart';
import 'pages/about_page.dart';
import 'pages/config_page.dart';
import 'pages/connect_page.dart';
import 'pages/diagnostics_page.dart';
import 'pages/settings_page.dart';
import 'widgets/telegram_button.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final VpnController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.s;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final titles = [s.navConnect, s.navConfig, s.navSettings, s.navDiag, s.navAbout];
        final toast = c.toast;
        if (toast != null && toast.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
            c.toast = null;
          });
        }
        return Scaffold(
          drawer: _Drawer(
            s: s,
            index: index,
            version: c.update?.current ?? AppInfo.version,
            hasUpdate: c.update?.available == true,
            phase: c.snapshot.phase,
            onSelect: (i) {
              setState(() => index = i);
              Navigator.pop(context);
            },
          ),
          appBar: AppBar(
            title: Text(titles[index]),
            actions: [
              // Top-right Telegram mark: opens the official channel, where new
              // versions and their notes are published.
              Center(
                child: TelegramButton(
                  tooltip: '${s.telegram} · ${AppInfo.telegramHandle}',
                  onPressed: () => Links.openTelegram(),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: IndexedStack(
            index: index,
            children: [
              ConnectPage(controller: c),
              ConfigPage(controller: c),
              SettingsPage(controller: c),
              DiagnosticsPage(controller: c),
              AboutPage(controller: c),
            ],
          ),
        );
      },
    );
  }
}

class _Drawer extends StatelessWidget {
  const _Drawer({
    required this.s,
    required this.index,
    required this.onSelect,
    required this.version,
    required this.hasUpdate,
    required this.phase,
  });

  final S s;
  final int index;
  final ValueChanged<int> onSelect;
  final String version;
  final bool hasUpdate;
  final EnginePhase phase;

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData icon, String label, {bool badge = false}) {
      final active = index == i;
      return ListTile(
        selected: active,
        leading: Icon(icon, color: active ? VoidrauColors.cyan : VoidrauColors.muted),
        title: Text(label),
        trailing: badge
            ? const CircleAvatar(
                radius: 10,
                backgroundColor: VoidrauColors.coral,
                child: Text('1', style: TextStyle(fontSize: 11, color: Colors.white)),
              )
            : null,
        onTap: () => onSelect(i),
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/branding/icon.png', width: 44, height: 44),
              ),
              title: Text(s.appName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(s.brandSubtitle),
            ),
            const Divider(),
            item(0, Icons.shield_outlined, s.navConnect),
            item(1, Icons.tune, s.navConfig),
            item(2, Icons.settings_outlined, s.navSettings, badge: hasUpdate),
            item(3, Icons.terminal, s.navDiag),
            item(4, Icons.info_outline, s.navAbout),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: TelegramButton(
                size: 30,
                onPressed: () => Links.openTelegram(),
              ),
              title: Text(AppInfo.telegramHandle),
              subtitle: Text(s.telegram),
              onTap: () => Links.openTelegram(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    phase.name,
                    style: const TextStyle(color: VoidrauColors.muted),
                  ),
                  const Spacer(),
                  Text('v$version', style: const TextStyle(color: VoidrauColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
