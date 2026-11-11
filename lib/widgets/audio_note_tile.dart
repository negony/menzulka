import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/audio_note.dart';

/// Плитка одной голосовой заметки: play/pause, прогресс, длительность, удаление.
class AudioNoteTile extends StatefulWidget {
  final AudioNote note;
  final bool canDelete;
  final VoidCallback? onDelete;

  const AudioNoteTile({
    super.key,
    required this.note,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  State<AudioNoteTile> createState() => _AudioNoteTileState();
}

class _AudioNoteTileState extends State<AudioNoteTile> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.note.durationMs);
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
    _posSub = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _durSub = _player.onDurationChanged.listen((duration) {
      if (!mounted || duration <= Duration.zero) return;
      setState(() => _duration = duration);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!File(widget.note.localFilePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл заметки не найден')),
      );
      return;
    }
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(widget.note.localFilePath));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds > 0
        ? _duration
        : Duration(milliseconds: widget.note.durationMs);
    final progress = total.inMilliseconds > 0
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        icon: Icon(
          _playing ? Icons.pause_circle : Icons.play_circle,
          size: 36,
          color: Colors.blue,
        ),
        tooltip: _playing ? 'Пауза' : 'Прослушать',
        onPressed: _toggle,
      ),
      title: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(value: progress),
      ),
      subtitle: Text(
        '${formatAudioDuration(_position.inMilliseconds)} / '
        '${formatAudioDuration(total.inMilliseconds)}',
      ),
      trailing: widget.canDelete
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Удалить заметку',
              onPressed: widget.onDelete,
            )
          : null,
    );
  }
}
