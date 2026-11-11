import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/models/history_event.dart';
import 'package:menzulka/models/project_version.dart';
import 'package:menzulka/utils/format_utils.dart';

void main() {
  test('formatHistoryDate — Сегодня/Вчера/дата', () {
    final now = DateTime(2026, 10, 30, 12, 0);
    expect(formatHistoryDate(DateTime(2026, 10, 30, 9), now: now), 'Сегодня');
    expect(formatHistoryDate(DateTime(2026, 10, 29, 23), now: now), 'Вчера');
    expect(
        formatHistoryDate(DateTime(2026, 10, 27, 10), now: now), '27 октября');
    expect(
      formatHistoryDate(DateTime(2025, 12, 31), now: now),
      '31 декабря 2025',
    );
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 Б');
    expect(formatBytes(2048), '2.0 КБ');
    expect(formatBytes(12 * 1024), '12 КБ');
    expect(formatBytes(2 * 1024 * 1024), '2.0 МБ');
  });

  test('formatDateTimeShort', () {
    expect(
      formatDateTimeShort(DateTime(2026, 10, 30, 10, 5)),
      '30.10.2026 10:05',
    );
  });

  test('plural — русские формы', () {
    expect(plural(1, 'точка', 'точки', 'точек'), 'точка');
    expect(plural(3, 'точка', 'точки', 'точек'), 'точки');
    expect(plural(5, 'точка', 'точки', 'точек'), 'точек');
    expect(plural(11, 'точка', 'точки', 'точек'), 'точек');
    expect(plural(21, 'точка', 'точки', 'точек'), 'точка');
  });

  test('HistoryCategory содержит типы', () {
    expect(
      historyCategoryTypes[HistoryCategory.points],
      contains(HistoryEventType.annotationCreated),
    );
    expect(
      historyCategoryTypes[HistoryCategory.system],
      contains(HistoryEventType.versionCreated),
    );
  });

  test('ProjectVersion.contentsLabel', () {
    final version = ProjectVersion(
      id: 'v1',
      drawingId: 'd1',
      label: 'Версия',
      filePath: '/tmp/v.abris',
      sizeBytes: 1000,
      annotationsCount: 6,
      measurementsCount: 2,
      photosCount: 18,
      audioCount: 1,
      createdAt: DateTime(2026, 10, 30),
    );
    expect(
        version.contentsLabel, '6 точек · 18 фото · 1 заметка · 2 измерения');
  });
}
