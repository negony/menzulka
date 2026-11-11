import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/models/audio_note.dart';

void main() {
  test('AudioNote.toJson/fromJson — round-trip', () {
    final note = AudioNote(
      id: 'a1',
      annotationId: 'n1',
      localFilePath: '/tmp/x.m4a',
      durationMs: 65000,
      createdAt: DateTime(2026, 10, 30, 12, 0),
    );

    final json = note.toJson();
    expect(json['id'], 'a1');
    expect(json['durationMs'], 65000);

    final restored = AudioNote.fromJson(
      json,
      localFilePath: '/tmp/x.m4a',
      annotationId: 'n1',
    );
    expect(restored, isNotNull);
    expect(restored!.id, 'a1');
    expect(restored.durationMs, 65000);
    expect(restored.annotationId, 'n1');
    expect(restored.localFilePath, '/tmp/x.m4a');
  });

  test('AudioNote.fromJson — невалидные данные', () {
    expect(AudioNote.fromJson(const {}, localFilePath: '/tmp/x.m4a'), isNull);
    expect(AudioNote.fromJson({'id': 'a1'}, localFilePath: ''), isNull);
  });

  test('formatAudioDuration', () {
    expect(formatAudioDuration(0), '00:00');
    expect(formatAudioDuration(1000), '00:01');
    expect(formatAudioDuration(83000), '01:23');
    expect(formatAudioDuration(600000), '10:00');
  });
}
