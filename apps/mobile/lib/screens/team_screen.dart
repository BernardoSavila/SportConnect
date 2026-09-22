import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_member.dart';
import '../models/ranking_entry.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/card_atleta.dart';
import '../widgets/shimmer_loader.dart';
import 'athlete_detail_screen.dart';
import 'dm_chat_screen.dart';
import 'conversations_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late Future<List<TeamMember>> _membersFuture;
  late Future<List<RankingEntry>> _rankingFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;
    _membersFuture = app.api.getTeamMembers(teamId);
    _rankingFuture = app.api.getRanking(teamId);
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_membersFuture, _rankingFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Sporting CB',
            subtitle: 'A tua equipa',
            watermarkIcon: Icons.groups_rounded,
            actions: [
              IconButton(
                icon: const Icon(Icons.mail_outline_rounded, color: Colors.white),
                tooltip: 'Mensagens privadas',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConversationsScreen()),
                ),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<TeamMember>>(
              future: _membersFuture,
              builder: (context, memberSnap) {
                if (!memberSnap.hasData) {
                  return const ShimmerList();
                }
                final members = memberSnap.data!;
                return FutureBuilder<List<RankingEntry>>(
                  future: _rankingFuture,
                  builder: (context, rankSnap) {
                    final ranking = rankSnap.data ?? <RankingEntry>[];
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: members.length,
                        itemBuilder: (context, i) {
                          final m = members[i];
                          final myId = context.read<AppState>().currentUser?.id;
                          int? points;
                          for (final r in ranking) {
                            if (r.userId == m.id) {
                              points = r.totalPoints;
                              break;
                            }
                          }
                          return CardAtleta(
                            id: m.id,
                            name: m.name,
                            role: m.role,
                            avatarUrl: m.avatarUrl,
                            points: m.role == 'athlete' ? (points ?? 0) : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => AthleteDetailScreen(userId: m.id)),
                            ),
                            onMessageTap: m.id == myId
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => DmChatScreen(otherUserId: m.id, otherUserName: m.name)),
                                    ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
