import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// dart:io não existe na Web — só é importado quando não estamos a correr
// no browser, via a verificação kIsWeb antes de qualquer uso de Platform.
import 'dart:io' show Platform;

import '../models/user.dart';
import '../models/event.dart';
import '../models/post.dart';
import '../models/ranking_entry.dart';
import '../models/chat_message.dart';
import '../models/team_member.dart';
import '../models/athlete_profile.dart';
import '../models/attendance_entry.dart';
import '../models/attendance_stats.dart';
import '../models/career_stats.dart';
import '../models/team_poll.dart';
import '../models/team_info.dart';
import '../models/direct_message.dart';
import '../models/admin_models.dart';

/// Endereço do servidor consoante a plataforma onde a app está a correr —
/// cada uma "vê" a máquina local de forma diferente:
/// - Chrome/Web e macOS: a app corre na mesma máquina que o servidor, por
///   isso "localhost" funciona diretamente.
/// - Emulador Android: "10.0.2.2" é o alias especial que o emulador usa
///   para apontar para o localhost da máquina anfitriã.
/// - iOS (simulador ou dispositivo físico): também "localhost" no
///   simulador; num iPhone físico seria preciso o IP real da máquina na
///   rede local (Wi-Fi), não "localhost".
String _defaultBaseUrl() {
  if (kIsWeb) return 'http://localhost:3000';
  if (Platform.isAndroid) return 'http://10.0.2.2:3000';
  return 'http://localhost:3000';
}

/// Serviço central de acesso à API SportConnect.
///
/// Para o Projeto 1 (esqueleto), todos os métodos têm um fallback para
/// dados mockados caso o pedido HTTP falhe (ex.: backend ainda não está
/// a correr). Isto permite navegar por toda a app com dados estáticos,
/// como pedido no documento de objetivos, e passar a consumir a API real
/// assim que o servidor esteja disponível — basta que `baseUrl` aponte
/// para o endereço correto.
class ApiService {
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl();

  final String baseUrl;
  final _storage = const FlutterSecureStorage();

  Future<void> _saveToken(String token) => _storage.write(key: 'jwt_token', value: token);
  Future<String?> getToken() => _storage.read(key: 'jwt_token');
  Future<void> logout() => _storage.delete(key: 'jwt_token');

  /// Guarda preferências simples do utilizador (ex.: tema escuro), no
  /// mesmo armazenamento seguro usado para o token — evita adicionar
  /// mais uma dependência só para isto.
  Future<void> savePref(String key, String value) => _storage.write(key: 'pref_$key', value: value);
  Future<String?> getPref(String key) => _storage.read(key: 'pref_$key');

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ---------------- AUTH ----------------

  Future<AppUser> login(String email, String password) async {
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Só cai aqui em falhas de ligação reais (servidor em baixo, sem
      // rede, timeout) — nunca por causa de credenciais erradas, já que
      // nesse caso o servidor respondeu e sabemos exatamente o que aconteceu.
      await _saveToken('mock-token');
      return AppUser(id: 1, name: 'Bernardo Costa', email: email, role: 'athlete', teamId: 1);
    }

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await _saveToken(data['token']);
      return AppUser.fromJson(data['user']);
    }

    // O servidor respondeu e rejeitou as credenciais — mostra o erro a
    // sério, em vez de disfarçar com um login de demonstração.
    String message = 'Credenciais inválidas';
    try {
      final data = jsonDecode(res.body);
      if (data['error'] != null) message = data['error'];
    } catch (_) {
      // corpo não é JSON válido — mantém a mensagem por omissão
    }
    throw Exception(message);
  }

  /// Pede um código de recuperação de password para o email indicado.
  /// O servidor responde sempre com sucesso (por segurança, não revela
  /// se o email existe ou não) — por isso este método só lança [Exception]
  /// em falhas de ligação reais.
  Future<void> forgotPassword(String email) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/forgot-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('Não foi possível pedir a recuperação. Tenta novamente.');
    }
  }

  /// Confirma o código de recuperação recebido por email e define a nova
  /// password. Lança [Exception] com uma mensagem legível se o código for
  /// inválido, expirado, ou já usado.
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/reset-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'code': code, 'new_password': newPassword}),
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) return;

    String message = 'Código inválido ou expirado.';
    try {
      final data = jsonDecode(res.body);
      if (data['error'] != null) message = data['error'];
    } catch (_) {
      // corpo não é JSON válido — mantém a mensagem por omissão
    }
    throw Exception(message);
  }

  /// Regista um novo utilizador. Lança [Exception] com uma mensagem legível
  /// em caso de erro (ex.: email já registado), para o ecrã mostrar ao utilizador.
  /// Devolve o utilizador recém-criado e, se a conta tiver criado uma
  /// equipa nova (via `teamName`), o código de convite dessa equipa —
  /// para o ecrã de registo o poder mostrar de imediato.
  Future<(AppUser user, String? teamInviteCode, bool isAssistantCoach)> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? teamCode,
    int? teamId,
    String? teamName,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'role': role,
            'team_code': teamCode,
            'team_id': teamId,
            'team_name': teamName,
          }),
        )
        .timeout(const Duration(seconds: 8));

    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      await _saveToken(data['token']);
      final inviteCode = data['team']?['invite_code'] as String?;
      final isAssistantCoach = data['is_assistant_coach'] == true;
      return (AppUser.fromJson(data['user']), inviteCode, isAssistantCoach);
    }
    throw Exception(data['error'] ?? 'Não foi possível criar a conta.');
  }

  // ---------------- EVENTS ----------------

  Future<List<TeamEvent>> getEvents(int teamId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/events?teamId=$teamId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => TeamEvent.fromJson(e)).toList();
      }
      throw Exception('Falha ao obter eventos');
    } catch (_) {
      return _mockEvents(teamId);
    }
  }

  /// Confirma presença/ausência. Devolve `true` se a resposta ficou em
  /// lista de espera (evento com lotação esgotada), `false` caso contrário.
  Future<bool> confirmAttendance(int eventId, String status) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/events/$eventId/attendance'),
            headers: await _authHeaders(),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['waitlisted'] == true;
      }
      return false;
    } catch (_) {
      return false; // modo offline — TODO: mostrar feedback offline.
    }
  }

  /// Lista completa de atletas da equipa com o respetivo estado de
  /// presença no evento — usado na vista do treinador.
  Future<List<AttendanceEntry>> getEventRoster(int eventId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/events/$eventId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List roster = data['attendance'] ?? [];
        return roster.map((e) => AttendanceEntry.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Cria um evento. Se `daysOfWeek`/`until` forem indicados, cria uma
  /// ocorrência recorrente (ex.: "todas as terças até dia X"). Devolve o
  /// número de eventos criados (1 se não for recorrente).
  Future<int> createEvent({
    required int teamId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    required String type,
    List<int>? daysOfWeek,
    DateTime? until,
    int? maxCapacity,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/events'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'team_id': teamId,
              'title': title,
              'description': description,
              'start_time': startTime.toUtc().toIso8601String(),
              'end_time': endTime.toUtc().toIso8601String(),
              'location': location,
              'type': type,
              'max_capacity': maxCapacity,
              if (daysOfWeek != null && daysOfWeek.isNotEmpty && until != null)
                'recurrence': {
                  'days_of_week': daysOfWeek,
                  'until': until.toUtc().toIso8601String(),
                },
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 201) return 0;
      final data = jsonDecode(res.body);
      return (data is Map && data.containsKey('count')) ? data['count'] as int : 1;
    } catch (_) {
      return 0; // modo offline/demo
    }
  }

  /// Duplica um evento existente para uma nova data/hora.
  Future<bool> duplicateEvent(int eventId, {required DateTime startTime, required DateTime endTime}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/events/$eventId/duplicate'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'start_time': startTime.toUtc().toIso8601String(),
              'end_time': endTime.toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Edita um evento existente (apenas treinador). Todos os parâmetros são
  /// opcionais — só o que for enviado é alterado no servidor.
  Future<bool> updateEvent(
    int eventId, {
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? type,
    int? maxCapacity,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (startTime != null) body['start_time'] = startTime.toUtc().toIso8601String();
      if (endTime != null) body['end_time'] = endTime.toUtc().toIso8601String();
      if (location != null) body['location'] = location;
      if (type != null) body['type'] = type;
      if (maxCapacity != null) body['max_capacity'] = maxCapacity;

      final res = await http
          .patch(Uri.parse('$baseUrl/events/$eventId'), headers: await _authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Cancela (elimina) um evento existente (apenas treinador).
  Future<bool> deleteEvent(int eventId) async {
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/events/$eventId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Atualiza os contactos de emergência/encarregado de educação do
  /// próprio utilizador autenticado.
  Future<bool> updateEmergencyContact({
    String? guardianName,
    String? guardianPhone,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/users/me/contact'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'guardian_name': guardianName,
              'guardian_phone': guardianPhone,
              'emergency_contact_name': emergencyContactName,
              'emergency_contact_phone': emergencyContactPhone,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------------- MENSAGENS PRIVADAS (DM) ----------------

  Future<List<ConversationPreview>> getConversations() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/messages/direct/conversations'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => ConversationPreview.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<DirectMessageModel>> getDirectHistory(int withUserId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/messages/direct/$withUserId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => DirectMessageModel.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ---------------- FEED ----------------

  Future<List<FeedPost>> getFeed(int teamId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/feed?teamId=$teamId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => FeedPost.fromJson(e)).toList();
      }
      throw Exception('Falha ao obter feed');
    } catch (_) {
      return _mockFeed(teamId);
    }
  }

  Future<bool> createPost({required int teamId, required String content, String? mediaUrl}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/posts'),
            headers: await _authHeaders(),
            body: jsonEncode({'team_id': teamId, 'content': content, 'media_url': mediaUrl}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Edita o texto e/ou a imagem de uma publicação existente (apenas
  /// treinador).
  Future<bool> updatePost(int postId, {String? content, String? mediaUrl}) async {
    try {
      final body = <String, dynamic>{};
      if (content != null) body['content'] = content;
      if (mediaUrl != null) body['media_url'] = mediaUrl;

      final res = await http
          .patch(Uri.parse('$baseUrl/posts/$postId'), headers: await _authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Elimina uma publicação existente (apenas treinador).
  Future<bool> deletePost(int postId) async {
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/posts/$postId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Alterna o "gosto" do utilizador autenticado num post. Devolve os
  /// novos valores para atualização otimista da UI, ou `null` em falha.
  Future<(bool liked, int count)?> toggleLike(int postId) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/posts/$postId/like'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['liked_by_me'] as bool, data['likes_count'] as int);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Faz upload de uma imagem (bytes + nome de ficheiro) e devolve o URL
  /// público para usar como `media_url` num post. Usa multipart/form-data.
  Future<String?> uploadMedia({required List<int> bytes, required String filename}) async {
    try {
      final uri = Uri.parse('$baseUrl/media/upload');
      final request = http.MultipartRequest('POST', uri);
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['url'] as String;
      }
      return null;
    } catch (_) {
      return null; // sem backend disponível — o post é criado sem imagem
    }
  }

  // ---------------- RANKING ----------------

  Future<List<RankingEntry>> getRanking(int teamId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/ranking?teamId=$teamId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => RankingEntry.fromJson(e)).toList();
      }
      throw Exception('Falha ao obter ranking');
    } catch (_) {
      return [
        RankingEntry(userId: 1, name: 'Bernardo Costa', totalPoints: 50),
        RankingEntry(userId: 2, name: 'Ana Ferreira', totalPoints: 20),
      ];
    }
  }

  Future<TeamInfo?> getTeam(int teamId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/teams/$teamId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return TeamInfo.fromJson(jsonDecode(res.body));
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<TeamMember>> getTeamMembers(int teamId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/teams/$teamId/members'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => TeamMember.fromJson(e)).toList();
      }
      throw Exception('Falha ao obter membros da equipa');
    } catch (_) {
      return [
        TeamMember(id: 2, name: 'Bernardo Costa', email: 'atleta1@sportconnect.pt', role: 'athlete'),
        TeamMember(id: 3, name: 'Ana Ferreira', email: 'atleta2@sportconnect.pt', role: 'athlete'),
      ];
    }
  }

  /// Atribui pontos/medalha a um atleta (treinador). Devolve `true` em sucesso.
  Future<bool> awardPoints({required int userId, required String type, required int points}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/achievements'),
            headers: await _authHeaders(),
            body: jsonEncode({'user_id': userId, 'type': type, 'points': points}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Perfil completo de um atleta/treinador, incluindo histórico de
  /// conquistas de gamificação — usado no ecrã de detalhe na aba Equipa.
  Future<AthleteProfile?> getAthleteProfile(int userId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/users/$userId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return AthleteProfile.fromJson(jsonDecode(res.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<AttendanceStats?> getAttendanceStats(int userId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/users/$userId/attendance-stats'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return AttendanceStats.fromJson(jsonDecode(res.body));
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<CareerStats?> getCareerStats(int userId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/users/$userId/career-stats'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return CareerStats.fromJson(jsonDecode(res.body));
      return null;
    } catch (_) {
      return null;
    }
  }

  /// URL do ficheiro .ics do evento — pronto a abrir com [url_launcher]
  /// (a app de calendário do telemóvel trata do resto).
  Future<String> getEventIcsUrl(int eventId) async {
    final token = await getToken();
    return '$baseUrl/events/$eventId/ics${token != null ? '?token=$token' : ''}';
  }

  /// Adiciona/remove um evento do calendário pessoal (dentro da app).
  /// Devolve o novo estado: true = ficou guardado, false = foi removido.
  Future<bool?> toggleSaveEvent(int eventId) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/events/$eventId/save'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['saved'] as bool;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Lista os eventos que o utilizador guardou no calendário pessoal —
  /// usado para desenhar os círculos no calendário mensal.
  Future<List<TeamEvent>> getSavedEvents() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/events/saved'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => TeamEvent.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> upsertGameStat({
    required int eventId,
    required int userId,
    required int goals,
    required int assists,
    required int minutesPlayed,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/events/$eventId/stats'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'user_id': userId,
              'goals': goals,
              'assists': assists,
              'minutes_played': minutesPlayed,
            }),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------------- SONDAGENS ----------------

  Future<List<TeamPoll>> getPolls(int teamId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/polls?teamId=$teamId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => TeamPoll.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> createPoll({required int teamId, required String question, required List<String> options}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/polls'),
            headers: await _authHeaders(),
            body: jsonEncode({'team_id': teamId, 'question': question, 'options': options}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Edita uma sondagem existente (apenas treinador). A pergunta pode ser
  /// alterada a qualquer momento; as opções só se ainda não houver votos
  /// — o servidor rejeita com erro nesse caso.
  Future<String?> updatePoll(int pollId, {String? question, List<String>? options}) async {
    try {
      final body = <String, dynamic>{};
      if (question != null) body['question'] = question;
      if (options != null) body['options'] = options;

      final res = await http
          .patch(Uri.parse('$baseUrl/polls/$pollId'), headers: await _authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return null;
      try {
        final data = jsonDecode(res.body);
        return data['error'] ?? 'Não foi possível editar a sondagem.';
      } catch (_) {
        return 'Não foi possível editar a sondagem.';
      }
    } catch (_) {
      return 'Sem ligação ao servidor.';
    }
  }

  /// Elimina uma sondagem existente (apenas treinador).
  Future<bool> deletePoll(int pollId) async {
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/polls/$pollId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<TeamPoll?> votePoll(int pollId, int optionId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/polls/$pollId/vote'),
            headers: await _authHeaders(),
            body: jsonEncode({'option_id': optionId}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return TeamPoll.fromJson(jsonDecode(res.body));
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Atualiza a foto de perfil do próprio utilizador. `avatarUrl` deve vir
  /// de [uploadMedia]. Devolve `true` em sucesso.
  Future<bool> updateAvatar(String avatarUrl) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/users/me/avatar'),
            headers: await _authHeaders(),
            body: jsonEncode({'avatar_url': avatarUrl}),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Atualiza nome, posição em campo e número de camisola do próprio
  /// utilizador. Qualquer parâmetro omitido mantém o valor atual.
  /// Devolve os dados atualizados em sucesso, ou `null` em falha — a
  /// mensagem de erro específica (se houver) vem em `error`.
  Future<(Map<String, dynamic>? data, String? error)> updateProfile({
    String? name,
    String? position,
    int? jerseyNumber,
    bool clearPosition = false,
    bool clearJerseyNumber = false,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/users/me/profile'),
            headers: await _authHeaders(),
            body: jsonEncode({
              if (name != null) 'name': name,
              if (position != null || clearPosition) 'position': clearPosition ? null : position,
              if (jerseyNumber != null || clearJerseyNumber) 'jersey_number': clearJerseyNumber ? null : jerseyNumber,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return (jsonDecode(res.body) as Map<String, dynamic>, null);
      try {
        final err = jsonDecode(res.body);
        return (null, err['error'] as String?);
      } catch (_) {
        return (null, 'Não foi possível guardar.');
      }
    } catch (_) {
      return (null, 'Verifica a ligação.');
    }
  }

  /// Muda a password do próprio utilizador. Devolve `null` em sucesso, ou
  /// uma mensagem de erro (ex.: "Password atual incorreta").
  Future<String?> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/users/me/password'),
            headers: await _authHeaders(),
            body: jsonEncode({'current_password': currentPassword, 'new_password': newPassword}),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return null;
      try {
        final err = jsonDecode(res.body);
        return err['error'] as String? ?? 'Não foi possível mudar a password.';
      } catch (_) {
        return 'Não foi possível mudar a password.';
      }
    } catch (_) {
      return 'Verifica a ligação.';
    }
  }

  // ---------------- CHAT (histórico — mensagens novas chegam via ChatService/Socket.io) ----------------

  Future<List<ChatMessageModel>> getChatHistory(int teamId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/chat/conversations?teamId=$teamId'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => ChatMessageModel.fromJson(e)).toList();
      }
      throw Exception('Falha ao obter histórico de chat');
    } catch (_) {
      return []; // sem backend disponível — chat arranca vazio, mas continua utilizável em tempo real se ligar depois
    }
  }

  // ---------------- MOCKS ----------------

  List<TeamEvent> _mockEvents(int teamId) => [
        TeamEvent(
          id: 1,
          teamId: teamId,
          title: 'Treino Táctico',
          description: 'Treino de finalização',
          startTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
          endTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
          location: 'Campo A',
          type: 'training',
        ),
        TeamEvent(
          id: 2,
          teamId: teamId,
          title: 'Jogo vs Rivais FC',
          description: 'Jornada 3',
          startTime: DateTime.now().add(const Duration(days: 5)),
          endTime: DateTime.now().add(const Duration(days: 5, hours: 1, minutes: 30)),
          location: 'Estádio Municipal',
          type: 'match',
        ),
      ];

  List<FeedPost> _mockFeed(int teamId) => [
        FeedPost(
          id: 1,
          teamId: teamId,
          authorId: 1,
          content: 'Bem-vindos à nova época! Treinos às terças e quintas.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        FeedPost(
          id: 2,
          teamId: teamId,
          authorId: 1,
          content: 'Parabéns pela vitória de sábado!',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

  // ---------------- ADMIN ----------------

  Future<AdminTeamProfile> getAdminTeam() async {
    final res = await http
        .get(Uri.parse('$baseUrl/admin/team'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return AdminTeamProfile.fromJson(jsonDecode(res.body));
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Não foi possível obter a ficha da equipa.');
  }

  Future<bool> updateAdminTeam({
    String? name,
    String? description,
    DateTime? foundedAt,
    String? ageGroup,
    String? modality,
    String? homeVenue,
    DateTime? seasonStartedAt,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (foundedAt != null) body['founded_at'] = foundedAt.toIso8601String();
    if (ageGroup != null) body['age_group'] = ageGroup;
    if (modality != null) body['modality'] = modality;
    if (homeVenue != null) body['home_venue'] = homeVenue;
    if (seasonStartedAt != null) body['season_started_at'] = seasonStartedAt.toIso8601String();

    final res = await http
        .patch(Uri.parse('$baseUrl/admin/team'), headers: await _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 8));
    return res.statusCode == 200;
  }

  Future<CoachProfile?> updateCoachProfile({
    int? coachId,
    String? coachPhone,
    String? coachCertification,
    String? coachNotes,
  }) async {
    final body = <String, dynamic>{};
    if (coachId != null) body['coach_id'] = coachId;
    if (coachPhone != null) body['coach_phone'] = coachPhone;
    if (coachCertification != null) body['coach_certification'] = coachCertification;
    if (coachNotes != null) body['coach_notes'] = coachNotes;

    final res = await http
        .patch(Uri.parse('$baseUrl/admin/coach'), headers: await _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return CoachProfile.fromJson(data['coach']);
    }
    return null;
  }

  Future<List<CoachHistoryEntry>> getCoachHistory() async {
    final res = await http
        .get(Uri.parse('$baseUrl/admin/coach-history'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => CoachHistoryEntry.fromJson(e)).toList();
    }
    throw Exception('Não foi possível obter o histórico de treinadores.');
  }

  /// Troca o treinador da equipa — [newCoachId] tem de ser um membro
  /// (atleta) já existente na equipa. Devolve false em caso de erro, com
  /// [onError] a receber a mensagem do servidor.
  /// Troca o treinador da equipa — cria uma conta nova para o novo
  /// treinador (nome, email, password), tal como um registo normal.
  Future<bool> transferCoach({
    required String name,
    required String email,
    required String password,
    String? notes,
    void Function(String)? onError,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/admin/coach-history/transfer'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            if (notes != null) 'notes': notes,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) return true;
    onError?.call(jsonDecode(res.body)['error'] ?? 'Não foi possível trocar o treinador.');
    return false;
  }

  Future<AdminStats> getAdminStats() async {
    final res = await http
        .get(Uri.parse('$baseUrl/admin/stats'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return AdminStats.fromJson(jsonDecode(res.body));
    }
    throw Exception('Não foi possível obter as estatísticas.');
  }

  Future<CoachActivityStats?> getCoachActivityStats() async {
    final res = await http
        .get(Uri.parse('$baseUrl/admin/coach/stats'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final body = res.body;
      if (body == 'null') return null;
      return CoachActivityStats.fromJson(jsonDecode(body));
    }
    throw Exception('Não foi possível obter as estatísticas do treinador.');
  }

  Future<List<RosterEntry>> getTeamRoster() async {
    final res = await http
        .get(Uri.parse('$baseUrl/admin/roster'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => RosterEntry.fromJson(e)).toList();
    }
    throw Exception('Não foi possível obter o plantel.');
  }

  /// URL do relatório geral em PDF — pronto a abrir com [url_launcher],
  /// tal como o .ics de um evento.
  Future<String> getAdminReportUrl() async {
    final token = await getToken();
    return '$baseUrl/admin/report${token != null ? '?token=$token' : ''}';
  }

  Future<bool> removeAthlete(int userId, {String? reason}) async {
    final res = await http
        .delete(
          Uri.parse('$baseUrl/admin/roster/$userId'),
          headers: await _authHeaders(),
          body: jsonEncode({if (reason != null) 'reason': reason}),
        )
        .timeout(const Duration(seconds: 8));
    return res.statusCode == 200;
  }

  Future<List<MembershipEntry>> getMembershipHistory() async {
    final res = await http
        .get(Uri.parse('$baseUrl/admin/membership-history'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => MembershipEntry.fromJson(e)).toList();
    }
    throw Exception('Não foi possível obter o histórico de membros.');
  }

  Future<List<SeasonPeriod>> getSeasonComparison() async {
    final res = await http
        .get(Uri.parse('$baseUrl/admin/season-comparison'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => SeasonPeriod.fromJson(e)).toList();
    }
    throw Exception('Não foi possível obter a comparação entre épocas.');
  }

  Future<List<AuditLogEntry>> getAuditLog() async {
    final res = await http
        .get(Uri.parse('$baseUrl/admin/audit-log'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => AuditLogEntry.fromJson(e)).toList();
    }
    throw Exception('Não foi possível obter o registo de auditoria.');
  }
}
