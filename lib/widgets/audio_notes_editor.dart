import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_note.dart';
import 'audio_note_tile.dart';

/// Редактор голосовых заметок: запись, прослушивание, удаление.
class AudioNotesEditor extends StatefulWidget {
  final List<AudioNote> notes;
  final ValueChanged<List<AudioNote>> onChanged;
  final String annotationId;
  final bool enabled;

  const AudioNotesEditor({
    super.key,
    required this.notes,
    required this.onChanged,
    this.annotationId = '',
    this.enabled = true,
  });

  @override
  State<AudioNotesEditor> createState() => _AudioNotesEditorState();
}

class _AudioNotesEditorState extends State<AudioNotesEditor> {
  final _recorder = AudioRecorder();
  final _stopwatch = Stopwatch();
  late List<AudioNote> _notes;
  bool _isRecording = false;
  Timer? _ticker;
  static const Duration _maxDuration = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _notes = List.of(widget.notes);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_isRecording) {
      _recorder.cancel();
    }
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_isRecording) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Разрешите доступ к микрофону (Android — настройки приложения; '
                'Windows — Параметры → Конфиденциальность → Микрофон)',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'rec_${const Uuid().v4()}.m4a');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _stopwatch
        ..reset()
        ..start();
      if (!mounted) return;
      setState(() => _isRecording = true);
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() {});
        if (_stopwatch.elapsed >= _maxDuration) _stop();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось начать запись: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stop() async {
    if (!_isRecording) return;
    _ticker?.cancel();
    _ticker = null;
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path == null || durationMs < 300) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }
    final note = AudioNote(
      id: const Uuid().v4(),
      annotationId: widget.annotationId,
      localFilePath: path,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );
    setState(() => _notes.add(note));
    widget.onChanged(List.of(_notes));
  }

  void _delete(AudioNote note) {
    setState(() => _notes.removeWhere((n) => n.id == note.id));
    widget.onChanged(List.of(_notes));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Голосовые заметки',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (_isRecording) ...[
              Text(
                formatAudioDuration(_stopwatch.elapsedMilliseconds),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon:
                    const Icon(Icons.stop_circle, color: Colors.red, size: 32),
                tooltip: 'Остановить запись',
                onPressed: _stop,
              ),
            ] else if (widget.enabled)
              IconButton(
                icon: const Icon(Icons.mic, color: Colors.blue, size: 32),
                tooltip: 'Записать заметку',
                onPressed: _start,
              ),
          ],
        ),
        if (_notes.isEmpty && !_isRecording)
          Text(
            widget.enabled
                ? 'Нет заметок — нажмите микрофон'
                : 'Нет голосовых заметок',
            style: TextStyle(color: Colors.grey[600]),
          ),
        for (final note in _notes)
          AudioNoteTile(
            key: ValueKey(note.id),
            note: note,
            canDelete: widget.enabled,
            onDelete: () => _delete(note),
          ),
      ],
    );
  }
}
