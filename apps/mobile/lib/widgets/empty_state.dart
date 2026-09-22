import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Estado vazio com profundidade e uma animação subtil de flutuação —
/// substitui o ícone estático num círculo por uma composição em camadas
/// que se sente mais viva e "premium".
class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = AppColors.primaryBlue,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _float;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _float = Tween<double>(begin: -6, end: 6).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.4, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          builder: (context, entrance, child) => Opacity(
            opacity: entrance,
            child: Transform.translate(offset: Offset(0, (1 - entrance) * 12), child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _float.value),
                  child: child,
                ),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.06)),
                      ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.1)),
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [widget.color, widget.color.withOpacity(0.75)],
                          ),
                          boxShadow: AppShadows.glow(widget.color),
                        ),
                        child: Icon(widget.icon, size: 24, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
              const SizedBox(height: 6),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
