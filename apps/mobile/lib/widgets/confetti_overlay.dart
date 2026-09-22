import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _Particle {
  _Particle(Random rnd)
      : dx = (rnd.nextDouble() - 0.5) * 2,
        speed = 0.6 + rnd.nextDouble() * 0.5,
        size = 6 + rnd.nextDouble() * 6,
        rotationSpeed = (rnd.nextDouble() - 0.5) * 8,
        color = _kColors[rnd.nextInt(_kColors.length)],
        startXFactor = rnd.nextDouble();

  final double dx; // deslocamento horizontal (drift)
  final double speed; // velocidade de queda
  final double size;
  final double rotationSpeed;
  final Color color;
  final double startXFactor; // posição horizontal inicial (0..1)

  static const _kColors = [
    AppColors.amber,
    AppColors.primaryBlue,
    AppColors.mint,
    AppColors.coral,
    AppColors.cyan,
    Color(0xFFFFD166),
  ];
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.progress);
  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = progress;
      final y = size.height * -0.05 + (size.height * 1.1) * (t * p.speed + (1 - p.speed) * 0.15);
      final x = size.width * p.startXFactor + p.dx * 40 * t;
      final opacity = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * t * pi);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

class _ConfettiWidget extends StatefulWidget {
  const _ConfettiWidget({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<_ConfettiWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _particles = List.generate(36, (_) => _Particle(rnd));
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(_particles, _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

/// Animação de confetti para celebrar uma ação (confirmar presença,
/// atribuir pontos). Uso: `ConfettiOverlay.show(context);`
class ConfettiOverlay {
  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: _ConfettiWidget(onDone: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
  }
}
