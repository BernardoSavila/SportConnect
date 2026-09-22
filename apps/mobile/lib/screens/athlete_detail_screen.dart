import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/athlete_profile.dart';
import '../models/attendance_stats.dart';
import '../models/career_stats.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class AthleteDetailScreen extends StatefulWidget {
  const AthleteDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  State<AthleteDetailScreen> createState() => _AthleteDetailScreenState();
}

class _AthleteDetailScreenState extends State<AthleteDetailScreen> {
  late Future<AthleteProfile?> _future;
  late Future<AttendanceStats?> _attendanceFuture;
  late Future<CareerStats?> _careerFuture;

  @override
  void initState() {
    super.initState();
    final api = context.read<AppState>().api;
    _future = api.getAthleteProfile(widget.userId);
    _attendanceFuture = api.getAttendanceStats(widget.userId);
    _careerFuture = api.getCareerStats(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AthleteProfile?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final profile = snapshot.data;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
            body: const Center(child: Text('Não foi possível carregar o perfil.')),
          );
        }

        final isCoach = profile.role == 'coach';
        final sortedAchievements = [...profile.achievements]..sort((a, b) => b.awardedAt.compareTo(a.awardedAt));

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 210,
                pinned: true,
                backgroundColor: AppColors.background,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Marca de água decorativa, bem subtil, para dar
                        // textura ao fundo em vez de ficar um bloco liso.
                        Positioned(
                          right: -22,
                          top: -14,
                          child: Transform.rotate(
                            angle: -0.2,
                            child: Icon(
                              isCoach ? Icons.shield_outlined : Icons.emoji_events_outlined,
                              size: 150,
                              color: (isCoach ? AppColors.primaryBlue : AppColors.mint).withOpacity(0.07),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -30,
                          bottom: -30,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isCoach ? AppColors.primaryBlue : AppColors.mint).withOpacity(0.06),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      (isCoach ? AppColors.primaryBlue : AppColors.mint),
                                      (isCoach ? AppColors.primaryBlue : AppColors.mint).withOpacity(0.4),
                                    ],
                                  ),
                                  boxShadow: AppShadows.glow(isCoach ? AppColors.primaryBlue : AppColors.mint),
                                ),
                                child: UserAvatar(
                                  name: profile.name,
                                  avatarUrl: profile.avatarUrl,
                                  size: 82,
                                  heroTag: 'athlete-avatar-${widget.userId}',
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(profile.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: (isCoach ? AppColors.primaryBlue : AppColors.mint).withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: (isCoach ? AppColors.primaryBlue : AppColors.mint).withOpacity(0.4)),
                                ),
                                child: Text(
                                  isCoach ? 'Treinador' : 'Atleta',
                                  style: TextStyle(
                                    color: isCoach ? AppColors.primaryBlue : AppColors.mint,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statCard(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: profile.email,
                        color: AppColors.primaryBlue,
                      ),
                      if (profile.guardianName?.isNotEmpty == true || profile.emergencyContactName?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.contact_emergency_outlined, color: AppColors.coral, size: 16),
                                  SizedBox(width: 6),
                                  Text('Contactos de emergência', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textDark)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (profile.guardianName?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    'Encarregado: ${profile.guardianName}${profile.guardianPhone?.isNotEmpty == true ? ' · ${profile.guardianPhone}' : ''}',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
                                  ),
                                ),
                              if (profile.emergencyContactName?.isNotEmpty == true)
                                Text(
                                  'Emergência: ${profile.emergencyContactName}${profile.emergencyContactPhone?.isNotEmpty == true ? ' · ${profile.emergencyContactPhone}' : ''}',
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (!isCoach) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                icon: Icons.bolt,
                                label: 'Pontos totais',
                                value: '${profile.totalPoints}',
                                color: AppColors.amber,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statCard(
                                icon: Icons.military_tech,
                                label: 'Medalhas',
                                value: '${profile.achievements.length}',
                                color: AppColors.mint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: const [
                            Icon(Icons.pie_chart_outline_rounded, color: AppColors.primaryBlue, size: 20),
                            SizedBox(width: 8),
                            Text('Assiduidade', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder(
                          future: _attendanceFuture,
                          builder: (context, snap) {
                            final stats = snap.data;
                            if (stats == null) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: AppShadows.soft,
                              ),
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
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: const [
                            Icon(Icons.sports_soccer, color: AppColors.coral, size: 20),
                            SizedBox(width: 8),
                            Text('Estatísticas de carreira', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder(
                          future: _careerFuture,
                          builder: (context, snap) {
                            final stats = snap.data;
                            if (stats == null || stats.games == 0) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: AppShadows.soft,
                                ),
                                alignment: Alignment.center,
                                child: Text('Ainda sem estatísticas registadas.', style: TextStyle(color: AppColors.textMuted)),
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: _statCard(icon: Icons.sports_soccer, label: 'Golos', value: '${stats.goals}', color: AppColors.coral)),
                                const SizedBox(width: 10),
                                Expanded(child: _statCard(icon: Icons.handshake_outlined, label: 'Assist.', value: '${stats.assists}', color: AppColors.primaryBlue)),
                                const SizedBox(width: 10),
                                Expanded(child: _statCard(icon: Icons.sports, label: 'Jogos', value: '${stats.games}', color: AppColors.mint)),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: const [
                            Icon(Icons.emoji_events_rounded, color: AppColors.amber, size: 20),
                            SizedBox(width: 8),
                            Text('Histórico de gamificação',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sortedAchievements.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppShadows.soft,
                            ),
                            alignment: Alignment.center,
                            child: Text('Ainda sem pontos atribuídos.', style: TextStyle(color: AppColors.textMuted)),
                          )
                        else
                          ...sortedAchievements.map(_achievementTile),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark),
              overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _achievementTile(AchievementEntry a) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.goldGradient),
            alignment: Alignment.center,
            child: const Icon(Icons.military_tech, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.type, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
                Text(dateFmt.format(a.awardedAt), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Text('+${a.points}', style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}
