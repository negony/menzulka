import 'dart:ui';

/// Тип объектной привязки (названия — как в русском AutoCAD 2024).
enum SnapType { vertex, point, intersection, perpendicular, tangent, nearest }

extension SnapTypeLabel on SnapType {
  String get label {
    switch (this) {
      case SnapType.vertex:
        return 'Конечная точка';
      case SnapType.point:
        return 'Узел';
      case SnapType.intersection:
        return 'Пересечение';
      case SnapType.perpendicular:
        return 'Перпендикуляр';
      case SnapType.tangent:
        return 'Касательная';
      case SnapType.nearest:
        return 'Ближайшая';
    }
  }
}

/// Источник привязки: исходный чертёж, нарисованный объект или их пересечение.
enum SnapSource { dxf, drawn, mixed }

extension SnapSourceLabel on SnapSource {
  String get label {
    switch (this) {
      case SnapSource.dxf:
        return 'чертёж';
      case SnapSource.drawn:
        return 'рисунок';
      case SnapSource.mixed:
        return 'чертёж+рисунок';
    }
  }
}

/// Настройки привязок (in-memory, как SyncSettings).
class SnapSettings {
  bool enabled;
  bool vertex;
  bool point;
  bool intersection;
  bool perpendicular;
  bool tangent;
  bool nearest;

  /// Ортогональное черчение (горизонталь/вертикаль от последней точки).
  bool ortho;

  /// Шаг угловой привязки в градусах (null — выключена): 45/30/20/15/10/5.
  double? polarStep;

  SnapSettings({
    this.enabled = true,
    this.vertex = true,
    this.point = true,
    this.intersection = true,
    this.perpendicular = true,
    this.tangent = true,
    this.nearest = true,
    this.ortho = false,
    this.polarStep,
  });
}

/// Найденная точка привязки в мировых координатах DXF.
class SnapResult {
  final Offset point;
  final SnapType type;
  final double distance;

  /// Откуда взята точка: из чертежа (DXF) или из нарисованного объекта.
  final SnapSource source;

  const SnapResult({
    required this.point,
    required this.type,
    required this.distance,
    this.source = SnapSource.dxf,
  });
}
