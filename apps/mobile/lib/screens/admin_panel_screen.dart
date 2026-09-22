import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/admin_models.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'coach_history_screen.dart';
import 'membership_history_screen.dart';
import 'season_comparison_screen.dart';
import 'audit_log_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late Future<AdminTeamProfile> _teamFuture;
  late Future<AdminStats> _statsFuture;
  late Future<List<RosterEntry>> _rosterFuture;
  late Future<CoachActivityStats?> _coachStatsFuture;
  late Future<List<FeedPost>> _myAnnouncementsFuture;
  bool _generatingReport = false;
  final _announcementController = TextEditingController();
  bool _publishingAnnouncement = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = context.read<AppState>().api;
    final teamId = context.read<AppState>().currentUser?.teamId ?? 1;
    final myId = context.read<AppState>().currentUser?.id;
    _teamFuture = api.getAdminTeam();
    _statsFuture = api.getAdminStats();
    _rosterFuture = api.getTeamRoster();
    _coachStatsFuture = api.getCoachActivityStats();
    _myAnnouncementsFuture = api.getFeed(teamId).then((posts) => posts.where((p) => p.authorId == myId).toList());
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_teamFuture, _statsFuture, _rosterFuture, _coachStatsFuture, _myAnnouncementsFuture]);
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Não definida';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ---------------- Editar ficha da equipa ----------------

  Future<void> _editTeam(AdminTeamProfile team) async {
    final nameCtrl = TextEditingController(text: team.name);
    final ageCtrl = TextEditingController(text: team.ageGroup ?? '');
    final modalityCtrl = TextEditingController(text: team.modality ?? '');
    final venueCtrl = TextEditingController(text: team.homeVenue ?? '');
    DateTime? founded = team.foundedAt;
    DateTime? seasonStart = team.seasonStartedAt;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ficha da equipa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome da equipa')),
                const SizedBox(height: 12),
                TextField(controller: ageCtrl, decoration: const InputDecoration(labelText: 'Escalão (ex: Sub-15)')),
                const SizedBox(height: 12),
                TextField(controller: modalityCtrl, decoration: const InputDecoration(labelText: 'Modalidade')),
                const SizedBox(height: 12),
                TextField(controller: venueCtrl, decoration: const InputDecoration(labelText: 'Local de treino')),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(founded == null ? 'Data de fundação' : _fmtDate(founded)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: founded ?? DateTime(2015, 1, 1),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => founded = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(seasonStart == null ? 'Início da época corrente' : _fmtDate(seasonStart)),
                  subtitle: const Text('Usado para as estatísticas de "época atual"', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.event_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: seasonStart ?? DateTime.now(),
                      firstDate: DateTime(2015, 1, 1),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) setDialogState(() => seasonStart = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final ok = await context.read<AppState>().api.updateAdminTeam(
          name: nameCtrl.text.trim(),
          ageGroup: ageCtrl.text.trim(),
          modality: modalityCtrl.text.trim(),
          homeVenue: venueCtrl.text.trim(),
          foundedAt: founded,
          seasonStartedAt: seasonStart,
        );
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Ficha da equipa atualizada!' : 'Não foi possível guardar.'),
      ),
    );
  }

  // ---------------- Editar ficha do treinador ----------------

  Future<void> _editCoach(CoachProfile coach) async {
    final phoneCtrl = TextEditingController(text: coach.coachPhone ?? '');
    final certCtrl = TextEditingController(text: coach.coachCertification ?? '');
    final notesCtrl = TextEditingController(text: coach.coachNotes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ficha de ${coach.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Contacto profissional')),
              const SizedBox(height: 12),
              TextField(controller: certCtrl, decoration: const InputDecoration(labelText: 'Certificação')),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notas administrativas'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    final result = await context.read<AppState>().api.updateCoachProfile(
          coachId: coach.id,
          coachPhone: phoneCtrl.text.trim(),
          coachCertification: certCtrl.text.trim(),
          coachNotes: notesCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: result != null ? AppColors.mint : AppColors.coral,
        content: Text(result != null ? 'Ficha do treinador atualizada!' : 'Não foi possível guardar.'),
      ),
    );
  }

  // ---------------- Remover atleta ----------------

  Future<void> _removeAthlete(RosterEntry athlete) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover ${athlete.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O atleta sai da equipa, mas a conta e o histórico (presenças, conquistas) mantêm-se guardados.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Motivo (opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<AppState>().api.removeAthlete(athlete.id, reason: reasonCtrl.text.trim());
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? '${athlete.name} foi removido(a) da equipa.' : 'Não foi possível remover o atleta.'),
      ),
    );
  }

  Future<void> _removeAssistantCoach(CoachProfile coach) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover ${coach.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O treinador-adjunto sai da equipa por completo, e passa a atleta sem equipa. '
              'A conta e o histórico mantêm-se guardados.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Motivo (opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<AppState>().api.removeAthlete(coach.id, reason: reasonCtrl.text.trim());
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? '${coach.name} foi removido(a) da equipa.' : 'Não foi possível remover — confirma que não é o treinador principal.'),
      ),
    );
  }

  // ---------------- Trocar treinador ----------------

  Future<void> _transferCoach() async {
    final api = context.read<AppState>().api;
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Trocar treinador'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cria a conta do novo treinador — o treinador atual passa a atleta da equipa, '
                  'e esta mudança fica registada no histórico.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome do novo treinador')),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password (mín. 8 caracteres)',
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Motivo / notas (opcional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar troca'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passwordCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
          content: Text('Preenche o nome, o email e uma password com pelo menos 8 caracteres.'),
        ),
      );
      return;
    }

    String? error;
    final ok = await api.transferCoach(
      name: nameCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      password: passwordCtrl.text,
      notes: notesCtrl.text.trim(),
      onError: (e) => error = e,
    );
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Treinador trocado com sucesso!' : (error ?? 'Não foi possível trocar o treinador.')),
      ),
    );
  }

  // ---------------- Relatório PDF ----------------

  // ---------------- Aviso oficial ----------------

  Future<void> _publishAnnouncement() async {
    final content = _announcementController.text.trim();
    if (content.isEmpty) return;
    setState(() => _publishingAnnouncement = true);
    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;
    final ok = await app.api.createPost(teamId: teamId, content: content);
    if (!mounted) return;
    setState(() {
      _publishingAnnouncement = false;
      if (ok) {
        _announcementController.clear();
        _myAnnouncementsFuture = app.api.getFeed(teamId).then(
              (posts) => posts.where((p) => p.authorId == app.currentUser?.id).toList(),
            );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Aviso oficial publicado no feed! ✅' : 'Não foi possível publicar o aviso.'),
      ),
    );
  }

  Future<void> _editAnnouncement(FeedPost post) async {
    final contentCtrl = TextEditingController(text: post.content);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar aviso'),
        content: TextField(controller: contentCtrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Conteúdo do aviso')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final content = contentCtrl.text.trim();
    if (content.isEmpty) return;

    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;
    final ok = await app.api.updatePost(post.id, content: content);
    if (!mounted) return;
    setState(() {
      _myAnnouncementsFuture = app.api.getFeed(teamId).then(
            (posts) => posts.where((p) => p.authorId == app.currentUser?.id).toList(),
          );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Aviso atualizado!' : 'Não foi possível atualizar o aviso.'),
      ),
    );
  }

  Future<void> _deleteAnnouncement(FeedPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar aviso'),
        content: const Text('Tens a certeza que queres eliminar este aviso? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;
    final ok = await app.api.deletePost(post.id);
    if (!mounted) return;
    setState(() {
      _myAnnouncementsFuture = app.api.getFeed(teamId).then(
            (posts) => posts.where((p) => p.authorId == app.currentUser?.id).toList(),
          );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Aviso eliminado.' : 'Não foi possível eliminar o aviso.'),
      ),
    );
  }

  Future<void> _generateReport() async {
    setState(() => _generatingReport = true);
    try {
      final url = await context.read<AppState>().api.getAdminReportUrl();
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.coral,
            content: Text('Não foi possível gerar o relatório.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  Future<void> _editProfile(AppUser? user) async {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar perfil'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    await context.read<AppState>().updateProfile(name: nameCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Painel de Admin',
            subtitle: 'Supervisão e registo institucional da equipa',
            watermarkIcon: Icons.admin_panel_settings_rounded,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'Editar perfil',
                onPressed: () => _editProfile(user),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Terminar sessão',
                onPressed: () async {
                  final app = context.read<AppState>();
                  await app.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  FutureBuilder<AdminTeamProfile>(
                    future: _teamFuture,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
                        );
                      }
                      final team = snap.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _teamCard(team),
                          const SizedBox(height: 16),
                          _coachCard(team),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  FutureBuilder<AdminStats>(
                    future: _statsFuture,
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      return _statsCard(snap.data!);
                    },
                  ),
                  const SizedBox(height: 16),
                  _announcementCard(),
                  const SizedBox(height: 16),
                  FutureBuilder<List<RosterEntry>>(
                    future: _rosterFuture,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
                        );
                      }
                      return _rosterCard(snap.data!);
                    },
                  ),
                  const SizedBox(height: 16),
                  _managementCard(),
                  const SizedBox(height: 16),
                  _actionsCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamCard(AdminTeamProfile team) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Ficha da equipa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textMuted),
                onPressed: () => _editTeam(team),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(team.name, style: const TextStyle(color: AppColors.textDark, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _infoRow(Icons.groups_2_outlined, 'Escalão', team.ageGroup ?? 'Não definido'),
          _infoRow(Icons.sports_soccer_outlined, 'Modalidade', team.modality ?? 'Não definida'),
          _infoRow(Icons.place_outlined, 'Local de treino', team.homeVenue ?? 'Não definido'),
          _infoRow(Icons.calendar_today_outlined, 'Fundação', _fmtDate(team.foundedAt)),
          _infoRow(Icons.people_alt_outlined, 'Atletas', '${team.memberCount}'),
        ],
      ),
    );
  }

  Widget _coachCard(AdminTeamProfile team) {
    final coach = team.coach;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_outlined, color: AppColors.mint),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Treinador atual', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
              ),
              if (coach != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textMuted),
                  onPressed: () => _editCoach(coach),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (coach == null) ...[
            const Text('A equipa não tem treinador atribuído no momento.', style: TextStyle(color: AppColors.textMuted)),
          ] else ...[
            Text(coach.name, style: const TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(coach.email, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 10),
            _infoRow(Icons.phone_outlined, 'Contacto', coach.coachPhone ?? 'Não definido'),
            _infoRow(Icons.workspace_premium_outlined, 'Certificação', coach.coachCertification ?? 'Não definida'),
            _infoRow(Icons.event_available_outlined, 'No cargo desde', _fmtDate(coach.coachStartedAt)),
            if (coach.coachNotes != null && coach.coachNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                child: Text(coach.coachNotes!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ),
            ],
            const SizedBox(height: 14),
            FutureBuilder<CoachActivityStats?>(
              future: _coachStatsFuture,
              builder: (context, snap) {
                if (!snap.hasData || snap.data == null) return const SizedBox.shrink();
                return _coachActivityBlock(snap.data!);
              },
            ),
          ],
          if (team.assistantCoaches.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('TREINADORES ADJUNTOS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...team.assistantCoaches.map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.mint.withOpacity(0.18),
                      child: Text(
                        a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.mint, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: const TextStyle(color: AppColors.textDark, fontSize: 13.5, fontWeight: FontWeight.w700)),
                          Text(a.email, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Editar ficha',
                      onPressed: () => _editCoach(a),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined, size: 18, color: AppColors.coral),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remover da equipa',
                      onPressed: () => _removeAssistantCoach(a),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoachHistoryScreen()),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Histórico'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
                  onPressed: _transferCoach,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Trocar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coachActivityBlock(CoachActivityStats s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ATIVIDADE DE GESTÃO', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile('Dias no cargo', s.tenureDays != null ? '${s.tenureDays}' : '—', AppColors.primaryBlue),
              _statTile('Eventos', '${s.eventsCreatedTotal}', AppColors.cyan),
              _statTile('Assid.', s.attendanceRateOwnEvents != null ? '${s.attendanceRateOwnEvents}%' : '—', AppColors.mint),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile('Treinos', '${s.trainingsCreated}', AppColors.textMuted),
              _statTile('Jogos', '${s.matchesCreated}', AppColors.coral),
              _statTile('Avisos', '${s.postsPublished}', AppColors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _announcementCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text('Aviso oficial', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Publica um aviso no feed da equipa em nome da direção — aparece destacado, '
            'distinto dos avisos normais do treinador, para toda a gente perceber que vem do Admin.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _announcementController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Escreve o aviso oficial…'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _publishingAnnouncement ? null : _publishAnnouncement,
              icon: _publishingAnnouncement
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                  : const Icon(Icons.campaign_outlined),
              label: Text(_publishingAnnouncement ? 'A publicar…' : 'Publicar aviso oficial'),
            ),
          ),
          FutureBuilder<List<FeedPost>>(
            future: _myAnnouncementsFuture,
            builder: (context, snap) {
              final posts = snap.data ?? [];
              if (posts.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  const Text('OS TEUS AVISOS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...posts.map(
                    (p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(p.content, style: const TextStyle(color: AppColors.textDark, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                            onPressed: () => _editAnnouncement(p),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.coral),
                            onPressed: () => _deleteAnnouncement(p),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statsCard(AdminStats stats) {
    final items = [
      ('${stats.memberCount}', 'Atletas', AppColors.primaryBlue),
      ('${stats.attendanceRate}%', 'Assiduidade', AppColors.mint),
      ('${stats.totalEvents}', 'Eventos', AppColors.cyan),
      ('${stats.totalPointsAwarded}', 'Pontos', AppColors.amber),
      ('${stats.postCount}', 'Avisos', AppColors.coral),
      ('${stats.pollCount}', 'Sondagens', AppColors.primaryBlue),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.query_stats_rounded, color: AppColors.cyan),
              SizedBox(width: 8),
              Text('Estatísticas da equipa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: items
                .map((it) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(it.$1, style: AppTextStyles.bigStat(color: it.$3, size: 26)),
                        const SizedBox(height: 4),
                        Text(it.$2, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), textAlign: TextAlign.center),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _rosterCard(List<RosterEntry> roster) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            child: Row(
              children: [
                const Icon(Icons.groups_2_outlined, color: AppColors.mint),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Plantel — estatísticas individuais',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
                ),
                Text('${roster.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (roster.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Text('Ainda sem atletas na equipa.', style: TextStyle(color: AppColors.textMuted)),
            )
          else
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(children: roster.map(_rosterTile).toList()),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _rosterTile(RosterEntry a) {
    final rate = a.attendanceRate;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 18),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      collapsedIconColor: AppColors.textMuted,
      iconColor: AppColors.primaryBlue,
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: AppColors.surfaceHigh,
        child: Text(
          a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
          style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800),
        ),
      ),
      title: Text(a.name, style: const TextStyle(color: AppColors.textDark, fontSize: 14.5, fontWeight: FontWeight.w700)),
      subtitle: Text(
        [
          if (a.position != null) a.position,
          if (a.jerseyNumber != null) '#${a.jerseyNumber}',
        ].join(' · '),
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rate == null ? '—' : '$rate%',
            style: TextStyle(
              color: rate == null ? AppColors.textMuted : (rate >= 75 ? AppColors.mint : (rate >= 40 ? AppColors.amber : AppColors.coral)),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
        ],
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Row(
                children: [
                  _statTile('Presença', '${a.presentCount}/${a.totalDecided}', AppColors.mint),
                  _statTile('Pontos', '${a.points}', AppColors.amber),
                  _statTile('Jogos', '${a.gamesPlayed}', AppColors.cyan),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _statTile('Golos', '${a.goals}', AppColors.coral),
                  _statTile('Assist.', '${a.assists}', AppColors.primaryBlue),
                  _statTile('Minutos', '${a.minutesPlayed}\'', AppColors.textMuted),
                ],
              ),
              if (a.emergencyContactName != null || a.guardianName != null) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('CONTACTOS DE EMERGÊNCIA', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                if (a.emergencyContactName != null)
                  _contactRow(Icons.phone_outlined, a.emergencyContactName!, a.emergencyContactPhone),
                if (a.guardianName != null) _contactRow(Icons.person_outline, a.guardianName!, a.guardianPhone),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.coral, side: const BorderSide(color: AppColors.coral)),
                  onPressed: () => _removeAthlete(a),
                  icon: const Icon(Icons.person_remove_outlined, size: 17),
                  label: const Text('Remover da equipa'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String name, String? phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phone != null ? '$name · $phone' : name,
              style: const TextStyle(color: AppColors.textDark, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, color: AppColors.amber),
              SizedBox(width: 8),
              Text('Relatório geral', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ficha da equipa, histórico de treinadores, atividade da época e plantel completo, num único PDF.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generatingReport ? null : _generateReport,
              icon: _generatingReport
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                  : const Icon(Icons.description_outlined),
              label: Text(_generatingReport ? 'A gerar…' : 'Gerar relatório (PDF)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _managementCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_accounts_outlined, color: AppColors.mint),
              SizedBox(width: 8),
              Text('Gestão e registos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 12),
          _navRow(
            icon: Icons.groups_2_outlined,
            color: AppColors.mint,
            title: 'Entradas e saídas',
            subtitle: 'Histórico de membros da equipa',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembershipHistoryScreen())),
          ),
          const Divider(height: 22, color: AppColors.surfaceHigh),
          _navRow(
            icon: Icons.stacked_bar_chart_rounded,
            color: AppColors.cyan,
            title: 'Comparação entre épocas',
            subtitle: 'Estatísticas por período de treinador',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeasonComparisonScreen())),
          ),
          const Divider(height: 22, color: AppColors.surfaceHigh),
          _navRow(
            icon: Icons.fact_check_outlined,
            color: AppColors.amber,
            title: 'Registo de auditoria',
            subtitle: 'Ações administrativas realizadas',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuditLogScreen())),
          ),
        ],
      ),
    );
  }

  Widget _navRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textDark, fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
