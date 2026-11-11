import 'dart:math' as math;
import 'dart:ui';

/// Пересечение прямой (точка [a], единичное направление [dir]) с прямоугольником
/// [rect] — true-бесконечная линия на экране при любом зуме.
({Offset start, Offset end})? clipLineToRect(Offset a, Offset dir, Rect rect) {
  var tMin = -double.infinity;
  var tMax = double.infinity;
  if (dir.dx.abs() < 1e-12) {
    if (a.dx < rect.left || a.dx > rect.right) return null;
  } else {
    final t1 = (rect.left - a.dx) / dir.dx;
    final t2 = (rect.right - a.dx) / dir.dx;
    tMin = math.max(tMin, math.min(t1, t2));
    tMax = math.min(tMax, math.max(t1, t2));
  }
  if (dir.dy.abs() < 1e-12) {
    if (a.dy < rect.top || a.dy > rect.bottom) return null;
  } else {
    final t1 = (rect.top - a.dy) / dir.dy;
    final t2 = (rect.bottom - a.dy) / dir.dy;
    tMin = math.max(tMin, math.min(t1, t2));
    tMax = math.min(tMax, math.max(t1, t2));
  }
  if (tMin > tMax) return null;
  return (start: a + dir * tMin, end: a + dir * tMax);
}

/// Коэффициент размера дуг облака (пользователь просил +30%).
const double kCloudArcScale = 1.3;

/// Четыре угла прямоугольника по двум точкам (против часовой стрелки).
List<Offset> rectangleCorners(Offset a, Offset b) {
  final left = math.min(a.dx, b.dx);
  final right = math.max(a.dx, b.dx);
  final bottom = math.min(a.dy, b.dy);
  final top = math.max(a.dy, b.dy);
  return [
    Offset(left, bottom),
    Offset(right, bottom),
    Offset(right, top),
    Offset(left, top),
  ];
}

/// Нарисованное облако: замкнутый контур из полукруглых зубцов.
///
/// Хорды подбираются максимально близкими по длине (перебор вариантов
/// `L / n` по всем сторонам), поэтому радиусы всех дуг практически равны —
/// облако выглядит гармонично. Вершины идут против часовой стрелки,
/// `bulge = arcScale` (1.3 — дуги на 30% «глубже», как просил пользователь).
/// Полилиния замыкается на первую вершину.
({List<Offset> vertices, List<double> bulges}) buildCloud(
  List<Offset> corners, {
  double arcScale = kCloudArcScale,
}) {
  final left = corners[0].dx;
  final bottom = corners[0].dy;
  final right = corners[2].dx;
  final top = corners[2].dy;
  final w = right - left;
  final h = top - bottom;
  if (w <= 1e-9 || h <= 1e-9) {
    return (
      vertices: List<Offset>.of(corners),
      bulges: List<double>.filled(corners.length, 0.0),
    );
  }

  final sides = [w, h, w, h];
  // Кандидаты длины хорды: L / n для всех сторон и разумных n.
  final candidates = <double>{};
  for (final l in sides) {
    for (var n = 1; n <= 64; n++) {
      candidates.add(l / n);
    }
  }

  var bestCounts = <int>[];
  var bestDeviation = double.infinity;
  for (final c in candidates) {
    if (c <= 1e-9) continue;
    final counts = <int>[];
    var total = 0;
    for (final l in sides) {
      final n = math.max(1, (l / c).round());
      counts.add(n);
      total += n;
    }
    if (total < 8 || total > 80) continue;
    final chords = [for (var i = 0; i < 4; i++) sides[i] / counts[i]];
    final mean = chords.reduce((a, b) => a + b) / chords.length;
    if (mean <= 0) continue;
    var deviation = 0.0;
    for (final chord in chords) {
      final d = (chord - mean).abs() / mean;
      if (d > deviation) deviation = d;
    }
    if (deviation < bestDeviation) {
      bestDeviation = deviation;
      bestCounts = counts;
    }
  }
  if (bestCounts.isEmpty) bestCounts = [2, 2, 2, 2];

  final vertices = <Offset>[];
  final bulges = <double>[];
  for (var i = 0; i < 4; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % 4];
    final count = bestCounts[i];
    for (var k = 0; k < count; k++) {
      final t = k / count;
      vertices.add(Offset(
        a.dx + (b.dx - a.dx) * t,
        a.dy + (b.dy - a.dy) * t,
      ));
      // CCW-обход → +1 даёт дугу снаружи прямоугольника.
      bulges.add(arcScale);
    }
  }
  return (vertices: vertices, bulges: bulges);
}

/// Геометрия линейного размера: размерная линия параллельна p1p2 и
/// проходит через p3; выносные линии — из p1/p2; текст — вдоль линии.
class DimensionLayout {
  final Offset dimStart;
  final Offset dimEnd;
  final Offset ext1End;
  final Offset ext2End;
  final Offset textPosition;

  /// Угол текста в градусах (DXF, CCW, y вверх), нормализован к (-90, 90].
  final double textAngleDeg;

  final double length;

  const DimensionLayout({
    required this.dimStart,
    required this.dimEnd,
    required this.ext1End,
    required this.ext2End,
    required this.textPosition,
    required this.textAngleDeg,
    required this.length,
  });
}

/// Строит геометрию размера между [p1] и [p2] с линией через [p3].
DimensionLayout? layoutDimension(
  Offset p1,
  Offset p2,
  Offset p3, {
  double textHeight = 2.5,
}) {
  final dx = p2.dx - p1.dx;
  final dy = p2.dy - p1.dy;
  final length = math.sqrt(dx * dx + dy * dy);
  if (length < 1e-9) return null;
  final ux = dx / length;
  final uy = dy / length;
  final nx = -uy;
  final ny = ux;

  // Смещение размерной линии от измеряемого отрезка (по нормали).
  final offset = (p3.dx - p1.dx) * nx + (p3.dy - p1.dy) * ny;
  final dimStart = Offset(p1.dx + nx * offset, p1.dy + ny * offset);
  final dimEnd = Offset(p2.dx + nx * offset, p2.dy + ny * offset);

  // Текст — с внешней стороны размерной линии, с запасом.
  final sign = offset < 0 ? -1.0 : 1.0;
  final textPosition = Offset(
    (dimStart.dx + dimEnd.dx) / 2 + nx * sign * textHeight * 1.6,
    (dimStart.dy + dimEnd.dy) / 2 + ny * sign * textHeight * 1.6,
  );

  // Выносные линии немного выходят за размерную.
  final overshoot = textHeight * 0.35;
  final ext1End = Offset(
      dimStart.dx + nx * sign * overshoot, dimStart.dy + ny * sign * overshoot);
  final ext2End = Offset(
      dimEnd.dx + nx * sign * overshoot, dimEnd.dy + ny * sign * overshoot);

  // Угол текста вдоль линии, но не «вверх ногами».
  var angle = math.atan2(uy, ux) * 180 / math.pi;
  while (angle > 90) {
    angle -= 180;
  }
  while (angle <= -90) {
    angle += 180;
  }

  return DimensionLayout(
    dimStart: dimStart,
    dimEnd: dimEnd,
    ext1End: ext1End,
    ext2End: ext2End,
    textPosition: textPosition,
    textAngleDeg: angle,
    length: length,
  );
}

/// Облако по произвольному замкнутому контуру (например, нарисованному
/// пальцем). Контур приводится к CCW, делится на равные хорды (перебор
/// `L / n` минимизирует разброс), каждая хорда — полукруглый зубец наружу.
({List<Offset> vertices, List<double> bulges}) buildCloudFromPolygon(
  List<Offset> polygon, {
  double arcScale = kCloudArcScale,
}) {
  final points = <Offset>[];
  for (final p in polygon) {
    if (points.isEmpty || (p - points.last).distance > 1e-9) {
      points.add(p);
    }
  }
  while (points.length >= 2 && (points.first - points.last).distance <= 1e-9) {
    points.removeLast();
  }
  if (points.length < 3) {
    return (
      vertices: List<Offset>.of(points),
      bulges: List<double>.filled(points.length, 0.0),
    );
  }

  // Ориентация: против часовой стрелки (положительная площадь).
  var area = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    area += a.dx * b.dy - b.dx * a.dy;
  }
  final poly = area < 0 ? points.reversed.toList() : points;

  final edges = <double>[];
  for (var i = 0; i < poly.length; i++) {
    edges.add((poly[(i + 1) % poly.length] - poly[i]).distance);
  }
  final candidates = <double>{};
  for (final l in edges) {
    for (var n = 1; n <= 96; n++) {
      candidates.add(l / n);
    }
  }

  var bestCounts = <int>[];
  var bestDeviation = double.infinity;
  for (final c in candidates) {
    if (c <= 1e-9) continue;
    final counts = <int>[];
    var total = 0;
    for (final l in edges) {
      final n = math.max(1, (l / c).round());
      counts.add(n);
      total += n;
    }
    if (total < 8 || total > 160) continue;
    final chords = [
      for (var i = 0; i < edges.length; i++) edges[i] / counts[i]
    ];
    final mean = chords.reduce((a, b) => a + b) / chords.length;
    if (mean <= 0) continue;
    var deviation = 0.0;
    for (final chord in chords) {
      final d = (chord - mean).abs() / mean;
      if (d > deviation) deviation = d;
    }
    if (deviation < bestDeviation) {
      bestDeviation = deviation;
      bestCounts = counts;
    }
  }
  if (bestCounts.isEmpty) bestCounts = [for (final _ in edges) 1];

  final vertices = <Offset>[];
  final bulges = <double>[];
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    final count = bestCounts[i];
    for (var k = 0; k < count; k++) {
      final t = k / count;
      vertices.add(Offset(
        a.dx + (b.dx - a.dx) * t,
        a.dy + (b.dy - a.dy) * t,
      ));
      bulges.add(arcScale);
    }
  }
  return (vertices: vertices, bulges: bulges);
}

/// Полка размера по умолчанию: середина отрезка + нормаль «вверх» (в мире)
/// на расстоянии [offsetWorld].
Offset defaultDimensionShelf(Offset p1, Offset p2, double offsetWorld) {
  final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
  final d = p2 - p1;
  final len = d.distance;
  if (len < 1e-9) return mid + Offset(0, offsetWorld);
  var n = Offset(-d.dy / len, d.dx / len);
  // Вверх по экрану = +y в мире; для вертикального отрезка — вправо.
  if (n.dy < -1e-9) n = -n;
  if (n.dy.abs() <= 1e-9 && n.dx < 0) n = -n;
  return mid + n * offsetWorld;
}
