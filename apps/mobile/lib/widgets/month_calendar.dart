import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';

/// Calendário mensal dedicado (em vez de abrir o Google Calendar externo) —
/// mostra um círculo nos dias em que o atleta "adicionou ao calendário" um
/// treino/jogo. Tocar num dia circulado mostra mais informação do evento.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.savedEvents,
    required this.onEventTap,
  });

  final List<TeamEvent> savedEvents;
  final void Function(TeamEvent event) onEventTap;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _visibleMonth;

  static const _weekdayLabels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
  static const _monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  Map<int, List<TeamEvent>> get _eventsByDay {
    final map = <int, List<TeamEvent>>{};
    for (final e in widget.savedEvents) {
      if (e.startTime.year == _visibleMonth.year && e.startTime.month == _visibleMonth.month) {
        map.putIfAbsent(e.startTime.day, () => []).add(e);
      }
    }
    return map;
  }

  void _changeMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _onDayTap(int day, List<TeamEvent> events) {
    if (events.isEmpty) return;
    HapticFeedback.lightImpact();
    if (events.length == 1) {
      widget.onEventTap(events.first);
      return;
    }
    // Mais que um evento no mesmo dia — deixa escolher qual ver.
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Dia $day', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
            const SizedBox(height: 8),
            ...events.map((e) => ListTile(
                  leading: Icon(
                    e.type == 'match' ? Icons.sports_soccer : Icons.fitness_center,
                    color: e.type == 'match' ? AppColors.coral : AppColors.primaryBlue,
                  ),
                  title: Text(e.title, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${e.startTime.hour.toString().padLeft(2, '0')}:${e.startTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onEventTap(e);
                  },
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsByDay = _eventsByDay;
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // weekday: 1=segunda..7=domingo -> quantas células vazias antes do dia 1
    final leadingBlanks = firstOfMonth.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final now = DateTime.now();
    final isCurrentMonth = now.year == _visibleMonth.year && now.month == _visibleMonth.month;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.textMuted),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: _weekdayLabels
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          for (int row = 0; row < rows; row++)
            Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final day = cellIndex - leadingBlanks + 1;
                if (day < 1 || day > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 40));
                }
                final events = eventsByDay[day] ?? [];
                final hasEvent = events.isNotEmpty;
                final isToday = isCurrentMonth && day == now.day;
                final accent = hasEvent && events.first.type == 'match' ? AppColors.coral : AppColors.primaryBlue;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onDayTap(day, events),
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasEvent ? accent.withOpacity(0.16) : Colors.transparent,
                        border: hasEvent
                            ? Border.all(color: accent, width: 2)
                            : isToday
                                ? Border.all(color: AppColors.textMuted.withOpacity(0.4), width: 1)
                                : null,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: hasEvent ? accent : AppColors.textDark,
                          fontWeight: hasEvent || isToday ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}
