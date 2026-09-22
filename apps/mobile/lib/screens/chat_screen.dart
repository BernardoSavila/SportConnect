import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../models/chat_message.dart';
import '../services/app_state.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_message_bubble.dart';
import '../widgets/empty_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  final _audioRecorder = AudioRecorder();

  ChatService? _chatService;
  StreamSubscription<ChatMessageModel>? _messageSub;
  bool _loading = true;
  bool _uploading = false;
  bool _recording = false;
  int _teamId = 1;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final app = context.read<AppState>();
    _teamId = app.currentUser?.teamId ?? 1;
    _myUserId = app.currentUser?.id;
    // Não marcamos aqui "chat ativo" — com o IndexedStack, este ecrã é
    // criado uma vez quando a app abre, não só quando tocas na aba. Quem
    // sabe mesmo qual é a aba visível agora é o home_shell, no toque.

    final history = await app.api.getChatHistory(_teamId);
    if (!mounted) return;
    setState(() {
      _messages.addAll(history);
      _loading = false;
    });
    _scrollToBottom();

    // Usa a ligação Socket.io partilhada (criada em HomeShell) em vez de
    // abrir uma segunda ligação — assim o badge de não lidas e o chat em
    // si falam sempre com o mesmo socket.
    await app.ensureChatConnected(_teamId);
    _chatService = app.chatService;
    _messageSub = _chatService?.messages.listen((msg) {
      if (!mounted) return;
      setState(() => _messages.add(msg));
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _chatService?.sendMessage(_teamId, content: text, type: 'text');
    _messageController.clear();
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (img == null) return;

    setState(() => _uploading = true);
    final app = context.read<AppState>();
    final bytes = await img.readAsBytes();
    final url = await app.api.uploadMedia(bytes: bytes, filename: img.name);
    if (!mounted) return;
    setState(() => _uploading = false);

    if (url != null) {
      _chatService?.sendMessage(_teamId, mediaUrl: url, type: 'image');
    } else {
      _showError('Não foi possível enviar a imagem.');
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _audioRecorder.stop();
      setState(() => _recording = false);
      if (path != null) {
        await _sendAudio(path);
      }
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _showError('Sem permissão de microfone. Ativa-a nas definições do telemóvel.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() => _recording = true);
  }

  Future<void> _sendAudio(String path) async {
    setState(() => _uploading = true);
    final app = context.read<AppState>();
    final bytes = await File(path).readAsBytes();
    final url = await app.api.uploadMedia(bytes: bytes, filename: 'voice.m4a');
    if (!mounted) return;
    setState(() => _uploading = false);

    if (url != null) {
      _chatService?.sendMessage(_teamId, mediaUrl: url, type: 'audio');
    } else {
      _showError('Não foi possível enviar o áudio.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.coral, content: Text(message)),
    );
  }

  @override
  void dispose() {
    // Não fazemos dispose ao _chatService aqui — é uma ligação partilhada,
    // gerida pelo AppState (mantém-se ligada noutros separadores para o
    // badge de não lidas continuar a funcionar). O HomeShell já trata de
    // marcar o separador como inativo ao mudar de aba. Cancelamos apenas a
    // NOSSA subscrição a esta stream partilhada, para não se acumularem
    // subscrições fantasma cada vez que se volta a este ecrã.
    _messageSub?.cancel();
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _chatService?.isConnected ?? false;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Chat da equipa',
            subtitle: connected ? 'Em tempo real 🟢' : 'A ligar...',
            height: 140,
            watermarkIcon: Icons.forum_rounded,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.forum_outlined,
                        title: 'Ainda não há mensagens',
                        message: 'Sê o primeiro a dizer olá à equipa 👋',
                        color: AppColors.cyan,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _MessageBubble(
                          message: _messages[i],
                          mine: _messages[i].senderId == _myUserId,
                        ),
                      ),
          ),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(height: 3, child: LinearProgressIndicator()),
            ),
          if (_recording)
            Container(
              width: double.infinity,
              color: AppColors.coral.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.fiber_manual_record, color: AppColors.coral, size: 14),
                  SizedBox(width: 6),
                  Text('A gravar... toca no microfone para parar e enviar',
                      style: TextStyle(color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _uploading ? null : _sendImage,
                  icon: const Icon(Icons.image_outlined, color: AppColors.primaryBlue),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Escrever mensagem...'),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _uploading ? null : _toggleRecording,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _recording ? AppColors.coral : Colors.transparent,
                    ),
                    child: Icon(Icons.mic, color: _recording ? Colors.white : AppColors.textMuted),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.cardAccentGradient),
                  child: IconButton(
                    onPressed: _sendText,
                    icon: const Icon(Icons.send_rounded, color: AppColors.background),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final ChatMessageModel message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );

    Widget content;
    if (message.type == 'image' && message.mediaUrl != null) {
      content = ClipRRect(
        borderRadius: radius,
        child: Image.network(
          message.mediaUrl!,
          width: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 220,
            height: 140,
            color: AppColors.background,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
          ),
        ),
      );
    } else if (message.type == 'audio' && message.mediaUrl != null) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: mine ? AppColors.cardAccentGradient : null,
          color: mine ? null : AppColors.surface,
          borderRadius: radius,
          boxShadow: mine ? [] : AppShadows.soft,
        ),
        child: AudioMessageBubble(url: message.mediaUrl!, light: mine),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          gradient: mine ? AppColors.cardAccentGradient : null,
          color: mine ? null : AppColors.surface,
          borderRadius: radius,
          boxShadow: mine ? [] : AppShadows.soft,
        ),
        child: Text(message.content ?? '', style: TextStyle(color: mine ? AppColors.background : AppColors.textDark)),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(margin: const EdgeInsets.symmetric(vertical: 4), child: content),
    );
  }
}
