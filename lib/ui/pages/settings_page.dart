import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/settings.dart';
import '../../services/update_service.dart';
import '../../services/vpn_controller.dart';
import '../../theme/nimbus_theme.dart';

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
          child: Text(s.language, style: const TextStyle(color: NimbusColors.muted)),
        ),
        _seg(st.language.name, const {
          'system': 'System',
          'en': 'English',
          'fa': 'فارسی',
        }, (v) {
          st.language = LanguageChoice.values.firstWhere((e) => e.name == v);
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
        ListTile(
          title: Text(s.currentVersion),
          trailing: Text(u?.current ?? '1.0.0'),
        ),
        ListTile(
          title: Text(s.latestVersion),
          trailing: Text(u?.latest ?? '—'),
        ),
        if (u?.available == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s.updateAvailable,
                style: const TextStyle(color: NimbusColors.cyan)),
          ),
        if (u?.notes.isNotEmpty == true)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NimbusColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NimbusColors.line),
            ),
            child: Text(u!.notes, style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        FilledButton(
          onPressed: () async {
            await c.refreshUpdate();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    c.update?.available == true ? s.updateAvailable : s.upToDate,
                  ),
                ),
              );
            }
          },
          child: Text(s.checkUpdates),
        ),
        const SizedBox(height: 8),
        if (u?.available == true)
          FilledButton.tonal(
            onPressed: c.openUpdate,
            child: Text(s.downloadUpdate),
          ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(u?.htmlUrl ?? UpdateService.githubHtml),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(s.openRelease),
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
