import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/chat_message.dart';
import '../models/direct_message.dart';

/// Liga-se ao servidor via Socket.io para chat em tempo real: chat de
/// equipa e mensagens privadas (1-para-1) partilham a mesma ligação.
/// Ver protocolo em `apps/server/src/realtime.ts`.
class ChatService {
  ChatService({required this.baseUrl, required this.token});

  final String baseUrl;
  final String? token;

  io.Socket? _socket;
  final _messagesController = StreamController<ChatMessageModel>.broadcast();
  final _dmController = StreamController<DirectMessageModel>.broadcast();

  Stream<ChatMessageModel> get messages => _messagesController.stream;
  Stream<DirectMessageModel> get directMessages => _dmController.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect(int teamId) {
    if (token == null) return; // modo mock/offline — sem token não há tempo real
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    _socket!.onConnect((_) => _socket!.emit('join', {'teamId': teamId}));
    _socket!.on('message:new', (data) {
      _messagesController.add(ChatMessageModel.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('dm:new', (data) {
      _dmController.add(DirectMessageModel.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  void sendMessage(int teamId, {String? content, String? mediaUrl, String type = 'text'}) {
    _socket?.emit('message:send', {
      'teamId': teamId,
      if (content != null) 'content': content,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      'type': type,
    });
  }

  /// Entra na "sala" da conversa privada com [withUserId] — chamar ao abrir
  /// o ecrã de chat privado, antes de enviar/receber mensagens.
  void joinDirectConversation(int withUserId) {
    _socket?.emit('dm:join', {'withUserId': withUserId});
  }

  void sendDirectMessage(int toUserId, {String? content, String? mediaUrl, String type = 'text'}) {
    _socket?.emit('dm:send', {
      'toUserId': toUserId,
      if (content != null) 'content': content,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      'type': type,
    });
  }

  void dispose() {
    _socket?.dispose();
    _messagesController.close();
    _dmController.close();
  }
}
