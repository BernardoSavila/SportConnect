import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/team_member.dart';
import '../models/team_info.dart';
import '../models/user.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti_overlay.dart';
import 'login_screen.dart';

class CoachPanelScreen extends StatefulWidget {
  const CoachPanelScreen({super.key});

  @override
  State<CoachPanelScreen> createState() => _CoachPanelScreenState();
}

class _CoachPanelScreenState extends State<CoachPanelScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _postController = TextEditingController();
  final _pointsTypeController = TextEditingController();
  final _pointsAmountController = TextEditingController(text: '10');
  bool _isMatch = false;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  bool _creatingEvent = false;
  bool _publishingPost = false;
  bool _awardingPoints = false;
  XFile? _pickedImage;
  late Future<List<TeamMember>> _membersFuture;
  late Future<TeamInfo?> _teamFuture;
  int? _selectedMemberId;

  // Recorrência
  bool _isRecurring = false;
  final Set<int> _recurringDays = {}; // 0=Domingo..6=Sábado
  DateTime? _recurringUntil;

  // Definições da conta (o Treinador não tem aba "Perfil" própria, por
  // isso estas opções ficam aqui, tal como já existem para o Atleta).
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;
    _membersFuture = app.api.getTeamMembers(teamId);
    _teamFuture = app.api.getTeam(teamId);
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final app = context.read<AppState>();
    final saved = await app.api.getPref('notifications_enabled');
    if (!mounted) return;
    setState(() => _notificationsEnabled = saved != 'false');
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await context.read<AppState>().api.savePref('notifications_enabled', value.toString());
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
    final error = await context.read<AppState>().updateProfile(name: name.isEmpty ? null : name);
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickRecurringUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.add(const Duration(days: 30)),
      firstDate: _date,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _recurringUntil = picked);
  }

  Future<void> _createEvent() async {
    if (_titleController.text.trim().isEmpty) return;
    if (_isRecurring && (_recurringDays.isEmpty || _recurringUntil == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
          content: Text('Escolhe os dias da semana e até quando repetir.'),
        ),
      );
      return;
    }
    setState(() => _creatingEvent = true);
    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;
    final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final end = start.add(const Duration(hours: 1, minutes: 30));

    final count = await app.api.createEvent(
      teamId: teamId,
      title: _titleController.text.trim(),
      startTime: start,
      endTime: end,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      type: _isMatch ? 'match' : 'training',
      daysOfWeek: _isRecurring ? _recurringDays.toList() : null,
      until: _isRecurring ? _recurringUntil : null,
      maxCapacity: _capacityController.text.trim().isEmpty ? null : int.tryParse(_capacityController.text.trim()),
    );

    if (!mounted) return;
    setState(() {
      _creatingEvent = false;
      _isRecurring = false;
      _recurringDays.clear();
      _recurringUntil = null;
    });
    _titleController.clear();
    _locationController.clear();
    _capacityController.clear();
    final ok = count > 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(
          ok
              ? (count > 1 ? '$count eventos criados! ✅' : 'Evento criado e já visível na agenda! ✅')
              : 'Não foi possível criar o evento.',
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (img != null) setState(() => _pickedImage = img);
  }

  Future<void> _publishPost() async {
    if (_postController.text.trim().isEmpty) return;
    setState(() => _publishingPost = true);
    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;

    String? mediaUrl;
    if (_pickedImage != null) {
      final bytes = await _pickedImage!.readAsBytes();
      mediaUrl = await app.api.uploadMedia(bytes: bytes, filename: _pickedImage!.name);
    }

    await app.api.createPost(teamId: teamId, content: _postController.text.trim(), mediaUrl: mediaUrl);

    if (!mounted) return;
    setState(() {
      _publishingPost = false;
      _postController.clear();
      _pickedImage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryBlue,
        content: const Text('Aviso publicado no feed da equipa! 📣'),
      ),
    );
  }

  Future<void> _awardPoints() async {
    if (_selectedMemberId == null || _pointsTypeController.text.trim().isEmpty) return;
    final points = int.tryParse(_pointsAmountController.text.trim()) ?? 0;
    setState(() => _awardingPoints = true);
    final app = context.read<AppState>();

    final ok = await app.api.awardPoints(
      userId: _selectedMemberId!,
      type: _pointsTypeController.text.trim(),
      points: points,
    );

    if (!mounted) return;
    setState(() => _awardingPoints = false);
    if (ok) {
      _pointsTypeController.clear();
      _pointsAmountController.text = '10';
      setState(() => _selectedMemberId = null);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.amber : AppColors.coral,
        content: Text(ok ? 'Pontos atribuídos! 🏅' : 'Não foi possível atribuir os pontos.'),
      ),
    );
    if (ok && mounted) {
      ConfettiOverlay.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Painel do Treinador',
            subtitle: 'Gerir treinos e avisos',
            watermarkIcon: Icons.sports,
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
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                FutureBuilder<TeamInfo?>(
                  future: _teamFuture,
                  builder: (context, snap) {
                    final team = snap.data;
                    if (team == null) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppShadows.soft,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Código da equipa',
                                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  team.inviteCode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Partilha com atletas para se juntarem à equipa',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Colors.white),
                            tooltip: 'Copiar código',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: team.inviteCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text('Código copiado!'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _sectionCard(
                  icon: Icons.event_available_rounded,
                  iconColor: AppColors.primaryBlue,
                  title: 'Criar evento',
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Título do treino/jogo'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text('${_date.day}/${_date.month}/${_date.year}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(_time.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Local (opcional)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Lotação máxima (opcional)',
                        hintText: 'ex: 15 — extra vão para lista de espera',
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('É um jogo?'),
                      subtitle: const Text('Desligado = treino'),
                      value: _isMatch,
                      activeColor: AppColors.coral,
                      onChanged: (v) => setState(() => _isMatch = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repetir semanalmente'),
                      subtitle: const Text('Cria vários eventos de uma vez'),
                      value: _isRecurring,
                      activeColor: AppColors.primaryBlue,
                      onChanged: (v) => setState(() => _isRecurring = v),
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          _dayChip(1, 'Seg'),
                          _dayChip(2, 'Ter'),
                          _dayChip(3, 'Qua'),
                          _dayChip(4, 'Qui'),
                          _dayChip(5, 'Sex'),
                          _dayChip(6, 'Sáb'),
                          _dayChip(0, 'Dom'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _pickRecurringUntil,
                        icon: const Icon(Icons.event_repeat, size: 16),
                        label: Text(
                          _recurringUntil == null
                              ? 'Repetir até...'
                              : 'Até ${_recurringUntil!.day}/${_recurringUntil!.month}/${_recurringUntil!.year}',
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _creatingEvent ? null : _createEvent,
                        icon: _creatingEvent
                            ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add),
                        label: const Text('Criar evento'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _sectionCard(
                  icon: Icons.campaign_rounded,
                  iconColor: AppColors.cyan,
                  title: 'Publicar aviso',
                  children: [
                    TextField(
                      controller: _postController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Mensagem para a equipa'),
                    ),
                    const SizedBox(height: 12),
                    if (_pickedImage != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(File(_pickedImage!.path), height: 140, width: double.infinity, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setState(() => _pickedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Adicionar imagem'),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.deepBlue),
                        onPressed: _publishingPost ? null : _publishPost,
                        icon: _publishingPost
                            ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                        label: const Text('Publicar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _sectionCard(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppColors.amber,
                  title: 'Atribuir pontos / medalha',
                  children: [
                    FutureBuilder<List<TeamMember>>(
                      future: _membersFuture,
                      builder: (context, snapshot) {
                        final members = snapshot.data ?? [];
                        return DropdownButtonFormField<int>(
                          value: _selectedMemberId,
                          decoration: const InputDecoration(labelText: 'Atleta'),
                          items: members
                              .where((m) => m.role == 'athlete')
                              .map((m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(m.name, style: const TextStyle(color: AppColors.textDark)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedMemberId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pointsTypeController,
                      decoration: const InputDecoration(labelText: 'Motivo (ex: MVP da Jornada)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pointsAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pontos'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.amber),
                        onPressed: _awardingPoints ? null : _awardPoints,
                        icon: _awardingPoints
                            ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.stars_rounded),
                        label: const Text('Atribuir'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _sectionCard(
                  icon: Icons.settings_outlined,
                  iconColor: AppColors.textMuted,
                  title: 'Definições da conta',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      activeColor: AppColors.primaryBlue,
                      title: const Text('Notificações', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14)),
                      subtitle: const Text('Avisos de novos eventos e mensagens', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                    ),
                    const Divider(height: 1, color: AppColors.background),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                      title: const Text('Mudar password', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: _changePassword,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayChip(int day, String label) {
    final selected = _recurringDays.contains(day);
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textDark)),
      selected: selected,
      selectedColor: AppColors.primaryBlue,
      backgroundColor: AppColors.background,
      onSelected: (v) => setState(() {
        if (v) {
          _recurringDays.add(day);
        } else {
          _recurringDays.remove(day);
        }
      }),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
