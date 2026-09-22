import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'map_view_screen.dart';
import '../models/event.dart';
import '../models/attendance_entry.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti_overlay.dart';

/// Desenha um campo de futebol/desportivo estilizado, visto de cima —
/// substitui o antigo bloco de cor sólida por uma ilustração a sério,
/// com linhas bem visíveis em vez de um ícone perdido num fundo brilhante.
class _PitchPainter extends CustomPainter {
  _PitchPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final rect = Rect.fromLTWH(
      size.width * 0.06,
      size.height * 0.14,
      size.width * 0.88,
      size.height * 0.85,
    );

    // Relvado com um leve padrão de faixas, para não ficar um bloco liso.
    final stripeWidth = rect.width / 8;
    for (int i = 0; i < 8; i++) {
      final stripeRect = Rect.fromLTWH(rect.left + stripeWidth * i, rect.top, stripeWidth, rect.height);
      canvas.drawRect(
        stripeRect,
        Paint()..color = color.withOpacity(i.isEven ? 0.05 : 0.09),
      );
    }

    // Linhas do campo.
    canvas.drawRect(rect, line);
    canvas.drawLine(Offset(rect.center.dx, rect.top), Offset(rect.center.dx, rect.bottom), line);
    canvas.drawCircle(rect.center, rect.height * 0.24, line);
    canvas.drawCircle(rect.center, 3, Paint()..color = color);

    final boxWidth = rect.width * 0.16;
    final boxHeight = rect.height * 0.52;
    final smallWidth = boxWidth * 0.5;
    final smallHeight = rect.height * 0.24;

    // Grande área (esquerda e direita).
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.center.dy - boxHeight / 2, boxWidth, boxHeight),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.right - boxWidth, rect.center.dy - boxHeight / 2, boxWidth, boxHeight),
      line,
    );

    // Pequena área.
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.center.dy - smallHeight / 2, smallWidth, smallHeight),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.right - smallWidth, rect.center.dy - smallHeight / 2, smallWidth, smallHeight),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => oldDelegate.color != color;
}

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event});

  final TeamEvent event;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  String? _status;
  bool _waitlisted = false;
  bool _saving = false;
  Future<List<AttendanceEntry>>? _rosterFuture;
  bool _isCoach = false;
  bool _savedToCalendar = false;
  bool _checkingSaved = true;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _isCoach = app.currentUser?.isCoachOrAdmin == true;
    // Vai sempre buscar o "roster" (não só para o treinador) — é a única
    // forma de saber o estado real da MINHA presença já guardado no
    // servidor, em vez de assumir "por confirmar" sempre que o ecrã abre.
    _rosterFuture = app.api.getEventRoster(widget.event.id);
    _rosterFuture!.then((roster) {
      if (!mounted) return;
      final myId = app.currentUser?.id;
      final mine = roster.where((r) => r.userId == myId).toList();
      if (mine.isNotEmpty && mine.first.status != 'pending') {
        setState(() {
          _status = mine.first.status;
          _waitlisted = mine.first.status == 'waitlist';
        });
      }
    });
    app.api.getSavedEvents().then((saved) {
      if (!mounted) return;
      setState(() {
        _savedToCalendar = saved.any((e) => e.id == widget.event.id);
        _checkingSaved = false;
      });
    });
  }

  Future<void> _confirm(String status) async {
    setState(() => _saving = true);
    final waitlisted = await context.read<AppState>().api.confirmAttendance(widget.event.id, status);
    if (!mounted) return;
    setState(() {
      _status = status;
      _waitlisted = waitlisted;
      _saving = false;
    });
    final message = waitlisted
        ? 'Evento cheio — ficaste em lista de espera. Avisamos-te se surgir vaga.'
        : status == 'present'
            ? 'Presença confirmada! 🎉'
            : status == 'absent'
                ? 'Marcado como ausente.'
                : 'Confirmação removida — voltaste a "por confirmar".';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: waitlisted
            ? AppColors.amber
            : status == 'present'
                ? AppColors.mint
                : status == 'absent'
                    ? AppColors.coral
                    : AppColors.textMuted,
        content: Text(message),
      ),
    );
    if (status == 'present' && !waitlisted) {
      ConfettiOverlay.show(context);
    }
  }

  void _openMap() {
    final location = widget.event.location;
    if (location == null || location.isEmpty) return;
    showMapDialog(context, location: location, eventTitle: widget.event.title);
  }

  Future<void> _editEvent() async {
    final e = widget.event;
    final titleController = TextEditingController(text: e.title);
    final locationController = TextEditingController(text: e.location ?? '');
    DateTime date = e.startTime;
    TimeOfDay time = TimeOfDay.fromDateTime(e.startTime);
    final duration = e.endTime.difference(e.startTime);
    String type = e.type;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar evento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Título')),
                const SizedBox(height: 10),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Local')),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setDialogState(() => date = picked);
                        },
                        child: Text('${date.day}/${date.month}/${date.year}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: time);
                          if (picked != null) setDialogState(() => time = picked);
                        },
                        child: Text(time.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'training', label: Text('Treino')),
                    ButtonSegment(value: 'match', label: Text('Jogo')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setDialogState(() => type = s.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final newStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final ok = await context.read<AppState>().api.updateEvent(
          e.id,
          title: titleController.text.trim(),
          location: locationController.text.trim(),
          type: type,
          startTime: newStart,
          endTime: newStart.add(duration),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Evento atualizado!' : 'Não foi possível guardar as alterações.'),
      ),
    );
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _cancelEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar evento'),
        content: Text('Tens a certeza que queres cancelar "${widget.event.title}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar evento'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<AppState>().api.deleteEvent(widget.event.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
          content: Text('Não foi possível cancelar o evento.'),
        ),
      );
    }
  }

  Future<void> _duplicateEvent() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.event.startTime.add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.event.startTime),
    );
    if (time == null || !mounted) return;

    final newStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final duration = widget.event.endTime.difference(widget.event.startTime);
    final newEnd = newStart.add(duration);

    final ok = await context.read<AppState>().api.duplicateEvent(widget.event.id, startTime: newStart, endTime: newEnd);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Evento duplicado para ${date.day}/${date.month}/${date.year}!' : 'Não foi possível duplicar.'),
      ),
    );
  }

  Future<void> _toggleSaveToCalendar() async {
    final app = context.read<AppState>();
    setState(() => _checkingSaved = true);
    final saved = await app.api.toggleSaveEvent(widget.event.id);
    if (!mounted) return;
    setState(() {
      _checkingSaved = false;
      if (saved != null) _savedToCalendar = saved;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: saved == null ? AppColors.coral : AppColors.mint,
        content: Text(
          saved == null
              ? 'Não foi possível guardar. Verifica a ligação.'
              : saved
                  ? 'Adicionado ao teu calendário! 📅'
                  : 'Removido do teu calendário.',
        ),
      ),
    );
  }

  Future<void> _logGameStat(int userId, String userName) async {
    final goalsController = TextEditingController(text: '0');
    final assistsController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '90');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(userName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: goalsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Golos', prefixIcon: Icon(Icons.sports_soccer)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: assistsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Assistências', prefixIcon: Icon(Icons.handshake_outlined)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minutos jogados', prefixIcon: Icon(Icons.timer_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    final ok = await context.read<AppState>().api.upsertGameStat(
          eventId: widget.event.id,
          userId: userId,
          goals: int.tryParse(goalsController.text) ?? 0,
          assists: int.tryParse(assistsController.text) ?? 0,
          minutesPlayed: int.tryParse(minutesController.text) ?? 0,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Estatísticas guardadas!' : 'Não foi possível guardar.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE, dd/MM/yyyy · HH:mm');
    final e = widget.event;
    final isMatch = e.type == 'match';
    final accent = isMatch ? AppColors.coral : AppColors.primaryBlue;
    // Um evento passa a "passado" só depois de terminar mesmo — enquanto
    // estiver a decorrer, continua totalmente acessível.
    final isPast = e.endTime.isBefore(DateTime.now());
    // Verde de relvado real e escuro — propositadamente diferente do
    // verde-lima da marca, para não repetir o problema de brilho excessivo.
    final pitchColor = isMatch ? const Color(0xFF1B4D2E) : const Color(0xFF15423A);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            backgroundColor: pitchColor,
            actions: [
              if (_isCoach)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'duplicate') _duplicateEvent();
                    if (value == 'edit') _editEvent();
                    if (value == 'cancel') _cancelEvent();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar evento')),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: ListTile(leading: Icon(Icons.copy_all_outlined), title: Text('Duplicar evento')),
                    ),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: ListTile(
                        leading: Icon(Icons.cancel_outlined, color: AppColors.coral),
                        title: Text('Cancelar evento', style: TextStyle(color: AppColors.coral)),
                      ),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.background, pitchColor],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Repete exatamente o mesmo cálculo do "rect" usado em
                    // _PitchPainter, para o emblema cobrir mesmo todo o
                    // círculo central desenhado — não uma posição aproximada.
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final pitchRect = Rect.fromLTWH(w * 0.06, h * 0.14, w * 0.88, h * 0.85);
                    final circleDiameter = pitchRect.height * 0.24 * 2;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(painter: _PitchPainter(color: Colors.white.withOpacity(0.5))),
                        Positioned(
                          left: pitchRect.center.dx - circleDiameter / 2,
                          top: pitchRect.center.dy - circleDiameter / 2,
                          width: circleDiameter,
                          height: circleDiameter,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [accent, accent.withOpacity(0.75)],
                              ),
                              boxShadow: AppShadows.glow(accent),
                              border: Border.all(color: AppColors.background, width: 3),
                            ),
                            child: Icon(
                              isMatch ? Icons.sports_soccer : Icons.fitness_center,
                              size: circleDiameter * 0.45,
                              color: AppColors.background,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 10),
                  Chip(
                    label: Text(isMatch ? 'Jogo' : 'Treino',
                        style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                    backgroundColor: accent.withOpacity(0.1),
                    side: BorderSide.none,
                  ),
                  const SizedBox(height: 16),
                  _infoRow(Icons.schedule, dateFmt.format(e.startTime)),
                  if (e.location != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _infoRow(Icons.place_outlined, e.location!)),
                        TextButton.icon(
                          onPressed: _openMap,
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('Ver mapa', style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ],
                  if (e.maxCapacity != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(Icons.groups_outlined, 'Lotação: ${e.maxCapacity} lugares'),
                  ],
                  if (e.description != null) ...[
                    const SizedBox(height: 18),
                    Text(e.description!, style: const TextStyle(fontSize: 14.5, height: 1.5)),
                  ],
                  const SizedBox(height: 16),
                  if (isPast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: const [
                          Icon(Icons.history_rounded, color: AppColors.textMuted, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Este evento já terminou — só de consulta.',
                                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                          ),
                        ],
                      ),
                    )
                  else
                    _checkingSaved
                        ? const SizedBox(
                            height: 36,
                            width: 36,
                            child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : _savedToCalendar
                            ? FilledButton.icon(
                                onPressed: _toggleSaveToCalendar,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.mint,
                                  foregroundColor: AppColors.background,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.event_available_rounded, size: 18),
                                label: const Text('No teu calendário'),
                              )
                            : OutlinedButton.icon(
                                onPressed: _toggleSaveToCalendar,
                                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                                label: const Text('Adicionar ao calendário'),
                              ),
                  const SizedBox(height: 28),
                  const Text('A tua presença', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  if (isPast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.soft),
                      child: Row(
                        children: [
                          Icon(
                            _status == 'present'
                                ? Icons.check_circle
                                : _status == 'absent'
                                    ? Icons.cancel
                                    : Icons.help_outline_rounded,
                            color: _status == 'present'
                                ? AppColors.mint
                                : _status == 'absent'
                                    ? AppColors.coral
                                    : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _status == 'present'
                                ? 'Estiveste presente'
                                : _status == 'absent'
                                    ? 'Estiveste ausente'
                                    : 'Não chegaste a confirmar',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13.5),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (_waitlisted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: const [
                            Icon(Icons.hourglass_top_rounded, color: AppColors.amber, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Estás em lista de espera — o evento está cheio.',
                                  style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600, fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _attendanceButton(
                            label: 'Presente',
                            icon: Icons.check_circle,
                            color: AppColors.mint,
                            selected: _status == 'present',
                            onTap: () => _confirm(_status == 'present' ? 'pending' : 'present'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _attendanceButton(
                            label: 'Ausente',
                            icon: Icons.cancel,
                            color: AppColors.coral,
                            selected: _status == 'absent',
                            onTap: () => _confirm(_status == 'absent' ? 'pending' : 'absent'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_isCoach) ...[
                    const SizedBox(height: 28),
                    Row(
                      children: const [
                        Icon(Icons.fact_check_outlined, color: AppColors.primaryBlue, size: 20),
                        SizedBox(width: 8),
                        Text('Confirmações da equipa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<AttendanceEntry>>(
                      future: _rosterFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final roster = snapshot.data!;
                        if (roster.isEmpty) {
                          return Text('Sem atletas na equipa.', style: TextStyle(color: Colors.grey.shade500));
                        }
                        return Column(
                          children: roster.map((r) {
                            final statusColor = r.status == 'present'
                                ? AppColors.mint
                                : r.status == 'absent'
                                    ? AppColors.coral
                                    : r.status == 'waitlist'
                                        ? AppColors.amber
                                        : AppColors.textMuted;
                            final statusLabel = r.status == 'present'
                                ? 'Presente'
                                : r.status == 'absent'
                                    ? 'Ausente'
                                    : r.status == 'waitlist'
                                        ? 'Espera'
                                        : 'Pendente';
                            final statusIcon = r.status == 'present'
                                ? Icons.check_circle
                                : r.status == 'absent'
                                    ? Icons.cancel
                                    : r.status == 'waitlist'
                                        ? Icons.hourglass_top_rounded
                                        : Icons.hourglass_empty_rounded;
                            return GestureDetector(
                              onTap: isMatch ? () => _logGameStat(r.userId, r.userName) : null,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: AppShadows.soft,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(r.userName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                    ),
                                    if (isMatch) ...[
                                      const Icon(Icons.sports_soccer, color: AppColors.textMuted, size: 15),
                                      const SizedBox(width: 10),
                                    ],
                                    Icon(statusIcon, color: statusColor, size: 16),
                                    const SizedBox(width: 6),
                                    Text(statusLabel,
                                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5))),
      ],
    );
  }

  Widget _attendanceButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: selected ? AppShadows.glow(color) : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _saving ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: selected ? Colors.white : color),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        color: selected ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
