import 'dart:math' as math;

import '../models/dxf_models.dart';

/// Аффинное преобразование 2D (как в DXF-блоках): [a b c; d e f].
class DxfAffine {
  final double a, b, c, d, e, f;

  const DxfAffine(this.a, this.b, this.c, this.d, this.e, this.f);

  static const identity = DxfAffine(1, 0, 0, 0, 1, 0);

  ({double x, double y}) apply(double x, double y) =>
      (x: a * x + b * y + c, y: d * x + e * y + f);

  DxfAffine mul(DxfAffine o) => DxfAffine(
        a * o.a + b * o.d,
        a * o.b + b * o.e,
        a * o.c + b * o.f + c,
        d * o.a + e * o.d,
        d * o.b + e * o.e,
        d * o.c + e * o.f + f,
      );

  double get determinant => a * e - b * d;

  double get uniformScale => math.sqrt(determinant.abs());

  /// Угол поворота в градусах.
  double get rotationDeg => math.atan2(d, a) * 180 / math.pi;

  bool get isIdentity =>
      a == 1 && b == 0 && c == 0 && d == 0 && e == 1 && f == 0;

  /// Похоже на подобие (поворот + равномерный масштаб + сдвиг), без отражения.
  bool get isSimilarity {
    if (determinant <= 0) return false;
    final len1 = a * a + d * d;
    final len2 = b * b + e * e;
    final dot = a * b + d * e;
    final scale2 = math.max(len1, 1e-12);
    return (len1 - len2).abs() <= scale2 * 1e-6 && dot.abs() <= scale2 * 1e-6;
  }
}

/// Преобразование блока: base → поворот → масштаб → точка вставки.
DxfAffine insertAffine(DxfInsert ins, DxfBlock block) {
  final rad = ins.rotation * math.pi / 180;
  final cosr = math.cos(rad), sinr = math.sin(rad);
  final sx = ins.scaleX, sy = ins.scaleY;
  return DxfAffine(
    cosr * sx,
    -sinr * sy,
    ins.x - cosr * sx * block.baseX + sinr * sy * block.baseY,
    sinr * sx,
    cosr * sy,
    ins.y - sinr * sx * block.baseX - cosr * sy * block.baseY,
  );
}
