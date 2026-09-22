import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_poll.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  late Future<List<TeamPoll>> _future;
  int _teamId = 1;
  bool _isCoach = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final app = context.read<AppState>();
    _teamId = app.currentUser?.teamId ?? 1;
    _isCoach = app.currentUser?.isCoachOrAdmin == true;
    _future = app.api.getPolls(_teamId);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _vote(TeamPoll poll, int optionId) async {
    final app = context.read<AppState>();
    final updated = await app.api.votePoll(poll.id, optionId);
    if (updated == null || !mounted) return;
    setState(() {
      _future = _future.then((polls) => polls.map((p) => p.id == poll.id ? updated : p).toList());
    });
  }

  void _openCreateDialog() {
    final questionController = TextEditingController();
    final optionControllers = [TextEditingController(), TextEditingController()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nova sondagem',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: questionController,
                      decoration: const InputDecoration(labelText: 'Pergunta'),
                    ),
                    const SizedBox(height: 12),
                    ...optionControllers.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(labelText: 'Opção ${entry.key + 1}'),
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => setSheetState(() => optionControllers.add(TextEditingController())),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar opção'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final question = questionController.text.trim();
                          final options =
                              optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                          if (question.isEmpty || options.length < 2) return;
                          final ok = await context.read<AppState>().api.createPoll(
                                teamId: _teamId,
                                question: question,
                                options: options,
                              );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          if (ok) _refresh();
                        },
                        child: const Text('Publicar sondagem'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openEditDialog(TeamPoll poll) {
    final questionController = TextEditingController(text: poll.question);
    final hasVotes = poll.totalVotes > 0;
    final optionControllers = hasVotes
        ? <TextEditingController>[]
        : poll.options.map((o) => TextEditingController(text: o.text)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Editar sondagem',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: questionController,
                      decoration: const InputDecoration(labelText: 'Pergunta'),
                    ),
                    const SizedBox(height: 12),
                    if (hasVotes)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                        child: const Text(
                          'Esta sondagem já tem votos, por isso as opções já não podem ser alteradas — só a pergunta.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      )
                    else ...[
                      ...optionControllers.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: entry.value,
                            decoration: InputDecoration(labelText: 'Opção ${entry.key + 1}'),
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () => setSheetState(() => optionControllers.add(TextEditingController())),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar opção'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final question = questionController.text.trim();
                          if (question.isEmpty) return;
                          final options = hasVotes
                              ? null
                              : optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                          if (options != null && options.length < 2) return;

                          final error = await context.read<AppState>().api.updatePoll(
                                poll.id,
                                question: question,
                                options: options,
                              );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          if (error == null) {
                            _refresh();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.coral, content: Text(error)),
                            );
                          }
                        },
                        child: const Text('Guardar alterações'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deletePoll(TeamPoll poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar sondagem'),
        content: const Text('Tens a certeza que queres eliminar esta sondagem? Os votos já registados também se perdem.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<AppState>().api.deletePoll(poll.id);
    if (!mounted) return;
    if (ok) {
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
          content: Text('Não foi possível eliminar a sondagem.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Sondagens',
            subtitle: 'A opinião da equipa conta',
            watermarkIcon: Icons.poll_rounded,
            actions: [
              if (_isCoach)
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 30),
                  onPressed: _openCreateDialog,
                ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<TeamPoll>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final polls = snapshot.data!;
                if (polls.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: const [
                        SizedBox(height: 100),
                        EmptyState(
                          icon: Icons.poll_outlined,
                          title: 'Sem sondagens ainda',
                          message: 'O treinador pode criar uma sondagem para a equipa votar.',
                          color: AppColors.cyan,
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: polls.length,
                    itemBuilder: (context, i) => _PollCard(
                      poll: polls[i],
                      onVote: (optionId) => _vote(polls[i], optionId),
                      isCoach: _isCoach,
                      onEdit: () => _openEditDialog(polls[i]),
                      onDelete: () => _deletePoll(polls[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll, required this.onVote, this.isCoach = false, this.onEdit, this.onDelete});

  final TeamPoll poll;
  final ValueChanged<int> onVote;
  final bool isCoach;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final total = poll.totalVotes;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(poll.question,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
              ),
              if (isCoach)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz, color: AppColors.textMuted, size: 20),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar')),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: AppColors.coral),
                        title: Text('Eliminar', style: TextStyle(color: AppColors.coral)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...poll.options.map((o) {
            final percent = total == 0 ? 0.0 : o.votes / total;
            final isMine = poll.myVote == o.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onVote(o.id),
                child: Stack(
                  children: [
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: isMine ? Border.all(color: AppColors.primaryBlue, width: 1.5) : null,
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent.clamp(0.0, 1.0),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: AppColors.cardAccentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                o.text,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: percent > 0.35 ? AppColors.background : AppColors.textDark,
                                ),
                              ),
                            ),
                            Text(
                              '${o.votes}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: percent > 0.35 ? AppColors.background : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Text('$total voto${total == 1 ? '' : 's'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
        ],
      ),
    );
  }
}
