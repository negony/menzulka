/// Голосовая заметка, привязанная к точке (аннотации).
class AudioNote {
  final String id;
  final String annotationId;
  final String localFilePath;
  final int durationMs;
  final DateTime createdAt;

  AudioNote({
    required this.id,
    required this.annotationId,
    required this.localFilePath,
    required this.durationMs,
    required this.createdAt,
  });

  /// JSON для манифеста `.abris` (путь к файлу внутри архива добавляет упаковщик).
  Map<String, dynamic> toJson() => {
        'id': id,
        'durationMs': durationMs,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Восстанавливает заметку из манифеста; [localFilePath] — уже локальный путь.
  static AudioNote? fromJson(
    Map<String, dynamic> json, {
    required String localFilePath,
    String annotationId = '',
  }) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty || localFilePath.isEmpty) return null;
    return AudioNote(
      id: id,
      annotationId: annotationId,
      localFilePath: localFilePath,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Длительность в формате мм:сс.
String formatAudioDuration(int milliseconds) {
  final totalSeconds = (milliseconds / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
