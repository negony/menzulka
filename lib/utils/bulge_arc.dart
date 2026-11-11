import 'dart:math' as math;
import 'dart:ui';

/// Точки аппроксимации дуги по bulge-сегменту.
///
/// Возвращает точки от p1 (исключая) до p2 (включая): путь уже содержит
/// начальную точку. Используется при отрисовке полилиний (`LayerCache`) и
/// нарисованных облаков.
List<Offset> bulgeArcPoints(
  double x1,
  double y1,
  double x2,
  double y2,
  double bulge, {
  int segments = 24,
}) {
  final p2 = Offset(x2, y2);
  final dx = x2 - x1, dy = y2 - y1;
  final chord = math.sqrt(dx * dx + dy * dy);
  if (chord < 1e-9) return [p2];
  final theta = 4 * math.atan(bulge);
  if (theta.abs() < 1e-9) return [p2];
  final r = chord / (2 * math.sin(theta.abs() / 2));
  final mid = Offset((x1 + x2) / 2, (y1 + y2) / 2);
  final ux = dx / chord, uy = dy / chord;
  final nx = -uy, ny = ux;
  final h = math.sqrt(math.max(0.0, r * r - (chord * chord) / 4));
  final c1 = Offset(mid.dx + nx * h, mid.dy + ny * h);
  final c2 = Offset(mid.dx - nx * h, mid.dy - ny * h);
  final p1 = Offset(x1, y1);
  final s1 = _signedSweep(c1, p1, p2, theta);
  final s2 = _signedSweep(c2, p1, p2, theta);
  final first = (s1 - theta).abs() <= (s2 - theta).abs();
  final center = first ? c1 : c2;
  final sweep = first ? s1 : s2;
  final a1 = math.atan2(p1.dy - center.dy, p1.dx - center.dx);
  final pts = <Offset>[];
  for (var i = 1; i <= segments; i++) {
    final a = a1 + sweep * i / segments;
    pts.add(Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a)));
  }
  return pts;
}

double _signedSweep(Offset c, Offset p1, Offset p2, double theta) {
  final a1 = math.atan2(p1.dy - c.dy, p1.dx - c.dx);
  final a2 = math.atan2(p2.dy - c.dy, p2.dx - c.dx);
  var d = a2 - a1;
  while (d <= -math.pi) {
    d += 2 * math.pi;
  }
  while (d > math.pi) {
    d -= 2 * math.pi;
  }
  if (theta > 0 && d < 0) d += 2 * math.pi;
  if (theta < 0 && d > 0) d -= 2 * math.pi;
  return d;
}
