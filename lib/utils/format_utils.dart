/// Форматирование размера файла: «512 Б», «12.3 КБ», «1.2 МБ».
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} КБ';
  }
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} МБ';
}

/// Подпись единиц чертежа для интерфейса: 'm' → «м», 'mm' → «мм», 'cm' → «см».
String unitsLabel(String units) {
  switch (units) {
    case 'm':
      return 'м';
    case 'mm':
      return 'мм';
    case 'cm':
      return 'см';
    default:
      return units;
  }
}

/// Координата для отображения: 3 знака после точки, тысячи через пробел.
/// Пример: 2217.5689 → «2 217.569», -12.3 → «-12.300».
String formatCoordinate(double v) {
  final negative = v < -0.0005;
  final s = v.abs().toStringAsFixed(3);
  final dot = s.indexOf('.');
  final intPart = dot < 0 ? s : s.substring(0, dot);
  final frac = dot < 0 ? '' : s.substring(dot + 1);
  final b = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) b.write(' ');
    b.write(intPart[i]);
  }
  if (frac.isNotEmpty) b.write('.$frac');
  return negative ? '-$b' : '$b';
}

const List<String> _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// Заголовок дня для журнала: «Сегодня», «Вчера», «30 октября 2026».
String formatHistoryDate(DateTime date, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  final base = '${d.day} ${_months[d.month - 1]}';
  return d.year == today.year ? base : '$base ${d.year}';
}

/// Время события: «10:15».
String formatHistoryTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

/// Дата-время для подписи версии: «30.10.2026 10:15».
String formatDateTimeShort(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.'
    '${dt.month.toString().padLeft(2, '0')}.'
    '${dt.year} ${formatHistoryTime(dt)}';

/// Русская форма множественного числа: plural(1,'точка','точки','точек').
String plural(int count, String one, String few, String many) {
  final n = count % 100;
  if (n >= 11 && n <= 14) return many;
  switch (count % 10) {
    case 1:
      return one;
    case 2:
    case 3:
    case 4:
      return few;
    default:
      return many;
  }
}
