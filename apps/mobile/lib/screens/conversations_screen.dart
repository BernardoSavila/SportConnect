import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/direct_message.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/user_avatar.dart';
import 'dm_chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<List<ConversationPreview>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().api.getConversations();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Mensagens',
            subtitle: 'Conversas privadas',
            watermarkIcon: Icons.forum_rounded,
          ),
          Expanded(
            child: FutureBuilder<List<ConversationPreview>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final conversations = snapshot.data!;
                if (conversations.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: const [
                        SizedBox(height: 100),
                        EmptyState(
                          icon: Icons.mail_outline_rounded,
                          title: 'Sem conversas ainda',
                          message: 'Vai à aba Equipa e toca no ícone de mensagem junto a um colega para começar.',
                          color: AppColors.cyan,
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: conversations.length,
                    itemBuilder: (context, i) {
                      final c = conversations[i];
                      final dateFmt = DateFormat('dd/MM HH:mm');
                      final preview = c.lastMessageType == 'image'
                          ? '📷 Imagem'
                          : c.lastMessageType == 'audio'
                              ? '🎤 Áudio'
                              : (c.lastMessage ?? '');
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), boxShadow: AppShadows.soft),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DmChatScreen(otherUserId: c.userId, otherUserName: c.userName),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  UserAvatar(name: c.userName, avatarUrl: c.avatarUrl, size: 44),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.userName,
                                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                        const SizedBox(height: 2),
                                        Text(preview,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  Text(dateFmt.format(c.sentAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
