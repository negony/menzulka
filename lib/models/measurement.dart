import 'dart:ui';

/// Форматирует длину (значение в метрах) для отображения в [units] (m/cm/mm).
String formatLength(double meters, String units) {
  switch (units) {
    case 'mm':
      return '${(meters * 1000).toStringAsFixed(1)} мм';
    case 'cm':
      return '${(meters * 100).toStringAsFixed(2)} см';
    default:
      return '${meters.toStringAsFixed(3)} м';
  }
}

/// Форматирует площадь (значение в м²) для отображения в [units] (m/cm/mm).
String formatArea(double squareMeters, String units) {
  switch (units) {
    case 'mm':
      return '${(squareMeters * 1000000).toStringAsFixed(1)} мм²';
    case 'cm':
      return '${(squareMeters * 10000).toStringAsFixed(2)} см²';
    default:
      return '${squareMeters.toStringAsFixed(2)} м²';
  }
}

abstract class Measurement {
  final String id;
  final String drawingId;
  final DateTime createdAt;
  Measurement(
      {required this.id, required this.drawingId, required this.createdAt});
  double getValueInDrawingUnits();
  double getValueInMeters(String units);
  String formatResult(String units);
}

class DistanceMeasurement extends Measurement {
  final Offset point1;
  final Offset point2;
  final String? annotation1Id;
  final String? annotation2Id;
  DistanceMeasurement({
    required super.id,
    required super.drawingId,
    required super.createdAt,
    required this.point1,
    required this.point2,
    this.annotation1Id,
    this.annotation2Id,
  });
  @override
  double getValueInDrawingUnits() => (point2 - point1).distance;
  @override
  double getValueInMeters(String units) =>
      _convert(getValueInDrawingUnits(), units);
  @override
  String formatResult(String units) =>
      formatLength(getValueInDrawingUnits(), units);
  double _convert(double value, String units) {
    switch (units) {
      case 'mm':
        return value / 1000;
      case 'cm':
        return value / 100;
      case 'm':
        return value;
      default:
        return value;
    }
  }
}

class PolygonMeasurement extends Measurement {
  final List<Offset> points;
  final List<String?> annotationIds;

  /// Контур замкнут: замыкающая сторона входит в периметр, выводится площадь.
  final bool closed;

  PolygonMeasurement({
    required super.id,
    required super.drawingId,
    required super.createdAt,
    required this.points,
    this.annotationIds = const [],
    this.closed = true,
  });

  @override
  double getValueInDrawingUnits() => getPerimeter();

  @override
  double getValueInMeters(String units) => _convert(getPerimeter(), units);

  @override
  String formatResult(String units) {
    if (!closed) {
      return 'Длина: ${formatLength(getPathLength(), units)}';
    }
    return 'Периметр: ${formatLength(getPerimeter(), units)}\n'
        'Площадь: ${formatArea(getArea(), units)}';
  }

  /// Сумма длин последовательных сторон (без замыкающей).
  double getPathLength() {
    if (points.length < 2) return 0;
    double p = 0;
    for (int i = 0; i < points.length - 1; i++) {
      p += (points[i + 1] - points[i]).distance;
    }
    return p;
  }

  /// Периметр: для замкнутого контура — стороны + замыкающая,
  /// для открытого — только сумма сторон.
  double getPerimeter() {
    if (points.length < 2) return 0;
    var p = getPathLength();
    if (closed && points.length >= 3) {
      p += (points.first - points.last).distance;
    }
    return p;
  }

  double getPerimeterInMeters(String units) => _convert(getPerimeter(), units);

  double getArea() {
    if (points.length < 3) return 0;
    double a = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      a += points[i].dx * points[j].dy;
      a -= points[j].dx * points[i].dy;
    }
    return a.abs() / 2;
  }

  double getAreaInMeters(String units) => _convertArea(getArea(), units);

  double _convert(double v, String u) {
    switch (u) {
      case 'mm':
        return v / 1000;
      case 'cm':
        return v / 100;
      case 'm':
        return v;
      default:
        return v;
    }
  }

  double _convertArea(double a, String u) {
    switch (u) {
      case 'mm':
        return a / 1000000;
      case 'cm':
        return a / 10000;
      case 'm':
        return a;
      default:
        return a;
    }
  }
}
