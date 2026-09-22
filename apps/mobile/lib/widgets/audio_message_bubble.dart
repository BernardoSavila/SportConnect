import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pequeno leitor de áudio embutido numa bolha de chat — play/pause e
/// barra de progresso simples, para mensagens de voz.
class AudioMessageBubble extends StatefulWidget {
  const AudioMessageBubble({super.key, required this.url, required this.light});

  /// URL do ficheiro de áudio (devolvido por POST /media/upload).
  final String url;

  /// Se `true`, usa cores claras (para bolhas com fundo colorido/gradiente).
  final bool light;

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(widget.url));
      setState(() => _playing = true);
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.light ? AppColors.background : AppColors.primaryBlue;
    final progress = _duration.inMilliseconds == 0 ? 0.0 : _position.inMilliseconds / _duration.inMilliseconds;

    return SizedBox(
      width: 180,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(widget.light ? 0.25 : 0.12)),
              child: Icon(_playing ? Icons.pause : Icons.play_arrow, color: color, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _duration.inMilliseconds == 0 ? 'Áudio' : _format(_duration - _position),
                  style: TextStyle(fontSize: 10, color: color.withOpacity(0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
