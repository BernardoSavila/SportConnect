import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/ranking_entry.dart';
import '../models/athlete_profile.dart';
import '../models/attendance_stats.dart';
import '../models/career_stats.dart';
import '../models/user.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<RankingEntry>> _future;
  late Future<AthleteProfile?> _selfProfileFuture;
  late Future<AttendanceStats?> _attendanceFuture;
  late Future<CareerStats?> _careerFuture;
  bool _uploadingAvatar = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadNotificationPref();
  }

  void _load() {
    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;
    final userId = app.currentUser?.id ?? 0;
    _future = app.api.getRanking(teamId);
    _selfProfileFuture = app.api.getAthleteProfile(userId);
    _attendanceFuture = app.api.getAttendanceStats(userId);
    _careerFuture = app.api.getCareerStats(userId);
  }

  Future<void> _loadNotificationPref() async {
    final app = context.read<AppState>();
    final saved = await app.api.getPref('notifications_enabled');
    if (!mounted) return;
    setState(() => _notificationsEnabled = saved != 'false');
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _editEmergencyContact(AthleteProfile? current) async {
    final guardianNameCtrl = TextEditingController(text: current?.guardianName ?? '');
    final guardianPhoneCtrl = TextEditingController(text: current?.guardianPhone ?? '');
    final emergencyNameCtrl = TextEditingController(text: current?.emergencyContactName ?? '');
    final emergencyPhoneCtrl = TextEditingController(text: current?.emergencyContactPhone ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contactos de emergência'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: guardianNameCtrl,
                decoration: const InputDecoration(labelText: 'Nome do encarregado de educação'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: guardianPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone do encarregado'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emergencyNameCtrl,
                decoration: const InputDecoration(labelText: 'Contacto de emergência'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emergencyPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone de emergência'),
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
    );

    if (saved != true || !mounted) return;
    final ok = await context.read<AppState>().api.updateEmergencyContact(
          guardianName: guardianNameCtrl.text.trim(),
          guardianPhone: guardianPhoneCtrl.text.trim(),
          emergencyContactName: emergencyNameCtrl.text.trim(),
          emergencyContactPhone: emergencyPhoneCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      final app = context.read<AppState>();
      _selfProfileFuture = app.api.getAthleteProfile(app.currentUser?.id ?? 0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Contactos atualizados!' : 'Não foi possível guardar.'),
      ),
    );
  }

  Future<void> _editProfile(AppUser? user) async {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final positionCtrl = TextEditingController(text: user?.position ?? '');
    final jerseyCtrl = TextEditingController(text: user?.jerseyNumber?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 10),
              TextField(
                controller: positionCtrl,
                decoration: const InputDecoration(labelText: 'Posição em campo', hintText: 'ex: Avançado, Guarda-redes...'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: jerseyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de camisola', hintText: 'ex: 10'),
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
    );

    if (saved != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final position = positionCtrl.text.trim();
    final jerseyText = jerseyCtrl.text.trim();
    final jerseyNumber = jerseyText.isEmpty ? null : int.tryParse(jerseyText);

    final error = await context.read<AppState>().updateProfile(
          name: name.isEmpty ? null : name,
          position: position.isEmpty ? null : position,
          jerseyNumber: jerseyNumber,
          clearPosition: position.isEmpty,
          clearJerseyNumber: jerseyText.isEmpty,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error == null ? AppColors.mint : AppColors.coral,
        content: Text(error ?? 'Perfil atualizado!'),
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? localError;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mudar password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password atual'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nova password', hintText: 'mín. 8 caracteres'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar nova password'),
                ),
                if (localError != null) ...[
                  const SizedBox(height: 10),
                  Text(localError!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              onPressed: () {
                if (newCtrl.text.length < 8) {
                  setDialogState(() => localError = 'A nova password deve ter pelo menos 8 caracteres.');
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setDialogState(() => localError = 'As passwords não coincidem.');
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;
    final error = await context.read<AppState>().api.changePassword(
          currentPassword: currentCtrl.text,
          newPassword: newCtrl.text,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error == null ? AppColors.mint : AppColors.coral,
        content: Text(error ?? 'Password atualizada com sucesso!'),
      ),
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await context.read<AppState>().api.savePref('notifications_enabled', value.toString());
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (img == null) return;

    setState(() => _uploadingAvatar = true);
    final bytes = await img.readAsBytes();
    final ok = await context.read<AppState>().updateAvatar(bytes, img.name);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Foto de perfil atualizada!' : 'Não foi possível atualizar a foto.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.currentUser;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: user?.name ?? 'Perfil',
            subtitle: [
              user?.role == 'coach' ? 'Treinador' : 'Atleta',
              if (user?.position?.isNotEmpty == true) user!.position!,
              if (user?.jerseyNumber != null) '#${user!.jerseyNumber}',
            ].join(' · '),
            height: 175,
            watermarkIcon: Icons.emoji_events_rounded,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'Editar perfil',
                onPressed: () => _editProfile(user),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
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
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _uploadingAvatar ? null : _pickAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: UserAvatar(
                              name: user?.name ?? '?',
                              avatarUrl: user?.avatarUrl,
                              size: 64,
                              gradient: AppColors.cardAccentGradient,
                            ),
                          ),
                          if (_uploadingAvatar)
                            Positioned.fill(
                              top: 8,
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                              ),
                            )
                          else
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.background, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 12, color: AppColors.background),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FutureBuilder<List<RankingEntry>>(
                        future: _future,
                        builder: (context, snapshot) {
                          final entry = snapshot.data?.firstWhere(
                            (r) => r.userId == user?.id,
                            orElse: () => RankingEntry(userId: 0, name: '', totalPoints: 0),
                          );
                          final position = (snapshot.data?.indexWhere((r) => r.userId == user?.id) ?? -1) + 1;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TweenAnimationBuilder<int>(
                                tween: IntTween(begin: 0, end: entry?.totalPoints ?? 0),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) => Text('$value', style: AppTextStyles.bigStat(size: 42)),
                              ),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('pts',
                                    style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _statBadge(position > 0 ? '${position}º' : '—', 'posição', AppColors.cyan),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: const [
                    Icon(Icons.emoji_events_rounded, color: AppColors.amber, size: 20),
                    SizedBox(width: 8),
                    Text('Ranking da equipa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<RankingEntry>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ShimmerList(count: 3, showAvatar: false);
                    }
                    final ranking = snapshot.data!;
                    return Column(
                      children: ranking.asMap().entries.map((entry) {
                        final i = entry.key;
                        final r = entry.value;
                        final isMe = r.userId == user?.id;
                        final medalColor = i == 0
                            ? AppColors.amber
                            : i == 1
                                ? const Color(0xFFB0B8C1)
                                : i == 2
                                    ? const Color(0xFFCD7F32)
                                    : AppColors.textMuted;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primaryBlue.withOpacity(0.1) : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: isMe ? Border.all(color: AppColors.primaryBlue.withOpacity(0.25)) : null,
                            boxShadow: isMe ? [] : AppShadows.soft,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: medalColor.withOpacity(0.15)),
                                alignment: Alignment.center,
                                child: Text('${i + 1}º',
                                    style: TextStyle(color: medalColor, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(r.name,
                                    style: TextStyle(
                                        fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                                        color: AppColors.textDark)),
                              ),
                              Text('${r.totalPoints} pts',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Icon(Icons.contact_emergency_outlined, color: AppColors.coral, size: 20),
                    SizedBox(width: 8),
                    Text('Contactos de emergência', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<AthleteProfile?>(
                  future: _selfProfileFuture,
                  builder: (context, snap) {
                    final profile = snap.data;
                    final hasContact = profile?.guardianName?.isNotEmpty == true || profile?.emergencyContactName?.isNotEmpty == true;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasContact) ...[
                            if (profile!.guardianName?.isNotEmpty == true)
                              _contactRow(Icons.family_restroom, 'Encarregado de educação', profile.guardianName!, profile.guardianPhone),
                            if (profile.emergencyContactName?.isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              _contactRow(Icons.emergency_outlined, 'Emergência', profile.emergencyContactName!, profile.emergencyContactPhone),
                            ],
                            const SizedBox(height: 12),
                          ] else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Ainda não definiste contactos de emergência.',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _editEmergencyContact(profile),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: Text(hasContact ? 'Editar contactos' : 'Adicionar contactos'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Icon(Icons.pie_chart_outline_rounded, color: AppColors.primaryBlue, size: 20),
                    SizedBox(width: 8),
                    Text('As minhas estatísticas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<AttendanceStats?>(
                  future: _attendanceFuture,
                  builder: (context, snap) {
                    final stats = snap.data;
                    if (stats == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Taxa de presença',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
                              Text('${stats.percentage}%',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.mint, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: stats.percentage / 100,
                              minHeight: 8,
                              backgroundColor: AppColors.background,
                              valueColor: const AlwaysStoppedAnimation(AppColors.mint),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${stats.present} presenças · ${stats.absent} faltas · ${stats.pending} por confirmar',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<CareerStats?>(
                  future: _careerFuture,
                  builder: (context, snap) {
                    final stats = snap.data;
                    if (stats == null || stats.games == 0) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
                        alignment: Alignment.center,
                        child: const Text('Ainda sem estatísticas de jogo registadas.', style: TextStyle(color: AppColors.textMuted)),
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: _miniStat(Icons.sports_soccer, 'Golos', '${stats.goals}', AppColors.coral)),
                        const SizedBox(width: 10),
                        Expanded(child: _miniStat(Icons.handshake_outlined, 'Assist.', '${stats.assists}', AppColors.primaryBlue)),
                        const SizedBox(width: 10),
                        Expanded(child: _miniStat(Icons.sports, 'Jogos', '${stats.games}', AppColors.mint)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Icon(Icons.military_tech_outlined, color: AppColors.amber, size: 20),
                    SizedBox(width: 8),
                    Text('Histórico de conquistas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<AthleteProfile?>(
                  future: _selfProfileFuture,
                  builder: (context, snap) {
                    final achievements = snap.data?.achievements ?? [];
                    if (achievements.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
                        alignment: Alignment.center,
                        child: const Text('Ainda sem conquistas atribuídas.', style: TextStyle(color: AppColors.textMuted)),
                      );
                    }
                    final sorted = [...achievements]..sort((a, b) => b.awardedAt.compareTo(a.awardedAt));
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
                      child: Column(
                        children: sorted.map((a) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.goldGradient),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.military_tech, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.type,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textDark)),
                                      Text(
                                        '${a.awardedAt.day}/${a.awardedAt.month}/${a.awardedAt.year}',
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text('+${a.points}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.amber, fontSize: 13.5)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Icon(Icons.settings_outlined, color: AppColors.textMuted, size: 20),
                    SizedBox(width: 8),
                    Text('Definições da conta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeColor: AppColors.primaryBlue,
                        title: const Text('Notificações', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14)),
                        subtitle: const Text('Avisos de novos eventos e mensagens', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      ),
                      const Divider(height: 1, color: AppColors.background),
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                        title: const Text('Mudar password', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14)),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        onTap: _changePassword,
                      ),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String name, String? phone) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13.5)),
              if (phone != null && phone.isNotEmpty)
                Text(phone, style: const TextStyle(color: AppColors.primaryBlue, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}
