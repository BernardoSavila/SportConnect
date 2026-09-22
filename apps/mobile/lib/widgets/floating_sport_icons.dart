import 'dart:math';
import 'package:flutter/material.dart';

class _FloatIcon {
  _FloatIcon({
    required this.icon,
    required this.left,
    required this.top,
    required this.size,
    required this.opacity,
    required this.phase,
    required this.bobSpeed,
    required this.bobAmount,
    required this.rotationSpeed,
  });

  final IconData icon;
  final double left; // fração 0..1 da largura
  final double top; // fração 0..1 da altura
  final double size;
  final double opacity;
  final double phase;
  final double bobSpeed;
  final double bobAmount;
  final double rotationSpeed; // voltas completas ao longo da animação (pode ser negativo)
}

/// Fundo decorativo com ícones desportivos a flutuar suavemente e a rodar
/// devagar — substitui as "bolhas" lisas por algo com mais identidade e
/// vida, sem pesar no desempenho (tudo animado com um único controller).
class FloatingSportIcons extends StatefulWidget {
  const FloatingSportIcons({super.key, this.color = Colors.white, this.baseOpacity = 0.14});

  final Color color;
  final double baseOpacity;

  @override
  State<FloatingSportIcons> createState() => _FloatingSportIconsState();
}

class _FloatingSportIconsState extends State<FloatingSportIcons> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_FloatIcon> _icons;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

    _icons = [
      _FloatIcon(
        icon: Icons.sports_soccer,
        left: 0.78,
        top: 0.06,
        size: 46,
        opacity: 1.0,
        phase: 0,
        bobSpeed: 1.0,
        bobAmount: 14,
        rotationSpeed: 0.6,
      ),
      _FloatIcon(
        icon: Icons.sports_basketball,
        left: -0.06,
        top: 0.14,
        size: 40,
        opacity: 0.85,
        phase: pi / 3,
        bobSpeed: 0.8,
        bobAmount: 10,
        rotationSpeed: -0.4,
      ),
      _FloatIcon(
        icon: Icons.emoji_events,
        left: 0.06,
        top: 0.58,
        size: 34,
        opacity: 0.8,
        phase: pi,
        bobSpeed: 1.2,
        bobAmount: 12,
        rotationSpeed: 0.25,
      ),
      _FloatIcon(
        icon: Icons.sports_volleyball,
        left: 0.88,
        top: 0.52,
        size: 30,
        opacity: 0.7,
        phase: pi / 1.5,
        bobSpeed: 0.9,
        bobAmount: 9,
        rotationSpeed: 0.5,
      ),
      _FloatIcon(
        icon: Icons.sports_tennis,
        left: 0.72,
        top: 0.74,
        size: 26,
        opacity: 0.6,
        phase: pi / 4,
        bobSpeed: 1.1,
        bobAmount: 8,
        rotationSpeed: -0.7,
      ),
      _FloatIcon(
        icon: Icons.fitness_center,
        left: -0.04,
        top: 0.82,
        size: 30,
        opacity: 0.55,
        phase: pi / 2,
        bobSpeed: 0.7,
        bobAmount: 10,
        rotationSpeed: 0.15,
      ),
      _FloatIcon(
        icon: Icons.sports_football,
        left: 0.14,
        top: 0.02,
        size: 28,
        opacity: 0.55,
        phase: pi / 6,
        bobSpeed: 1.3,
        bobAmount: 11,
        rotationSpeed: 0.45,
      ),
      _FloatIcon(
        icon: Icons.sports_rugby,
        left: 0.4,
        top: 0.9,
        size: 32,
        opacity: 0.6,
        phase: pi / 5,
        bobSpeed: 0.85,
        bobAmount: 9,
        rotationSpeed: -0.3,
      ),
      _FloatIcon(
        icon: Icons.sports_hockey,
        left: 0.94,
        top: 0.2,
        size: 24,
        opacity: 0.5,
        phase: pi / 1.2,
        bobSpeed: 1.0,
        bobAmount: 8,
        rotationSpeed: 0.55,
      ),
      _FloatIcon(
        icon: Icons.sports_golf,
        left: 0.3,
        top: 0.32,
        size: 22,
        opacity: 0.4,
        phase: pi / 2.4,
        bobSpeed: 1.4,
        bobAmount: 7,
        rotationSpeed: -0.6,
      ),
      _FloatIcon(
        icon: Icons.sports_baseball,
        left: 0.55,
        top: 0.12,
        size: 24,
        opacity: 0.45,
        phase: pi / 3.5,
        bobSpeed: 0.95,
        bobAmount: 9,
        rotationSpeed: 0.35,
      ),
      _FloatIcon(
        icon: Icons.sports_handball,
        left: -0.02,
        top: 0.42,
        size: 26,
        opacity: 0.45,
        phase: pi / 2.8,
        bobSpeed: 1.15,
        bobAmount: 10,
        rotationSpeed: -0.2,
      ),
      _FloatIcon(
        icon: Icons.pool,
        left: 0.62,
        top: 0.4,
        size: 22,
        opacity: 0.4,
        phase: pi / 1.8,
        bobSpeed: 0.75,
        bobAmount: 8,
        rotationSpeed: 0.2,
      ),
      _FloatIcon(
        icon: Icons.directions_run,
        left: 0.9,
        top: 0.88,
        size: 26,
        opacity: 0.45,
        phase: pi / 2.2,
        bobSpeed: 1.05,
        bobAmount: 9,
        rotationSpeed: -0.5,
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * pi;
              return Stack(
                children: _icons.map((f) {
                  final bob = sin(t * f.bobSpeed + f.phase) * f.bobAmount;
                  final rotation = t * f.rotationSpeed;
                  return Positioned(
                    left: f.left * w,
                    top: f.top * h + bob,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Icon(
                        f.icon,
                        size: f.size,
                        color: widget.color.withOpacity(widget.baseOpacity * f.opacity),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }
}
