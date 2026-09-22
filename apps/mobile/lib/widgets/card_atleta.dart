import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

class CardAtleta extends StatelessWidget {
  const CardAtleta({
    super.key,
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.points,
    this.onTap,
    this.onMessageTap,
  });

  final int id;
  final String name;
  final String role;
  final String? avatarUrl;
  final int? points;
  final VoidCallback? onTap;
  final VoidCallback? onMessageTap;

  @override
  Widget build(BuildContext context) {
    final isCoach = role == 'coach';
    final isAdmin = role == 'admin';
    final badgeColor = isAdmin ? AppColors.coral : (isCoach ? AppColors.primaryBlue : const Color(0xFF1A9B77));
    final badgeLabel = isAdmin ? 'Admin' : (isCoach ? 'Treinador' : 'Atleta');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), boxShadow: AppShadows.soft),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                UserAvatar(
                  name: name,
                  avatarUrl: avatarUrl,
                  size: 46,
                  gradient: isAdmin
                      ? const LinearGradient(colors: [AppColors.coral, Color(0xFFB33A50)])
                      : (isCoach
                          ? const LinearGradient(colors: [AppColors.deepBlue, AppColors.primaryBlue])
                          : AppColors.cardAccentGradient),
                  heroTag: 'athlete-avatar-$id',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onMessageTap != null)
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryBlue, size: 20),
                    onPressed: onMessageTap,
                    tooltip: 'Enviar mensagem privada',
                  ),
                if (points != null)
                  Row(
                    children: [
                      const Icon(Icons.bolt, size: 16, color: AppColors.amber),
                      const SizedBox(width: 2),
                      Text('$points', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
