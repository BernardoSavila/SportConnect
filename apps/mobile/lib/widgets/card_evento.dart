import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';

class CardEvento extends StatelessWidget {
  const CardEvento({super.key, required this.event, this.onTap});

  final TeamEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isMatch = event.type == 'match';
    final dateFmt = DateFormat('dd/MM · HH:mm');
    final accent = isMatch ? AppColors.coral : AppColors.primaryBlue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: isMatch
                          ? [AppColors.coral, const Color(0xFFFF9472)]
                          : [AppColors.primaryBlue, AppColors.skyBlue],
                    ),
                  ),
                  child: Icon(
                    isMatch ? Icons.sports_soccer : Icons.fitness_center,
                    color: isMatch ? Colors.white : AppColors.background,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(dateFmt.format(event.startTime),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                          if (event.location != null) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.place_outlined, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(event.location!,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right_rounded, color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
