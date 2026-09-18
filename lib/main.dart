import 'package:flutter/material.dart';

import 'models/settings.dart';
import 'services/vpn_controller.dart';
import 'theme/nimbus_theme.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NimbusApp());
}

class NimbusApp extends StatefulWidget {
  const NimbusApp({super.key});

  @override
  State<NimbusApp> createState() => _NimbusAppState();
}

class _NimbusAppState extends State<NimbusApp> {
  final controller = VpnController();

  @override
  void initState() {
    super.initState();
    controller.boot();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = controller.settings.theme;
        final dark = switch (theme) {
          ThemeChoice.dark => true,
          ThemeChoice.light => false,
          ThemeChoice.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        return MaterialApp(
          title: 'Nimbus VPN',
          debugShowCheckedModeBanner: false,
          theme: NimbusColors.light(),
          darkTheme: NimbusColors.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: controller.rtl ? const Locale('fa') : const Locale('en'),
          builder: (context, child) {
            return Directionality(
              textDirection:
                  controller.rtl ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomeShell(controller: controller),
        );
      },
    );
  }
}
