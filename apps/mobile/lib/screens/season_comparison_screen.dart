import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class SeasonComparisonScreen extends StatefulWidget {
  const SeasonComparisonScreen({super.key});

  @override
  State<SeasonComparisonScreen> createState() => _SeasonComparisonScreenState();
}

class _SeasonComparisonScreenState extends State<SeasonComparisonScreen> {
  late Future<List<SeasonPeriod>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.getSeasonComparison();
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'Comparação entre Épocas',
            subtitle: 'Estatísticas por período de treinador',
            watermarkIcon: Icons.stacked_bar_chart_rounded,
            height: 130,
          ),
          Expanded(
            child: FutureBuilder<List<SeasonPeriod>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
                }
                final periods = snap.data!.reversed.toList(); // mais recente primeiro
                if (periods.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Ainda sem períodos para comparar.', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: periods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _periodCard(periods[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodCard(SeasonPeriod p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: p.current ? Border.all(color: AppColors.primaryBlue, width: 1.5) : null,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Era de ${p.coachName}', style: const TextStyle(color: AppColors.textDark, fontSize: 15.5, fontWeight: FontWeight.w800)),
              ),
              if (p.current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('ATUAL', style: TextStyle(color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${_fmtDate(p.startedAt)} — ${p.endedAt != null ? _fmtDate(p.endedAt!) : 'presente'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('Eventos', '${p.eventsTotal}', AppColors.cyan),
              _stat('Treinos', '${p.trainings}', AppColors.textMuted),
              _stat('Jogos', '${p.matches}', AppColors.coral),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat('Assiduidade', p.attendanceRate != null ? '${p.attendanceRate}%' : '—', AppColors.mint),
              _stat('Pontos', '${p.pointsAwarded}', AppColors.amber),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
        ],
      ),
    );
  }
}
