import 'dart:ui';

/// Инструмент рисования / тип нарисованного объекта.
enum DrawnType {
  point,
  polyline,
  line,
  ray,
  circle,
  rectangle,
  cloud,
  text,
  dimension,
}

extension DrawnTypeLabel on DrawnType {
  String get label {
    switch (this) {
      case DrawnType.point:
        return 'Точка';
      case DrawnType.polyline:
        return 'Полилиния';
      case DrawnType.line:
        return 'Отрезок';
      case DrawnType.ray:
        return 'Прямая';
      case DrawnType.circle:
        return 'Круг';
      case DrawnType.rectangle:
        return 'Прямоугольник';
      case DrawnType.cloud:
        return 'Облако';
      case DrawnType.text:
        return 'Текст';
      case DrawnType.dimension:
        return 'Размер';
    }
  }
}

/// Цвет по умолчанию для нарисованных объектов (светло-синий).
const int kDrawnDefaultColor = 0xFF64B5F6;

/// Слой по умолчанию для нарисованных объектов.
const String kDefaultDrawnLayer = 'Слой 1';

/// Толщина по умолчанию (экранные пиксели).
const double kDrawnDefaultStrokePx = 1.6;

/// 5 вариантов толщины линии (экранные пиксели, постоянные при любом зуме).
const List<double> kDrawnStrokeOptions = [1.2, 2.0, 3.0, 4.5, 6.0];

/// Палитра цветов для рисования (8 цветов, различимых на тёмном холсте).
const List<int> kDrawnColorOptions = [
  0xFFFFFFFF, // белый
  0xFFFFEB3B, // жёлтый
  0xFFFF9800, // оранжевый
  0xFFF44336, // красный
  0xFFE040FB, // пурпурный
  0xFF00BCD4, // голубой
  0xFF4CAF50, // зелёный
  0xFF64B5F6, // синий (по умолчанию)
];

/// Нарисованный пользователем объект в мировых координатах DXF.
class DrawnObject {
  final String id;
  final String drawingId;
  final DrawnType type;

  /// Точки в мировых координатах DXF.
  final List<Offset> points;

  /// Bulge-значения (параллельно [points]) — используется облаком.
  final List<double> bulges;

  /// Текст (для инструмента «текст»).
  final String? text;

  /// Высота текста в мировых единицах (для text/dimension).
  final double? height;

  /// Цвет в ARGB.
  final int color;

  /// Толщина линии в экранных пикселях.
  final double strokePx;

  /// Поворот объекта (для текста), градусы против часовой стрелки.
  final double rotation;

  /// Слой нарисованного объекта (можно отключать в панели слоёв).
  final String layer;

  final DateTime createdAt;

  const DrawnObject({
    required this.id,
    required this.drawingId,
    required this.type,
    required this.points,
    this.bulges = const [],
    this.text,
    this.height,
    this.color = kDrawnDefaultColor,
    this.strokePx = kDrawnDefaultStrokePx,
    this.rotation = 0,
    this.layer = kDefaultDrawnLayer,
    required this.createdAt,
  });

  /// Копия с изменёнными полями (перемещение/поворот текста).
  DrawnObject copyWith({
    List<Offset>? points,
    List<double>? bulges,
    String? text,
    double? height,
    int? color,
    double? strokePx,
    double? rotation,
    String? layer,
  }) {
    return DrawnObject(
      id: id,
      drawingId: drawingId,
      type: type,
      points: points ?? this.points,
      bulges: bulges ?? this.bulges,
      text: text ?? this.text,
      height: height ?? this.height,
      color: color ?? this.color,
      strokePx: strokePx ?? this.strokePx,
      rotation: rotation ?? this.rotation,
      layer: layer ?? this.layer,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'points': [
        for (final p in points) ...[p.dx, p.dy]
      ],
      'bulges': bulges,
      'text': text,
      'height': height,
      'color': color,
      'strokePx': strokePx,
      'rotation': rotation,
      'layer': layer,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Восстанавливает объект из JSON (БД / manifest `.abris`).
  ///
  /// Старые данные без `color`/`strokePx` получают значения по умолчанию.
  static DrawnObject? fromJson(Map<String, dynamic> json, String drawingId) {
    final typeName = json['type'] as String?;
    DrawnType? type;
    for (final t in DrawnType.values) {
      if (t.name == typeName) {
        type = t;
        break;
      }
    }
    if (type == null) return null;

    final rawPoints = (json['points'] as List?) ?? const [];
    final points = <Offset>[];
    for (var i = 0; i + 1 < rawPoints.length; i += 2) {
      final x = (rawPoints[i] as num?)?.toDouble();
      final y = (rawPoints[i + 1] as num?)?.toDouble();
      if (x == null || y == null) continue;
      points.add(Offset(x, y));
    }
    if (points.isEmpty) return null;

    final rawBulges = (json['bulges'] as List?) ?? const [];
    final bulges = <double>[
      for (final b in rawBulges) (b as num?)?.toDouble() ?? 0.0,
    ];

    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    final text = json['text'] as String?;
    final height = (json['height'] as num?)?.toDouble();
    final color = (json['color'] as num?)?.toInt() ?? kDrawnDefaultColor;
    final strokePx =
        (json['strokePx'] as num?)?.toDouble() ?? kDrawnDefaultStrokePx;
    final rotation = (json['rotation'] as num?)?.toDouble() ?? 0.0;

    return DrawnObject(
      id: (json['id'] as String?) ?? '${DateTime.now().microsecondsSinceEpoch}',
      drawingId: drawingId,
      type: type,
      points: points,
      bulges: bulges,
      text: text,
      height: height,
      color: color,
      strokePx: strokePx,
      rotation: rotation,
      layer: (json['layer'] as String?) ?? kDefaultDrawnLayer,
      createdAt: createdAt,
    );
  }
}
