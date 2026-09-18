import 'package:flutter/material.dart';

import '../../models/engine_state.dart';
import '../../theme/nimbus_theme.dart';

class OrbButton extends StatefulWidget {
  const OrbButton({
    super.key,
    required this.phase,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final EnginePhase phase;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  State<OrbButton> createState() => _OrbButtonState();
}

class _OrbButtonState extends State<OrbButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.phase == EnginePhase.connected;
    final busy = widget.phase == EnginePhase.connecting ||
        widget.phase == EnginePhase.scanning ||
        widget.phase == EnginePhase.reconnecting ||
        widget.phase == EnginePhase.preparing;
    final error = widget.phase == EnginePhase.error;

    final colors = error
        ? const [Color(0xFFFF6B74), Color(0xFF761527)]
        : connected
            ? const [Color(0xFF2AE5F5), Color(0xFF0867E8), Color(0xFF082E83)]
            : busy
                ? const [NimbusColors.cyan, NimbusColors.violet, NimbusColors.blue]
                : const [Color(0xFFFF7680), Color(0xFF9D152C)];

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 250,
            height: 250,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [...colors, colors.first],
                  transform: busy
                      ? GradientRotation(_c.value * 6.283)
                      : const GradientRotation(-0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (connected ? NimbusColors.cyan : NimbusColors.coral)
                        .withValues(alpha: 0.35),
                    blurRadius: 42,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        connected ? Icons.shield : Icons.power_settings_new,
                        size: 42,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: 1.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.hint,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
