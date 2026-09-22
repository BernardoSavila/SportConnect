import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class MembershipHistoryScreen extends StatefulWidget {
  const MembershipHistoryScreen({super.key});

  @override
  State<MembershipHistoryScreen> createState() => _MembershipHistoryScreenState();
}

class _MembershipHistoryScreenState extends State<MembershipHistoryScreen> {
  late Future<List<MembershipEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.getMembershipHistory();
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'Entradas e Saídas',
            subtitle: 'Histórico de membros da equipa',
            watermarkIcon: Icons.groups_2_rounded,
            height: 130,
          ),
          Expanded(
            child: FutureBuilder<List<MembershipEntry>>(
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
                      child: Text('Ainda sem registos de entrada.', style: TextStyle(color: AppColors.textMuted)),
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

  Widget _entryCard(MembershipEntry entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: entry.current ? Border.all(color: AppColors.mint, width: 1.5) : null,
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: entry.current ? AppColors.mint : AppColors.surfaceHigh,
            child: Text(
              entry.userName.isNotEmpty ? entry.userName[0].toUpperCase() : '?',
              style: TextStyle(color: entry.current ? AppColors.background : AppColors.textMuted, fontWeight: FontWeight.w800),
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
                      child: Text(entry.userName, style: const TextStyle(color: AppColors.textDark, fontSize: 15.5, fontWeight: FontWeight.w800)),
                    ),
                    if (entry.current)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.mint.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Text('NA EQUIPA', style: TextStyle(color: AppColors.mint, fontSize: 10, fontWeight: FontWeight.w800)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Text('SAIU', style: TextStyle(color: AppColors.coral, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmtDate(entry.joinedAt)} — ${entry.leftAt != null ? _fmtDate(entry.leftAt!) : 'presente'}',
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
