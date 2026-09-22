import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class FeedPostCard extends StatefulWidget {
  const FeedPostCard({super.key, required this.post, this.onChanged});

  final FeedPost post;

  /// Chamado depois de o treinador editar ou eliminar a publicação com
  /// sucesso, para o ecrã que apresenta a lista poder recarregar os dados.
  final VoidCallback? onChanged;

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> with SingleTickerProviderStateMixin {
  late bool _liked;
  late int _likesCount;
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likesCount = widget.post.likesCount;
    _heartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_heartController);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    // Guarda o estado anterior para conseguir repor caso o pedido falhe —
    // sem isto, um "like" que falhasse silenciosamente na rede ficava a
    // parecer guardado até à próxima vez que os dados fossem recarregados
    // (ex.: depois de sair e voltar a entrar), o que é confuso e errado.
    final previousLiked = _liked;
    final previousCount = _likesCount;

    // Atualização otimista — a UI responde de imediato, sem esperar pela rede.
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    if (_liked) _heartController.forward(from: 0);

    final app = context.read<AppState>();
    final result = await app.api.toggleLike(widget.post.id);
    if (!mounted) return;

    if (result == null) {
      // O pedido falhou de verdade — repõe o estado anterior em vez de
      // deixar a UI a mentir sobre um "like" que nunca foi guardado.
      setState(() {
        _liked = previousLiked;
        _likesCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
          content: Text('Não foi possível guardar o gosto. Verifica a ligação.'),
        ),
      );
      return;
    }

    final (liked, count) = result;
    setState(() {
      _liked = liked;
      _likesCount = count;
    });
  }

  Future<void> _editPost() async {
    final controller = TextEditingController(text: widget.post.content);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar publicação'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Texto do aviso'),
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

    final text = controller.text.trim();
    if (text.isEmpty) return;
    final ok = await context.read<AppState>().api.updatePost(widget.post.id, content: text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.mint : AppColors.coral,
        content: Text(ok ? 'Publicação atualizada!' : 'Não foi possível guardar as alterações.'),
      ),
    );
    if (ok) widget.onChanged?.call();
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar publicação'),
        content: const Text('Tens a certeza que queres eliminar este aviso? Esta ação não pode ser desfeita.'),
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

    final ok = await context.read<AppState>().api.deletePost(widget.post.id);
    if (!mounted) return;
    if (ok) {
      widget.onChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
          content: Text('Não foi possível eliminar a publicação.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isCoach = context.watch<AppState>().currentUser?.isCoachOrAdmin == true;
    final dateFmt = DateFormat('dd/MM/yyyy · HH:mm');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft,
        border: post.isOfficial ? Border.all(color: AppColors.primaryBlue, width: 1.4) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: post.isOfficial ? null : AppColors.cardAccentGradient,
                    color: post.isOfficial ? AppColors.primaryBlue : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    post.isOfficial ? Icons.verified_rounded : Icons.campaign_rounded,
                    size: 18,
                    color: AppColors.background,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.isOfficial)
                        const Text(
                          'AVISO OFICIAL · ADMIN',
                          style: TextStyle(color: AppColors.primaryBlue, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                        ),
                      Text(dateFmt.format(post.createdAt), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                if (isCoach)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: AppColors.textMuted, size: 20),
                    onSelected: (value) {
                      if (value == 'edit') _editPost();
                      if (value == 'delete') _deletePost();
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Text(post.content, style: const TextStyle(fontSize: 14.5, height: 1.4, color: AppColors.textDark)),
          ),
          if (post.mediaUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.network(
                post.mediaUrl!,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: AppColors.background,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 16, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: ScaleTransition(
                      scale: _heartScale,
                      child: Icon(
                        _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _liked ? AppColors.coral : AppColors.textMuted,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '$_likesCount',
                  style: TextStyle(
                    color: _liked ? AppColors.coral : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
