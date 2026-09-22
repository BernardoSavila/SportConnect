import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/card_evento.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/empty_state.dart';
import '../widgets/month_calendar.dart';
import 'event_details_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<TeamEvent>> _future;
  late Future<List<TeamEvent>> _savedFuture;
  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;
    _future = app.api.getEvents(teamId);
    _savedFuture = app.api.getSavedEvents();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  void _openEvent(TeamEvent event) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)))
        // Ao voltar, atualiza — o utilizador pode ter guardado/removido do
        // calendário pessoal, ou confirmado presença, dentro do detalhe.
        .then((_) => setState(_load));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Calendário',
            subtitle: 'Treinos e jogos agendados',
            watermarkIcon: Icons.calendar_month_rounded,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  FutureBuilder<List<TeamEvent>>(
                    future: _savedFuture,
                    builder: (context, snapshot) {
                      return MonthCalendar(
                        savedEvents: snapshot.data ?? [],
                        onEventTap: _openEvent,
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _SegmentedToggle(
                      showPast: _showPast,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _showPast = value);
                      },
                    ),
                  ),
                  FutureBuilder<List<TeamEvent>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const ShimmerList();
                      }
                      final now = DateTime.now();
                      // Um evento "a decorrer" (já começou mas ainda não
                      // terminou) conta como próximo/acessível — só passa
                      // para "Passados" depois de terminar mesmo.
                      final upcoming = snapshot.data!.where((e) => e.endTime.isAfter(now)).toList()
                        ..sort((a, b) => a.startTime.compareTo(b.startTime));
                      final past = snapshot.data!.where((e) => !e.endTime.isAfter(now)).toList()
                        ..sort((a, b) => b.startTime.compareTo(a.startTime));

                      final events = _showPast ? past : upcoming;

                      if (events.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: EmptyState(
                            icon: _showPast ? Icons.history_rounded : Icons.event_busy_rounded,
                            title: _showPast ? 'Sem eventos passados' : 'Sem eventos agendados',
                            message: _showPast
                                ? 'Os treinos e jogos já realizados aparecem aqui.'
                                : 'Treinos e jogos criados pelo treinador aparecem aqui.',
                            color: AppColors.skyBlue,
                          ),
                        );
                      }
                      return Column(
                        children: events
                            .map((e) => Opacity(
                                  opacity: _showPast ? 0.7 : 1,
                                  child: CardEvento(event: e, onTap: () => _openEvent(e)),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alternador simples entre "Próximos" e "Passados" — eventos passados
/// são só de consulta (sem confirmar presença nem guardar no calendário).
class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.showPast, required this.onChanged});

  final bool showPast;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: _segment(context, 'Próximos', !showPast, () => onChanged(false))),
          Expanded(child: _segment(context, 'Passados', showPast, () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? AppColors.background : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
