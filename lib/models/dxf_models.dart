/// Модели DXF-сущностей (примитивов AutoCAD).
library;

abstract class DxfEntity {
  final String layer;

  /// Индекс цвета ACI из группы 62: 0 = BYBLOCK, 256 = BYLAYER, 1..255.
  final int? colorIndex;

  /// «True color» из группы 420 (0xRRGGBB).
  final int? trueColor;

  /// Вес линии из группы 370 (в 1/100 мм). -1=BYLAYER, -2=BYBLOCK, -3=DEFAULT.
  final int? lineWeight;

  /// Высота (Z/elevation) объекта из группы 30 (H в режиме «Координаты»).
  final double elevation;

  DxfEntity({
    required this.layer,
    this.colorIndex,
    this.trueColor,
    this.lineWeight,
    this.elevation = 0,
  });
}

/// Вершина полилинии: координаты + «bulge» (кривизна сегмента:
/// 0 = прямая, ±1 = полуокружность). Используется для дуг и «облаков».
class DxfVertex {
  final double x, y, bulge;
  const DxfVertex(this.x, this.y, [this.bulge = 0]);
}

class DxfLine extends DxfEntity {
  final double x1, y1, x2, y2;
  DxfLine(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.x1,
      required this.y1,
      required this.x2,
      required this.y2});
}

class DxfLwPolyline extends DxfEntity {
  final List<DxfVertex> vertices;
  final bool isClosed;
  DxfLwPolyline(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.vertices,
      this.isClosed = false});
}

/// Старая (2D) полилиния с отдельными VERTEX-сущностями.
class DxfPolyline extends DxfEntity {
  final List<DxfVertex> vertices;
  final bool isClosed;
  DxfPolyline(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.vertices,
      this.isClosed = false});
}

class DxfArc extends DxfEntity {
  final double cx, cy, radius;

  /// Углы в градусах (как в DXF, против часовой стрелки).
  final double startAngle, endAngle;

  DxfArc(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.cx,
      required this.cy,
      required this.radius,
      required this.startAngle,
      required this.endAngle});
}

class DxfEllipse extends DxfEntity {
  final double cx, cy;

  /// Вектор большой полуоси относительно центра.
  final double majorX, majorY;

  /// Отношение малой полуоси к большой.
  final double ratio;

  /// Параметры начала/конца дуги в радианах (как в DXF).
  final double startParam, endParam;

  DxfEllipse(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.cx,
      required this.cy,
      required this.majorX,
      required this.majorY,
      required this.ratio,
      this.startParam = 0,
      this.endParam = 6.283185307179586});
}

class DxfCircle extends DxfEntity {
  final double cx, cy, radius;
  DxfCircle(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.cx,
      required this.cy,
      required this.radius});
}

class DxfPoint extends DxfEntity {
  final double x, y;
  DxfPoint(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.x,
      required this.y});
}

class DxfText extends DxfEntity {
  final double x, y;
  final String content;
  final double height;
  final double rotation;
  DxfText(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.x,
      required this.y,
      required this.content,
      required this.height,
      this.rotation = 0});
}

class DxfInsert extends DxfEntity {
  final String blockName;
  final double x, y, scaleX, scaleY, rotation;
  DxfInsert(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.blockName,
      required this.x,
      required this.y,
      this.scaleX = 1.0,
      this.scaleY = 1.0,
      this.rotation = 0});
}

/// Заполненный четырёхугольник/треугольник: SOLID, TRACE, 3DFACE.
class DxfSolid extends DxfEntity {
  final List<DxfVertex> points;
  DxfSolid(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.points});
}

/// Сплайн, аппроксимированный ломаной по опорным/подгоночным точкам.
class DxfSpline extends DxfEntity {
  final List<DxfVertex> points;
  final bool isClosed;
  DxfSpline(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.points,
      this.isClosed = false});
}

/// Прямая: RAY (полубесконечная) или XLINE (бесконечная).
class DxfRay extends DxfEntity {
  final double x, y, dx, dy;
  final bool isInfinite;
  DxfRay(
      {required super.layer,
      super.colorIndex,
      super.trueColor,
      super.lineWeight,
      super.elevation,
      required this.x,
      required this.y,
      required this.dx,
      required this.dy,
      this.isInfinite = false});
}

class DxfLayer {
  final String name;
  final int colorIndex;
  final int? trueColor;
  final int? lineWeight;
  final bool isOff;
  final bool isFrozen;
  DxfLayer(
      {required this.name,
      this.colorIndex = 7,
      this.trueColor,
      this.lineWeight,
      this.isOff = false,
      this.isFrozen = false});
}

class DxfBlock {
  final String name;
  final double baseX, baseY;
  final double minX, minY, maxX, maxY;
  final List<DxfEntity> entities;
  DxfBlock(
      {required this.name,
      this.baseX = 0,
      this.baseY = 0,
      this.minX = 0,
      this.minY = 0,
      this.maxX = 0,
      this.maxY = 0,
      required this.entities});
}

class DxfDocument {
  final List<DxfLayer> layers;
  final List<DxfEntity> entities;
  final Map<String, DxfBlock> blocks;
  final double minX, minY, maxX, maxY;

  DxfDocument({
    required this.layers,
    required this.entities,
    this.blocks = const {},
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
}
