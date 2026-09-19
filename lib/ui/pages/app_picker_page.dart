import 'package:flutter/material.dart';

import '../../services/vpn_controller.dart';
import '../../theme/voidrau_theme.dart';

class AppPickerPage extends StatefulWidget {
  const AppPickerPage({super.key, required this.controller});
  final VpnController controller;

  @override
  State<AppPickerPage> createState() => _AppPickerPageState();
}

class _AppPickerPageState extends State<AppPickerPage> {
  String query = '';
  late Set<String> selected;

  @override
  void initState() {
    super.initState();
    selected = {...widget.controller.settings.splitApps};
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.s;
    final filtered = c.apps.where((app) {
      if (query.trim().isEmpty) return true;
      final q = query.toLowerCase();
      return '${app['label']}'.toLowerCase().contains(q) ||
          '${app['package']}'.toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(s.selectApps),
        actions: [
          TextButton(
            onPressed: () {
              c.settings.splitApps = selected.toList()..sort();
              c.persist();
              Navigator.pop(context);
            },
            child: Text(s.apply),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: s.searchApps,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: VoidrauColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  selected.addAll(filtered.map((e) => e['package'] ?? ''));
                }),
                child: Text(s.selectAll),
              ),
              TextButton(
                onPressed: () => setState(selected.clear),
                child: Text(s.clearAll),
              ),
              if (c.apps.isEmpty)
                TextButton(
                  onPressed: () async {
                    final path = await _askPath(context, s.addExe);
                    if (path != null && path.trim().isNotEmpty) {
                      setState(() => selected.add(path.trim()));
                    }
                  },
                  child: Text(s.addExe),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${selected.length} ${s.selected}',
                  style: const TextStyle(color: VoidrauColors.muted)),
            ),
          ),
          Expanded(
            child: c.apps.isEmpty
                ? ListView(
                    children: selected
                        .map(
                          (e) => CheckboxListTile(
                            value: true,
                            title: Text(e),
                            onChanged: (_) => setState(() => selected.remove(e)),
                          ),
                        )
                        .toList(),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final app = filtered[i];
                      final id = app['package'] ?? '';
                      return CheckboxListTile(
                        value: selected.contains(id),
                        title: Text(app['label'] ?? id),
                        subtitle: Text(id,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPath(BuildContext context, String title) async {
    final box = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: box, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, box.text),
            child: Text(widget.controller.s.apply),
          ),
        ],
      ),
    );
  }
}
