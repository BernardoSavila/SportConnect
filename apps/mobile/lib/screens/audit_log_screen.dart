import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late Future<List<AuditLogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.getAuditLog();
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  IconData _iconFor(String action) {
    switch (action) {
      case 'update_team_profile':
        return Icons.shield_outlined;
      case 'update_coach_profile':
        return Icons.sports_outlined;
      case 'transfer_coach':
        return Icons.swap_horiz_rounded;
      case 'remove_athlete':
        return Icons.person_remove_outlined;
      default:
        return Icons.fact_check_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'Registo de Auditoria',
            subtitle: 'Ações administrativas realizadas',
            watermarkIcon: Icons.fact_check_rounded,
            height: 130,
          ),
          Expanded(
            child: FutureBuilder<List<AuditLogEntry>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
                }
                final logs = snap.data!;
                if (logs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Ainda sem ações registadas.', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _logTile(logs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _logTile(AuditLogEntry log) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(_iconFor(log.action), size: 18, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.actionLabel, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w700)),
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(log.details!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ],
                const SizedBox(height: 5),
                Text(
                  '${log.adminName} · ${_fmtDateTime(log.createdAt)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
