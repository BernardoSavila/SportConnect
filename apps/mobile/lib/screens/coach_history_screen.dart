import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class CoachHistoryScreen extends StatefulWidget {
  const CoachHistoryScreen({super.key});

  @override
  State<CoachHistoryScreen> createState() => _CoachHistoryScreenState();
}

class _CoachHistoryScreenState extends State<CoachHistoryScreen> {
  late Future<List<CoachHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.getCoachHistory();
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'Histórico de Treinadores',
            subtitle: 'Registo institucional da equipa',
            watermarkIcon: Icons.history_rounded,
            height: 130,
          ),
          Expanded(
            child: FutureBuilder<List<CoachHistoryEntry>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
                }
                final history = snap.data!;
                if (history.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Ainda sem registos históricos.', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _entryCard(history[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(CoachHistoryEntry entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: entry.current ? Border.all(color: AppColors.primaryBlue, width: 1.5) : null,
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: entry.current ? AppColors.primaryBlue : AppColors.surfaceHigh,
            child: Text(
              entry.userName.isNotEmpty ? entry.userName[0].toUpperCase() : '?',
              style: TextStyle(
                color: entry.current ? AppColors.background : AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.userName,
                        style: const TextStyle(color: AppColors.textDark, fontSize: 15.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (entry.current)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ATUAL',
                          style: TextStyle(color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmtDate(entry.startedAt)} — ${entry.endedAt != null ? _fmtDate(entry.endedAt!) : 'presente'}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
                if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(entry.notes!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
