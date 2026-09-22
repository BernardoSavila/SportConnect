import 'package:flutter/material.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'chat_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.api) {
    _loadThemePreference();
  }

  final ApiService api;
  AppUser? currentUser;

  bool get isLoggedIn => currentUser != null;

  // ---------------- TEMA (claro/escuro) ----------------
  ThemeMode themeMode = ThemeMode.system;

  Future<void> _loadThemePreference() async {
    final saved = await api.getPref('theme_mode');
    if (saved == 'dark') {
      themeMode = ThemeMode.dark;
    } else if (saved == 'light') {
      themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool enabled) async {
    themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    await api.savePref('theme_mode', enabled ? 'dark' : 'light');
    notifyListeners();
  }

  // ---------------- CHAT (ligação partilhada entre ecrãs) ----------------
  // A ligação Socket.io vive aqui (não dentro do ChatScreen) para que
  // mensagens novas continuem a chegar mesmo quando o utilizador está
  // noutro separador — é o que permite mostrar o badge de "não lidas".
  ChatService? chatService;
  int unreadChatCount = 0;
  bool _chatTabActive = false;

  Future<void> ensureChatConnected(int teamId) async {
    if (chatService != null) return;
    final token = await api.getToken();
    chatService = ChatService(baseUrl: api.baseUrl, token: token);
    chatService!.connect(teamId);
    chatService!.messages.listen((msg) {
      final isMine = msg.senderId == currentUser?.id;
      if (!_chatTabActive && !isMine) {
        unreadChatCount++;
        notifyListeners();
      }
    });
  }

  void setChatTabActive(bool active) {
    _chatTabActive = active;
    if (active && unreadChatCount != 0) {
      unreadChatCount = 0;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    currentUser = await api.login(email, password);
    notifyListeners();
  }

  /// Devolve o código de convite se a conta tiver criado uma equipa nova
  /// (via `teamName`), ou `null` se entrou numa já existente.
  Future<(String? inviteCode, bool isAssistantCoach)> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? teamCode,
    int? teamId,
    String? teamName,
  }) async {
    final (user, inviteCode, isAssistantCoach) = await api.register(
      name: name,
      email: email,
      password: password,
      role: role,
      teamCode: teamCode,
      teamId: teamId,
      teamName: teamName,
    );
    currentUser = user;
    notifyListeners();
    return (inviteCode, isAssistantCoach);
  }

  /// Faz upload da imagem escolhida e atualiza o avatar do utilizador atual.
  /// Devolve `true` em sucesso.
  Future<bool> updateAvatar(List<int> bytes, String filename) async {
    final url = await api.uploadMedia(bytes: bytes, filename: filename);
    if (url == null) return false;
    final ok = await api.updateAvatar(url);
    if (ok && currentUser != null) {
      currentUser = currentUser!.copyWith(avatarUrl: url);
      notifyListeners();
    }
    return ok;
  }

  /// Atualiza nome/posição/número de camisola e reflete de imediato no
  /// utilizador atual em memória. Devolve a mensagem de erro, ou `null`
  /// em sucesso.
  Future<String?> updateProfile({
    String? name,
    String? position,
    int? jerseyNumber,
    bool clearPosition = false,
    bool clearJerseyNumber = false,
  }) async {
    final (data, error) = await api.updateProfile(
      name: name,
      position: position,
      jerseyNumber: jerseyNumber,
      clearPosition: clearPosition,
      clearJerseyNumber: clearJerseyNumber,
    );
    if (data != null && currentUser != null) {
      final prev = currentUser!;
      currentUser = AppUser(
        id: prev.id,
        name: data['name'] as String? ?? prev.name,
        email: prev.email,
        role: prev.role,
        teamId: prev.teamId,
        avatarUrl: prev.avatarUrl,
        position: data['position'] as String?,
        jerseyNumber: data['jersey_number'] as int?,
      );
      notifyListeners();
    }
    return error;
  }

  Future<void> logout() async {
    await api.logout();
    chatService?.dispose();
    chatService = null;
    unreadChatCount = 0;
    currentUser = null;
    notifyListeners();
  }
}
