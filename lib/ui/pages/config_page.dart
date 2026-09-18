import 'package:flutter/material.dart';

import '../../models/settings.dart';
import '../../services/vpn_controller.dart';
import '../../theme/nimbus_theme.dart';
import 'app_picker_page.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = c.s;
    final st = c.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        _label(s.mode),
        _seg(st.mode.name, {
          'vpn': s.deviceVpn,
          'proxy': s.socksProxy,
        }, (v) {
          st.mode = v == 'vpn' ? ConnectionMode.vpn : ConnectionMode.proxy;
          c.persist();
        }),
        _label(s.protocol),
        _seg(st.protocol.name, const {
          'smart': 'Smart',
          'masque': 'MASQUE',
          'wg': 'WireGuard',
          'gool': 'gool',
          'mim': 'MASQUE×2',
        }, (v) {
          st.protocol = Protocol.values.firstWhere((e) => e.name == v);
          c.persist();
        }, wrap: true),
        _label(s.scan),
        _dropdown(
          st.scan.name,
          {
            'turbo': s.scanTurbo,
            'balanced': s.scanBalanced,
            'thorough': s.scanThorough,
            'stealth': s.scanStealth,
            'ironclad': s.scanIronclad,
          },
          (v) {
            st.scan = ScanMode.values.firstWhere((e) => e.name == v);
            c.persist();
          },
        ),
        _label(s.obfuscation),
        _dropdown(st.obfuscation, const {
          'auto': 'auto',
          'firewall': 'firewall',
          'gfw': 'gfw',
          'balanced': 'balanced',
          'aggressive': 'aggressive',
          'light': 'light',
          'off': 'off',
        }, (v) {
          st.obfuscation = v;
          c.persist();
        }),
        if (st.protocol == Protocol.masque ||
            st.protocol == Protocol.mim ||
            st.protocol == Protocol.smart) ...[
          _label(s.transport),
          _seg(st.transport.name, const {'h3': 'HTTP/3', 'h2': 'HTTP/2'}, (v) {
            st.transport =
                v == 'h2' ? MasqueTransport.h2 : MasqueTransport.h3;
            c.persist();
          }),
        ],
        _label(s.ipVersion),
        _seg(st.ipVersion.name, const {
          'v4': 'IPv4',
          'v6': 'IPv6',
          'dual': 'Dual',
        }, (v) {
          st.ipVersion = IpVersion.values.firstWhere((e) => e.name == v);
          c.persist();
        }),
        _label(s.endpoint),
        TextFormField(
          initialValue: st.endpoint,
          decoration: InputDecoration(
            hintText: 'Automatic',
            filled: true,
            fillColor: NimbusColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (v) => st.endpoint = v,
          onFieldSubmitted: (_) => c.persist(),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: st.quickReconnect,
          title: Text(s.autoReconnect),
          subtitle: Text(s.autoReconnectHelp),
          onChanged: (v) {
            st.quickReconnect = v;
            c.persist();
          },
        ),
        SwitchListTile(
          value: st.fragment,
          title: Text(s.fragment),
          subtitle: Text(s.fragmentHelp),
          onChanged: (v) {
            st.fragment = v;
            c.persist();
          },
        ),
        SwitchListTile(
          value: st.autoConnect,
          title: Text(s.autoConnect),
          onChanged: (v) {
            st.autoConnect = v;
            c.persist();
          },
        ),
        SwitchListTile(
          value: st.killSwitch,
          title: Text(s.killSwitch),
          subtitle: Text(s.killSwitchHelp),
          onChanged: (v) {
            st.killSwitch = v;
            c.persist();
          },
        ),
        SwitchListTile(
          value: st.privateDns,
          title: Text(s.privateDns),
          onChanged: (v) {
            st.privateDns = v;
            c.persist();
          },
        ),
        SwitchListTile(
          value: st.lanShare,
          title: Text(s.lanShare),
          subtitle: Text(s.lanShareHelp),
          onChanged: (v) {
            st.lanShare = v;
            c.persist();
          },
        ),
        _label(s.splitTitle),
        Text(s.splitHelp, style: const TextStyle(color: NimbusColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        _seg(st.splitMode.name, {
          'off': s.splitOff,
          'include': s.splitInclude,
          'exclude': s.splitExclude,
        }, (v) {
          st.splitMode = SplitMode.values.firstWhere((e) => e.name == v);
          c.persist();
        }, wrap: true),
        if (st.splitMode != SplitMode.off)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AppPickerPage(controller: c),
                ),
              ),
              child: Text('${s.selectApps}  (${st.splitApps.length} ${s.selected})'),
            ),
          ),
        if (st.lanShare)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${s.lanAddress}: 0.0.0.0:1819',
                style: const TextStyle(color: NimbusColors.muted)),
          ),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: () {
            c.settings = VpnSettings(
              theme: st.theme,
              language: st.language,
            );
            c.persist();
          },
          child: Text(s.reset),
        ),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(color: NimbusColors.muted, fontSize: 13)),
      );

  Widget _seg(
    String value,
    Map<String, String> items,
    ValueChanged<String> onChanged, {
    bool wrap = false,
  }) {
    final buttons = items.entries
        .map(
          (e) => ChoiceChip(
            label: Text(e.value, style: const TextStyle(fontSize: 12)),
            selected: value == e.key,
            onSelected: (_) => onChanged(e.key),
          ),
        )
        .toList();
    if (wrap) {
      return Wrap(spacing: 8, runSpacing: 8, children: buttons);
    }
    return Wrap(spacing: 8, children: buttons);
  }

  Widget _dropdown(
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: NimbusColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
