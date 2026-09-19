import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../models/settings.dart';
import '../../services/links.dart';
import '../../services/vpn_controller.dart';
import '../../theme/voidrau_theme.dart';
import '../widgets/telegram_button.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = c.s;
    final st = c.settings;
    final u = c.update;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text(s.appearance, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _seg(st.theme.name, {
          'system': s.themeSystem,
          'dark': s.themeDark,
          'light': s.themeLight,
        }, (v) {
          st.theme = ThemeChoice.values.firstWhere((e) => e.name == v);
          c.persist();
        }),
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(s.language, style: const TextStyle(color: VoidrauColors.muted)),
        ),
        _seg(st.language.name, const {
          'system': 'System',
          'en': 'English',
          'fa': 'فارسی',
        }, (v) {
          st.language = LanguageChoice.values.firstWhere((e) => e.name == v);
          c.persist();
        }),
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(s.orbStyle, style: const TextStyle(color: VoidrauColors.muted)),
        ),
        _seg(st.orbStyle.name, {
          'classic': s.orbClassic,
          'mercury': s.orbMercury,
        }, (v) {
          st.orbStyle = OrbStyle.values.firstWhere((e) => e.name == v);
          c.persist();
        }),
        SwitchListTile(
          value: st.notifications,
          title: Text(s.notifications),
          onChanged: (v) {
            st.notifications = v;
            c.persist();
          },
        ),
        ListTile(
          title: Text(s.battery),
          subtitle: Text(s.batteryHelp),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => c.engine.openBatterySettings(),
        ),
        ListTile(
          title: Text(s.vpnSettings),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => c.engine.openSystemVpnSettings(),
        ),
        const Divider(height: 32),
        Text(s.updates, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        SwitchListTile(
          value: st.autoUpdate,
          title: Text(s.autoUpdates),
          subtitle: Text(s.autoUpdatesHelp),
          onChanged: (v) {
            st.autoUpdate = v;
            c.persist();
          },
        ),
        SwitchListTile(
          value: st.autoDownload,
          title: Text(s.autoDownload),
          onChanged: (v) {
            st.autoDownload = v;
            c.persist();
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(s.qsTile, style: const TextStyle(color: VoidrauColors.muted, fontSize: 12)),
        ),
        ListTile(
          title: Text(s.currentVersion),
          trailing: Text(u?.current ?? AppInfo.version),
        ),
        ListTile(
          title: Text(s.latestVersion),
          trailing: Text(u?.latest ?? '—'),
        ),
        if (u?.available == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s.updateAvailable,
                style: const TextStyle(color: VoidrauColors.cyan)),
          ),
        if (u?.notes.isNotEmpty == true)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VoidrauColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VoidrauColors.line),
            ),
            child: Text(u!.notes, style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        FilledButton(
          onPressed: () async {
            await c.refreshUpdate(force: true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    c.releaseCheckFailed
                        ? s.updateFailed
                        : (c.update?.available == true
                            ? s.updateAvailable
                            : s.upToDate),
                  ),
                ),
              );
            }
          },
          child: Text(s.checkUpdates),
        ),
        const SizedBox(height: 8),
        if (c.downloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(value: c.downloadProgress),
          ),
        if (u?.available == true)
          FilledButton.tonal(
            onPressed: c.downloadUpdate,
            child: Text(c.downloading ? s.downloading : s.downloadUpdate),
          ),
        TextButton.icon(
          onPressed: () => Links.openReleases(),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(s.openRelease),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: TelegramButton(
            size: 30,
            onPressed: () => Links.openTelegram(),
          ),
          title: Text('${s.aboutChannel} · ${AppInfo.telegramHandle}'),
          subtitle: Text(s.aboutChannelCredit),
          onTap: () => Links.openTelegram(),
        ),
      ],
    );
  }

  Widget _seg(String value, Map<String, String> items, ValueChanged<String> onChanged) {
    return Wrap(
      spacing: 8,
      children: items.entries
          .map(
            (e) => ChoiceChip(
              label: Text(e.value),
              selected: value == e.key,
              onSelected: (_) => onChanged(e.key),
            ),
          )
          .toList(),
    );
  }
}
