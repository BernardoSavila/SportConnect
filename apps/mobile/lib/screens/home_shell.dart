import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/animated_bottom_nav.dart';
import 'feed_screen.dart';
import 'calendar_screen.dart';
import 'team_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'coach_panel_screen.dart';
import 'admin_panel_screen.dart';

/// Shell principal com navegação inferior entre as secções chave da app.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppState>();
      // O Admin não usa o chat de equipa — só o Painel — por isso
      // não há necessidade de abrir a ligação em tempo real para ele.
      if (app.currentUser?.isAdmin == true) return;
      final teamId = app.currentUser?.teamId ?? 1;
      app.ensureChatConnected(teamId);
    });
  }

  void _onSelect(int i, AppState app) {
    setState(() => _index = i);
    app.setChatTabActive(i == 3);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.currentUser;
    final isCoach = user?.isCoachOrAdmin == true;
    final isAdmin = user?.isAdmin == true;

    // O Admin não navega pelas restantes secções da app (Feed,
    // Agenda, Equipa, Chat) como um Atleta ou Treinador — tem um único
    // painel de supervisão, sem barra de navegação inferior.
    if (isAdmin) {
      return const AdminPanelScreen();
    }

    final screens = [
      const FeedScreen(),
      const CalendarScreen(),
      const TeamScreen(),
      const ChatScreen(),
      isCoach ? const CoachPanelScreen() : const ProfileScreen(),
    ];

    return Scaffold(
      // IndexedStack em vez de AnimatedSwitcher: mantém os 5 ecrãs vivos
      // em memória ao mesmo tempo, só troca a visibilidade. Antes, cada
      // toque num ícone da barra de baixo destruía o ecrã anterior por
      // completo e criava um novo — obrigando a pedir os dados outra vez
      // ao servidor sempre que mudavas de separador. Agora é instantâneo.
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: AnimatedBottomNav(
        selectedIndex: _index,
        onSelected: (i) => _onSelect(i, app),
        items: [
          const NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Feed'),
          const NavItem(icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_month_rounded, label: 'Agenda'),
          const NavItem(icon: Icons.groups_outlined, selectedIcon: Icons.groups_rounded, label: 'Equipa'),
          NavItem(
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
            label: 'Chat',
            showBadge: app.unreadChatCount > 0 && _index != 3,
          ),
          NavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: isCoach ? 'Painel' : 'Perfil',
          ),
        ],
      ),
    );
  }
}
