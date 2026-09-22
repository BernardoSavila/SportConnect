import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Avatar consistente em toda a app: mostra a foto de perfil se existir,
/// caso contrário cai para um círculo com gradiente e a inicial do nome.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 44,
    this.gradient = AppColors.cardAccentGradient,
    this.heroTag,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final Gradient gradient;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      child = ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialCircle(),
        ),
      );
    } else {
      child = _initialCircle();
    }

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: child);
    }
    return child;
  }

  Widget _initialCircle() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w800, fontSize: size * 0.38),
      ),
    );
  }
}
