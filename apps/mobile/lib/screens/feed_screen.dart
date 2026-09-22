import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_post.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/empty_state.dart';
import '../widgets/floating_sport_icons.dart';
import 'coach_panel_screen.dart';
import 'polls_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<FeedPost>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final app = context.read<AppState>();
    final teamId = app.currentUser?.teamId ?? 1;
    _future = app.api.getFeed(teamId);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: AppColors.background),
          ),
          const Positioned.fill(
            child: FloatingSportIcons(color: AppColors.primaryBlue, baseOpacity: 0.07),
          ),
          Column(
            children: [
              GradientHeader(
                title: 'Feed',
                subtitle: 'Novidades da tua equipa',
                watermarkIcon: Icons.campaign_rounded,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.poll_outlined, color: Colors.white, size: 26),
                    tooltip: 'Sondagens',
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PollsScreen())),
                  ),
                  if (user?.isCoachOrAdmin == true)
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 30),
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const CoachPanelScreen())),
                    ),
                ],
              ),
              Expanded(
                child: FutureBuilder<List<FeedPost>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ShimmerList();
                    }
                    final posts = snapshot.data!;
                    if (posts.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                          children: const [
                            SizedBox(height: 100),
                            EmptyState(
                              icon: Icons.campaign_outlined,
                              title: 'Ainda não há publicações',
                              message: 'Quando o treinador publicar um aviso, aparece aqui.',
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: posts.length,
                        itemBuilder: (context, i) => TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 300 + i * 80),
                          curve: Curves.easeOut,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(offset: Offset(0, (1 - value) * 16), child: child),
                          ),
                          child: FeedPostCard(post: posts[i], onChanged: _refresh),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
