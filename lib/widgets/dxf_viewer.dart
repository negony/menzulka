import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart' as vec;
import '../models/dxf_models.dart';
import '../models/annotation.dart';
import '../models/drawn_object.dart';
import '../models/measurement.dart';
import '../models/snap_models.dart';
import '../screens/drawing_screen.dart';
import '../services/app_prefs.dart';
import '../services/dxf_elevation.dart';
import '../services/snap_engine.dart';
import '../utils/drawn_geometry.dart';
import '../utils/format_utils.dart';
import 'dxf_canvas_painter.dart';
import 'dxf_overlay_painter.dart';
import 'drawn_objects_painter.dart';
import 'drawn_texts_painter.dart';
import 'drawing_picks_painter.dart';
import 'drawing_preview_painter.dart';
import 'marker_painter.dart';
import 'measurement_labels_painter.dart';
import 'measurement_painter.dart';
import 'snap_glyph.dart';
import 'snap_loupe.dart';
import 'snap_marker_painter.dart';
import '../utils/dxf_overlays.dart';
import '../utils/layer_cache.dart';
import '../utils/marker_clusterer.dart';

class DxfViewer extends StatefulWidget {
  final DxfDocument document;
  final List<Annotation> annotations;
  final Set<String> hiddenLayers;
  final DrawingMode mode;
  final String units;
  final void Function(double dxfX, double dxfY) onCanvasTap;
  final void Function(Measurement)? onMeasurementFinished;

  /// Тап по маркеру существующей точки — открыть её карточку.
  final void Function(Annotation)? onAnnotationTap;

  /// Несколько точек в одном месте — показать выбор точки.
  /// Второй аргумент — точка тапа (с привязкой) для «Новая точка здесь».
  final void Function(List<Annotation>, Offset)? onAnnotationClusterTap;

  /// Стабильный id чертежа (для привязки измерений).
  final String drawingId;

  /// Нарисованные пользователем объекты (режим «Рисование»).
  final List<DrawnObject> drawnObjects;

  /// Новый нарисованный объект — сохранить в БД.
  final ValueChanged<DrawnObject>? onDrawnObjectCreated;

  /// Удалить последний нарисованный объект.
  final VoidCallback? onUndoLastDrawn;

  /// Обновлённый нарисованный объект (перемещение/поворот текста).
  final ValueChanged<DrawnObject>? onDrawnObjectUpdated;

  /// Удалить нарисованный объект (текст и т.п.) полностью.
  final ValueChanged<DrawnObject>? onDrawnObjectDeleted;

  /// Скрытые слои нарисованных объектов.
  final Set<String> hiddenDrawnLayers;

  /// Активный слой для новых объектов.
  final String activeDrawnLayer;

  /// Общие настройки привязок (живут на главном экране).
  final SnapSettings snapSettings;

  /// Создать точку по координате из режима «Координаты».
  final void Function(double dxfX, double dxfY)? onCreatePointAt;

  const DxfViewer({
    super.key,
    required this.document,
    required this.annotations,
    required this.hiddenLayers,
    required this.mode,
    required this.units,
    required this.onCanvasTap,
    required this.snapSettings,
    this.onMeasurementFinished,
    this.onAnnotationTap,
    this.onAnnotationClusterTap,
    this.drawingId = '',
    this.drawnObjects = const [],
    this.onDrawnObjectCreated,
    this.onUndoLastDrawn,
    this.onDrawnObjectUpdated,
    this.onDrawnObjectDeleted,
    this.hiddenDrawnLayers = const {},
    this.activeDrawnLayer = kDefaultDrawnLayer,
    this.onCreatePointAt,
  });

  @override
  State<DxfViewer> createState() => _DxfViewerState();
}

class _DxfViewerState extends State<DxfViewer> {
  late final TransformationController _transformController;
  late DxfLayerCacheManager _cacheManager;
  final _clusterer = MarkerClusterer();
  late DxfOverlays _overlays;
  final List<Offset> _measurementPoints = [];
  bool _measurementClosed = false;
  Size? _viewport;
  bool _fitPending = true;

  late SnapEngine _snapEngine;
  SnapSettings get _snapSettings => widget.snapSettings;
  SnapResult? _snapPreview;
  SnapResult? _lastSnap;

  /// Захваченная координата в режиме «Координаты» (для карточки).
  SnapResult? _coordinateResult;

  /// Точка без привязки (пустое место чертежа) — координаты тоже нужны.
  Offset? _coordRawPoint;

  /// Порядок инструментов рисования (перетаскивается в панели).
  late List<DrawnType> _drawToolOrder = List<DrawnType>.of(DrawnType.values);
  Offset? _hoverScreen;
  Timer? _lastSnapTimer;

  /// Прицеливание удержанием: палец прижат, лупа показывает увеличение.
  bool _aiming = false;
  Offset? _aimScreen;
  final Map<int, Offset> _pointerPositions = {};
  int? _aimPointer;
  double? _pinchDistance;

  /// Двухпальцевая панорама/зум в режиме «Координаты».
  bool _coordPanning = false;
  Offset? _coordPanStartCentroid;
  double? _coordPanStartDistance;
  Matrix4? _coordPanStartMatrix;

  /// Режим рисования: выбранный инструмент и уже указанные точки (мировые).
  DrawnType _drawTool = DrawnType.point;
  final List<Offset> _drawPicks = [];
  int _drawColor = kDrawnDefaultColor;
  double _drawStrokePx = kDrawnDefaultStrokePx;
  static const List<double> _textHeightOptions = [10.0, 14.0, 18.0, 24.0];

  /// Текущая точка пальца/прицеливания (мировая) и путь свободного облака.
  Offset? _drawAimWorld;
  final List<Offset> _cloudPath = [];
  final _drawToolsScroll = ScrollController();
  final _drawSettingsScroll = ScrollController();
  final _drawColorsScroll = ScrollController();

  /// Отслеживание «скольжения одним пальцем» в режиме рисования.
  Offset? _dragDownScreen;
  bool _dragMovedEnough = false;
  bool _multiPointerGesture = false;

  /// Выбранный объект (текст или прямоугольник): перемещение удержанием,
  /// поворот двумя пальцами; для текста — ещё и масштаб щипком.
  DrawnObject? _selectedObject;
  DrawnObject? _editedObject;
  Offset? _editStartScreen;
  Offset? _editStartWorldPos;
  List<Offset>? _editStartPoints;
  double? _rotStartAngle;
  double _rotStartRotation = 0;
  double? _pinchStartDist;
  double _pinchStartHeight = 0;
  bool _objectChanged = false;

  /// Поворот текста перетаскиванием за уголок рамки (мышь и палец).
  bool _textRotating = false;

  /// Панорама средней кнопкой мыши: старт и исходная матрица преобразования.
  bool _middlePanning = false;
  int? _middlePanPointer;
  Offset? _middlePanStartScreen;
  Matrix4? _middlePanStartMatrix;

  static const double _snapTolerancePx = 14.0;

  double get _screenScale {
    final s = _transformController.value.getMaxScaleOnAxis();
    return s <= 0 ? 1.0 : s;
  }

  double get _snapToleranceWorld => _snapTolerancePx / _screenScale;

  Offset _dxfToLocal(Offset world) => Offset(
        world.dx - widget.document.minX,
        world.dy == world.dy ? widget.document.maxY - world.dy : 0,
      );

  /// Мировые координаты DXF -> экранные координаты вьюера.
  Offset _worldToScreen(Offset world) {
    final local = _dxfToLocal(world);
    final v = _transformController.value
        .transform3(vec.Vector3(local.dx, local.dy, 0));
    return Offset(v.x, v.y);
  }

  /// Экранная позиция уголка-ручки поворота выбранного текста.
  Offset? _textRotationHandleScreen() {
    final obj = _selectedObject;
    if (obj == null || obj.type != DrawnType.text || obj.points.isEmpty) {
      return null;
    }
    final live = (_editedObject != null && _editedObject!.id == obj.id)
        ? _editedObject!
        : obj;
    final scale = _screenScale;
    final heightWorld = live.height ?? (12 / scale);
    final fontSize = (heightWorld * scale).clamp(2.0, 4000.0);
    final tp = TextPainter(
      text: TextSpan(
        text: live.text ?? '',
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final hw = (tp.width + 16) / 2;
    final hh = (tp.height + 12) / 2;
    tp.dispose();
    final a = live.rotation * math.pi / 180;
    // Как в DrawnTextsPainter: canvas.rotate(-a). Локальная точка (x, y)
    // переходит на экран как (x·cos a + y·sin a, -x·sin a + y·cos a).
    // Уголок рамки — правый верхний в системе текста: (hw, -hh).
    final offset = Offset(
      hw * math.cos(a) - hh * math.sin(a),
      -hw * math.sin(a) - hh * math.cos(a),
    );
    return _worldToScreen(live.points.first) + offset;
  }

  // --- Мышь: панорама средней кнопкой и завершение правой ---

  void _startMiddlePan(PointerDownEvent event) {
    _middlePanning = true;
    _middlePanPointer = event.pointer;
    _middlePanStartScreen = event.localPosition;
    _middlePanStartMatrix = _transformController.value.clone();
    if (mounted) setState(() {});
  }

  void _updateMiddlePan(Offset screen) {
    final start = _middlePanStartScreen;
    final m0 = _middlePanStartMatrix;
    if (start == null || m0 == null) return;
    final delta = screen - start;
    _transformController.value =
        Matrix4.translationValues(delta.dx, delta.dy, 0) * m0;
  }

  void _endMiddlePan() {
    if (!_middlePanning) return;
    _middlePanning = false;
    _middlePanPointer = null;
    _middlePanStartScreen = null;
    _middlePanStartMatrix = null;
  }

  /// Правая кнопка мыши: завершает полилинию/облако (как «Завершить»).
  void _finishByRightClick() {
    if (widget.mode != DrawingMode.drawing) return;
    if (_drawTool == DrawnType.cloud && _cloudPath.length >= 3) {
      final points = List<Offset>.of(_cloudPath);
      setState(() => _cloudPath.clear());
      _emitDrawn(points: points);
      return;
    }
    _finishDrawing();
  }

  void _updateSnap(Offset? screen) {
    if (!mounted) return;
    // Во время прицеливания привязка пересчитывается ТОЛЬКО для экранной
    // позиции пальца прицела. Любой другой screen (второй палец при
    // масштабировании, hover, перестройка виджета) её не двигает — иначе
    // вторая точка «прыгает» на второй палец.
    if (_aiming &&
        screen != null &&
        _aimScreen != null &&
        screen != _aimScreen) {
      return;
    }
    // Два и более пальцев — это масштабирование/панорама: привязку не двигаем,
    // иначе она «улетает» к месту второго пальца.
    if (_pointerPositions.length >= 2) return;
    _hoverScreen = screen;
    final isDrawing = widget.mode == DrawingMode.drawing;
    final isCoordinates = widget.mode == DrawingMode.coordinates;
    // В режиме «Точка» привязки тоже нужны: лупа/удержание должны показывать
    // узел/пересечение и ставить точку точно в него.
    final isAnnotation = widget.mode == DrawingMode.annotation;
    if ((widget.mode != DrawingMode.measurement &&
            !isDrawing &&
            !isCoordinates &&
            !isAnnotation) ||
        screen == null) {
      if (_snapPreview != null) setState(() => _snapPreview = null);
      return;
    }
    final world = _localToDxf(_screenToLocal(screen));
    if (!_snapSettings.enabled) {
      if (isDrawing || isAnnotation) {
        _drawAimWorld = world;
      }
      if (_snapPreview != null) setState(() => _snapPreview = null);
      return;
    }
    final Offset? fromWorld;
    if (widget.mode == DrawingMode.measurement) {
      fromWorld = _measurementPoints.isEmpty
          ? null
          : _localToDxf(_measurementPoints.last);
    } else if (widget.mode == DrawingMode.drawing) {
      fromWorld = _drawPicks.isEmpty ? null : _drawPicks.last;
    } else if (widget.mode == DrawingMode.annotation) {
      fromWorld = null;
    } else {
      // В координатах перпендикуляр/касательная — от последней захваченной.
      fromWorld = _coordinateResult?.point;
    }
    final result = _querySnap(world, from: fromWorld);
    if (isDrawing) {
      // Орто/угловая привязка — для свободного прицела; объектная привязка
      // важнее и даёт точную точку.
      // Облако рисуется свободно, без привязок.
      final newAim = _drawTool == DrawnType.cloud
          ? world
          : (result?.point ?? _applyDraftingAids(world));
      final aimChanged = newAim != _drawAimWorld;
      _drawAimWorld = newAim;
      if (result != _snapPreview || aimChanged) {
        setState(() => _snapPreview = result);
      }
      return;
    }
    if (isAnnotation) {
      // Точка из режима «Точка»: цель — точка привязки (если найдена).
      final newAim = result?.point ?? world;
      final aimChanged = newAim != _drawAimWorld;
      _drawAimWorld = newAim;
      if (result != _snapPreview || aimChanged) {
        setState(() => _snapPreview = result);
      }
      return;
    }
    if (result != _snapPreview) setState(() => _snapPreview = result);
  }

  Offset? get _previewLocal {
    if (widget.mode != DrawingMode.measurement || _measurementPoints.isEmpty) {
      return null;
    }
    final snapped = _snapPreview;
    if (snapped != null) return _dxfToLocal(snapped.point);
    final hover = _hoverScreen;
    return hover == null ? null : _screenToLocal(hover);
  }

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController()
      ..addListener(_handleTransformChanged);
    _cacheManager = DxfLayerCacheManager()..initialize(widget.document);
    _overlays = buildDxfOverlays(widget.document);
    _snapEngine =
        SnapEngine(widget.document, drawnObjects: _visibleDrawnObjects);
    _drawToolOrder = _loadToolOrder();
  }

  /// Порядок инструментов: сохранённый в настройках + недостающие в конец.
  List<DrawnType> _loadToolOrder() {
    final saved = AppPrefs.instance.drawToolOrder;
    final byName = {for (final t in DrawnType.values) t.name: t};
    final order = <DrawnType>[];
    for (final name in saved) {
      final t = byName[name];
      if (t != null && !order.contains(t)) order.add(t);
    }
    for (final t in DrawnType.values) {
      if (!order.contains(t)) order.add(t);
    }
    return order.isEmpty ? List<DrawnType>.of(DrawnType.values) : order;
  }

  /// Видимые нарисованные объекты (скрытые слои не показываем и не привязываем).
  List<DrawnObject> get _visibleDrawnObjects => [
        for (final o in widget.drawnObjects)
          if (!widget.hiddenDrawnLayers.contains(o.layer)) o,
      ];

  bool _sameStrings(Set<String> a, Set<String> b) =>
      a.length == b.length && a.every(b.contains);

  @override
  void didUpdateWidget(covariant DxfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hiddenChanged =
        !_sameStrings(oldWidget.hiddenDrawnLayers, widget.hiddenDrawnLayers);
    if (!identical(oldWidget.drawnObjects, widget.drawnObjects) ||
        hiddenChanged) {
      _snapEngine =
          SnapEngine(widget.document, drawnObjects: _visibleDrawnObjects);
      // Обновить выбранный объект, если он был изменён снаружи или скрыт.
      final selected = _selectedObject;
      if (selected != null) {
        DrawnObject? updated;
        for (final o in widget.drawnObjects) {
          if (o.id == selected.id) {
            updated = o;
            break;
          }
        }
        if (updated != null &&
            widget.hiddenDrawnLayers.contains(updated.layer)) {
          updated = null;
        }
        _selectedObject = updated;
        _editedObject = updated;
      }
    }
    if (!identical(oldWidget.document, widget.document)) {
      _cacheManager.dispose();
      _cacheManager = DxfLayerCacheManager()..initialize(widget.document);
      _overlays = buildDxfOverlays(widget.document);
      _snapEngine =
          SnapEngine(widget.document, drawnObjects: _visibleDrawnObjects);
      _measurementPoints.clear();
      _fitPending = true;
      _viewport = null;
      _snapPreview = null;
      _lastSnap = null;
      _lastSnapTimer?.cancel();
      _aiming = false;
      _aimScreen = null;
      _aimPointer = null;
      _pinchDistance = null;
      _pointerPositions.clear();
      _drawPicks.clear();
      _cloudPath.clear();
      _drawAimWorld = null;
    }
    if (oldWidget.mode != widget.mode) {
      _snapPreview = null;
      _lastSnap = null;
      _lastSnapTimer?.cancel();
      _aiming = false;
      _aimScreen = null;
      _aimPointer = null;
      _pinchDistance = null;
      _pointerPositions.clear();
      _drawPicks.clear();
      _cloudPath.clear();
      _drawAimWorld = null;
      // Выбор объекта относится к другому режиму — снимаем.
      _selectedObject = null;
      _editedObject = null;
      _objectChanged = false;
      _rotStartAngle = null;
      _pinchStartDist = null;
      _pinchStartHeight = 0;
      _editStartScreen = null;
      _editStartWorldPos = null;
      _editStartPoints = null;
      _endCoordinatePan();
    }
    // Настройки привязок живут на главном экране и меняются без смены
    // параметров вьюера — обновляем прицел, чтобы маркер сразу их учитывал.
    _updateSnap(_hoverScreen);
  }

  @override
  void dispose() {
    _lastSnapTimer?.cancel();
    _transformController.removeListener(_handleTransformChanged);
    _transformController.dispose();
    _cacheManager.dispose();
    _drawToolsScroll.dispose();
    _drawSettingsScroll.dispose();
    _drawColorsScroll.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    // Пересчитываем положение маркеров и толщину линий при пане/зуме.
    if (!mounted) return;
    setState(() {});
    // Во время прицеливания привязку не пересчитываем: она «привязана» к
    // пальцу, которым рисуем, а не к _hoverScreen (там может быть второй палец
    // при масштабировании — иначе привязка прыгает на него).
    if (!_aiming &&
        _hoverScreen != null &&
        (widget.mode == DrawingMode.measurement ||
            widget.mode == DrawingMode.drawing)) {
      _updateSnap(_hoverScreen);
    }
  }

  double get _boxWidth => widget.document.maxX - widget.document.minX;
  double get _boxHeight => widget.document.maxY - widget.document.minY;

  /// Вписывает локальную область чертежа (0..boxW, 0..boxH) в видимую область
  /// с отступом 10% и центрированием по обеим осям.
  void _fitToScreen(Size viewport) {
    final w = _boxWidth;
    final h = _boxHeight;
    if (w <= 0 || h <= 0 || viewport.width <= 0 || viewport.height <= 0) return;
    final scale = 0.9 * math.min(viewport.width / w, viewport.height / h);
    final dx = (viewport.width - scale * w) / 2;
    final dy = (viewport.height - scale * h) / 2;
    _transformController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// Видимая область в локальных координатах — для обрезки «прямой».
  Rect _visibleLocalRect(Size viewport, double scale) {
    final matrix = _transformController.value.clone()..invert();
    final corners = <Offset>[];
    for (final c in [
      Offset.zero,
      Offset(viewport.width, 0),
      Offset(0, viewport.height),
      Offset(viewport.width, viewport.height),
    ]) {
      final v = matrix.transform3(vec.Vector3(c.dx, c.dy, 0));
      corners.add(Offset(v.x, v.y));
    }
    var minXv = corners.first.dx, maxXv = corners.first.dx;
    var minYv = corners.first.dy, maxYv = corners.first.dy;
    for (final c in corners) {
      if (c.dx < minXv) minXv = c.dx;
      if (c.dx > maxXv) maxXv = c.dx;
      if (c.dy < minYv) minYv = c.dy;
      if (c.dy > maxYv) maxYv = c.dy;
    }
    return Rect.fromLTRB(minXv, minYv, maxXv, maxYv)
        .inflate(40 / (scale <= 0 ? 1 : scale));
  }

  Offset _screenToLocal(Offset screen) {
    final matrix = _transformController.value.clone()..invert();
    final v = matrix.transform3(vec.Vector3(screen.dx, screen.dy, 0));
    return Offset(v.x, v.y);
  }

  Offset _localToScreen(Offset local) {
    final v = _transformController.value
        .transform3(vec.Vector3(local.dx, local.dy, 0));
    return Offset(v.x, v.y);
  }

  Offset _localToDxf(Offset local) =>
      Offset(local.dx + widget.document.minX, widget.document.maxY - local.dy);

  void _handleTap(Offset screenPosition) {
    // Сначала проверяем тап по маркеру существующей точки.
    if (widget.mode != DrawingMode.measurement &&
        widget.mode != DrawingMode.drawing &&
        widget.mode != DrawingMode.coordinates &&
        widget.annotations.isNotEmpty) {
      final clusters = _clusterer.clusterize(
        annotations: widget.annotations,
        document: widget.document,
        matrix: _transformController.value,
        minDistancePx: 32.0,
      );
      for (final cluster in clusters) {
        final dx = cluster.centerX - screenPosition.dx;
        final dy = cluster.centerY - screenPosition.dy;
        if (dx * dx + dy * dy <= 26 * 26) {
          if (widget.onAnnotationClusterTap != null) {
            final world = _localToDxf(_screenToLocal(screenPosition));
            final snap = _snapSettings.enabled ? _querySnap(world) : null;
            widget.onAnnotationClusterTap!(
                cluster.annotations, snap?.point ?? world);
            return;
          }
          if (cluster.isSingle) {
            widget.onAnnotationTap?.call(cluster.annotations.first);
            return;
          } else {
            // Несколько точек слиплись — приближаем это место.
            _zoomAt(screenPosition, 2.0);
          }
          return;
        }
      }
    }
    final local = _screenToLocal(screenPosition);
    // Выделение/перемещение нарисованных объектов — только в режиме «Обзор».
    // При рисовании существующие объекты должны быть неподвижны: тап по ним
    // ставит точку (например, на вершину прямоугольника), а не выделяет его.
    if (widget.mode == DrawingMode.overview) {
      final hit = _hitTestEditable(screenPosition);
      if (hit != null) {
        setState(() {
          _selectedObject = hit;
          _editedObject = hit;
          _objectChanged = false;
          _editStartScreen = null;
          _editStartWorldPos = null;
          _editStartPoints = null;
          _rotStartAngle = null;
          _pinchStartDist = null;
          _pinchStartHeight = 0;
        });
        return;
      }
      if (_selectedObject != null) {
        setState(() {
          _selectedObject = null;
          _editedObject = null;
          _objectChanged = false;
          _editStartScreen = null;
          _editStartWorldPos = null;
          _editStartPoints = null;
          _rotStartAngle = null;
          _pinchStartDist = null;
          _pinchStartHeight = 0;
        });
        return;
      }
    }
    if (widget.mode == DrawingMode.measurement) {
      // Тап по первой точке (при 3+ точках) замыкает/размыкает контур.
      if (_measurementPoints.length >= 3) {
        final firstScreen = _localToScreen(_measurementPoints.first);
        final dx = firstScreen.dx - screenPosition.dx;
        final dy = firstScreen.dy - screenPosition.dy;
        if (dx * dx + dy * dy <= 24 * 24) {
          setState(() => _measurementClosed = !_measurementClosed);
          return;
        }
      }

      final world = _localToDxf(local);
      SnapResult? snap;
      if (_snapSettings.enabled) {
        final fromWorld = _measurementPoints.isEmpty
            ? null
            : _localToDxf(_measurementPoints.last);
        snap = _querySnap(world, from: fromWorld);
      }
      _addMeasurementPoint(world: world, snap: snap);
    } else if (widget.mode == DrawingMode.annotation) {
      final world = _localToDxf(local);
      // Привязка как при рисовании: точка создания — узел/пересечение и т.п.
      final snap = _snapSettings.enabled ? _querySnap(world) : null;
      final p = snap?.point ?? world;
      widget.onCanvasTap(p.dx, p.dy);
    } else if (widget.mode == DrawingMode.drawing) {
      _handleDrawingTap(_localToDxf(local));
    } else if (widget.mode == DrawingMode.coordinates) {
      // В режиме координат захват выполняется pointer-событиями (включая
      // протягивание), здесь дублировать не нужно.
    }
  }

  /// Привязка по единому индексу: примитивы чертежа и нарисованные объекты,
  /// включая их взаимные (смешанные) пересечения.
  SnapResult? _querySnap(Offset world, {Offset? from}) {
    if (!_snapSettings.enabled) return null;
    return _snapEngine.query(
      world,
      tolerance: _snapToleranceWorld,
      from: from,
      hiddenLayers: {
        ...widget.hiddenLayers,
        ...widget.hiddenDrawnLayers,
      },
      settings: _snapSettings,
    );
  }

  /// Полоса выбора вдоль линий прямоугольника (px): внутри можно рисовать.
  static const double _rectSelectStripPx = 12.0;

  /// Расстояние от точки до отрезка (для полосы выбора).
  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 <= 1e-12) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    final q = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - q).distance;
  }

  /// Выбираемый объект под экранной точкой (текст или прямоугольник).
  ///
  /// Прямоугольник выбирается только в узкой полосе вдоль его линий, чтобы
  /// можно было свободно рисовать внутри него.
  DrawnObject? _hitTestEditable(Offset screen) {
    final scale = _screenScale;
    final matrix = _transformController.value;
    for (final o in _visibleDrawnObjects.reversed) {
      if (o.type == DrawnType.rectangle && o.points.length >= 4) {
        final poly = [
          for (final p in o.points) _localToScreen(_dxfToLocal(p)),
        ];
        var nearBorder = false;
        for (var i = 0; i < poly.length; i++) {
          final d = _distanceToSegment(
            screen,
            poly[i],
            poly[(i + 1) % poly.length],
          );
          if (d <= _rectSelectStripPx) {
            nearBorder = true;
            break;
          }
        }
        if (nearBorder) return o;
        continue;
      }
      if (o.type != DrawnType.text || o.points.isEmpty) continue;
      final local = _dxfToLocal(o.points.first);
      final v = matrix.transform3(vec.Vector3(local.dx, local.dy, 0));
      final center = Offset(v.x, v.y);
      final heightWorld = o.height ?? (12 / scale);
      final fontSize = (heightWorld * scale).clamp(2.0, 4000.0);
      final tp = TextPainter(
        text: TextSpan(
          text: o.text ?? '',
          style: TextStyle(fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final a = o.rotation * math.pi / 180;
      final dx = screen.dx - center.dx;
      final dy = screen.dy - center.dy;
      // Обратное преобразование поворота экранного слоя.
      final px = dx * math.cos(a) - dy * math.sin(a);
      final py = dx * math.sin(a) + dy * math.cos(a);
      final inside =
          px.abs() <= tp.width / 2 + 10 && py.abs() <= tp.height / 2 + 8;
      tp.dispose();
      if (inside) return o;
    }
    return null;
  }

  Offset _centroid(List<Offset> points) {
    var sx = 0.0, sy = 0.0;
    for (final p in points) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / points.length, sy / points.length);
  }

  List<Offset> _rotatePoints(
      List<Offset> points, Offset center, double angleRad) {
    final c = math.cos(angleRad);
    final s = math.sin(angleRad);
    return [
      for (final p in points)
        Offset(
          center.dx + (p.dx - center.dx) * c - (p.dy - center.dy) * s,
          center.dy + (p.dx - center.dx) * s + (p.dy - center.dy) * c,
        ),
    ];
  }

  void _commitObjectEdit() {
    final edited = _editedObject;
    if (edited == null || !_objectChanged) return;
    _objectChanged = false;
    setState(() => _selectedObject = edited);
    widget.onDrawnObjectUpdated?.call(edited);
  }

  /// Панель действий для выбранного объекта (режим «Обзор»): изменить текст,
  /// удалить объект.
  Widget _buildSelectedObjectPanel() {
    final o = _selectedObject;
    if (o == null) return const SizedBox.shrink();
    final isText = o.type == DrawnType.text;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isText ? 'Текст: «${o.text ?? ''}»' : 'Объект выбран',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
            if (isText)
              TextButton.icon(
                key: const Key('edit-drawn-text'),
                onPressed: _editSelectedText,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Изменить'),
              ),
            TextButton.icon(
              key: const Key('delete-drawn-object'),
              onPressed: _deleteSelectedObject,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Удалить'),
            ),
          ],
        ),
      ),
    );
  }

  /// Изменить текст выбранного объекта (диалог).
  Future<void> _editSelectedText() async {
    final o = _selectedObject;
    if (o == null || o.type != DrawnType.text) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TextEditDialog(initial: o.text ?? ''),
    );
    if (!mounted) return;
    final text = result?.trim();
    if (text == null || text.isEmpty || text == o.text) return;
    setState(() {
      _editedObject = o.copyWith(text: text);
      _objectChanged = true;
    });
    _commitObjectEdit();
  }

  /// Удалить выбранный нарисованный объект.
  void _deleteSelectedObject() {
    final o = _selectedObject;
    if (o == null) return;
    setState(() {
      _selectedObject = null;
      _editedObject = null;
      _objectChanged = false;
      _editStartScreen = null;
      _editStartWorldPos = null;
      _editStartPoints = null;
      _rotStartAngle = null;
      _pinchStartDist = null;
      _pinchStartHeight = 0;
    });
    widget.onDrawnObjectDeleted?.call(o);
  }

  /// Добавляет вершину измерения (с учётом привязки) и запускает маркер.
  void _addMeasurementPoint({required Offset world, SnapResult? snap}) {
    final snappedWorld = snap?.point ?? world;

    // Если привязка совпала с первой вершиной — замыкаем, без дубля.
    if (snap != null && _measurementPoints.length >= 3) {
      final firstWorld = _localToDxf(_measurementPoints.first);
      if ((snappedWorld - firstWorld).distance <= _snapToleranceWorld * 0.5) {
        setState(() => _measurementClosed = !_measurementClosed);
        return;
      }
    }

    final pointLocal = _dxfToLocal(snappedWorld);
    setState(() {
      _measurementPoints.add(pointLocal);
      _measurementClosed = false;
      _lastSnap = snap;
      _snapPreview = null;
      _hoverScreen = null;
    });
    _lastSnapTimer?.cancel();
    _lastSnapTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _lastSnap = null);
    });
  }

  // ---------- режим рисования ----------

  void _handleDrawingTap(Offset world) {
    SnapResult? snap;
    if (_snapSettings.enabled) {
      snap = _querySnap(
        world,
        from: _drawPicks.isEmpty ? null : _drawPicks.last,
      );
    }
    final point = snap?.point ?? _applyDraftingAids(world);
    if (_drawTool == DrawnType.cloud) {
      // Облако рисуется только протягиванием пальца — тап точки не добавляет.
      return;
    }
    _lastSnap = snap;
    _snapPreview = null;
    _hoverScreen = null;
    _lastSnapTimer?.cancel();
    _lastSnapTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _lastSnap = null);
    });
    setState(() => _drawPicks.add(point));

    switch (_drawTool) {
      case DrawnType.point:
        _emitDrawn(points: [point]);
      case DrawnType.text:
        _addDrawnText(point);
      case DrawnType.polyline:
      case DrawnType.cloud:
        // Вершины накапливаются; завершение — кнопкой или отпусканием.
        break;
      case DrawnType.dimension:
        // Первые две точки задают отрезок; третий тап — полка по умолчанию.
        if (_drawPicks.length == 3) {
          final p1 = _drawPicks[0];
          final p2 = _drawPicks[1];
          _emitDrawn(points: [
            p1,
            p2,
            defaultDimensionShelf(p1, p2, 40 / _screenScale),
          ]);
        }
      case DrawnType.line:
      case DrawnType.ray:
      case DrawnType.circle:
      case DrawnType.rectangle:
        if (_drawPicks.length >= 2) {
          _emitDrawn(points: List<Offset>.of(_drawPicks));
        }
    }
  }

  void _emitDrawn({
    required List<Offset> points,
    String? text,
    double? height,
  }) {
    if (points.isEmpty) return;
    final tool = _drawTool;
    var pts = List<Offset>.of(points);
    var bulges = <double>[];
    if (tool == DrawnType.rectangle) {
      if (pts.length < 2) return;
      pts = rectangleCorners(pts[0], pts[1]);
    } else if (tool == DrawnType.cloud) {
      if (pts.length < 3) return;
      final cloud = buildCloudFromPolygon(pts);
      pts = cloud.vertices;
      bulges = cloud.bulges;
    } else if (tool == DrawnType.polyline) {
      if (pts.length < 2) return;
    } else if (tool == DrawnType.dimension) {
      if (pts.length < 3) return;
    } else if (tool == DrawnType.line ||
        tool == DrawnType.ray ||
        tool == DrawnType.circle) {
      if (pts.length < 2) return;
    }

    // Высота подписи размера — по умолчанию (12 px в текущем масштабе);
    // высота текста выбирается в диалоге ввода текста.
    final objectHeight = height ??
        (tool == DrawnType.dimension && _screenScale > 0
            ? 12 / _screenScale
            : null);

    final object = DrawnObject(
      id: const Uuid().v4(),
      drawingId: widget.drawingId,
      type: tool,
      points: pts,
      bulges: bulges,
      text: text,
      height: objectHeight,
      color: _drawColor,
      strokePx: _drawStrokePx,
      layer: widget.activeDrawnLayer,
      createdAt: DateTime.now(),
    );
    setState(() {
      _drawPicks.clear();
      _cloudPath.clear();
      _drawAimWorld = null;
      _snapPreview = null;
    });
    widget.onDrawnObjectCreated?.call(object);
  }

  Future<void> _addDrawnText(Offset point) async {
    var input = '';
    var heightPx = 14.0;
    final value = await showDialog<({String text, double heightPx})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Текст на чертеже'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Введите текст'),
                onChanged: (v) => input = v,
                onSubmitted: (v) => Navigator.pop(
                  dialogContext,
                  (text: v, heightPx: heightPx),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Высота текста',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 0,
                children: [
                  for (final px in _textHeightOptions)
                    _textHeightChip(
                      px,
                      heightPx,
                      (v) => setDialogState(() => heightPx = v),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                (text: input, heightPx: heightPx),
              ),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    final text = value?.text.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) setState(() => _drawPicks.clear());
      return;
    }
    final height = _screenScale > 0 ? value!.heightPx / _screenScale : 2.5;
    _emitDrawn(points: List<Offset>.of(_drawPicks), text: text, height: height);
  }

  void _finishDrawing() {
    if (_drawTool == DrawnType.polyline && _drawPicks.length >= 2) {
      _emitDrawn(points: List<Offset>.of(_drawPicks));
      return;
    }
    if (_drawTool == DrawnType.cloud && _drawPicks.length >= 3) {
      _emitDrawn(points: List<Offset>.of(_drawPicks));
    }
  }

  void _cancelDrawingPicks() {
    if (_drawPicks.isEmpty && _cloudPath.isEmpty) return;
    setState(() {
      _drawPicks.clear();
      _cloudPath.clear();
      _drawAimWorld = null;
    });
  }

  void _selectDrawTool(DrawnType tool) {
    if (_drawTool == tool) return;
    setState(() {
      _drawTool = tool;
      _drawPicks.clear();
      _cloudPath.clear();
      _drawAimWorld = null;
      // Снять выделение объекта — иначе pointer-down уходит в перемещение.
      _selectedObject = null;
      _editedObject = null;
      _objectChanged = false;
    });
  }

  String get _drawHint {
    switch (_drawTool) {
      case DrawnType.point:
        return 'Коснитесь точки или удерживайте для привязки';
      case DrawnType.text:
        return 'Коснитесь места — ввод текста и его высота в окне';
      case DrawnType.polyline:
        return _drawPicks.isEmpty
            ? 'Укажите вершины, затем «Завершить»'
            : 'Вершин: ${_drawPicks.length} — укажите следующую или завершите';
      case DrawnType.cloud:
        return 'Обведите облако пальцем';
      case DrawnType.rectangle:
        return _drawPicks.isEmpty
            ? 'Укажите первый угол'
            : 'Укажите противоположный угол';
      case DrawnType.dimension:
        switch (_drawPicks.length) {
          case 0:
            return 'Укажите первую точку размера';
          case 1:
            return 'Укажите вторую точку размера';
          default:
            return 'Тап — полка по умолчанию, удержание — подвинуть';
        }
      case DrawnType.circle:
        return _drawPicks.isEmpty
            ? 'Укажите центр круга'
            : 'Ведите палец для радиуса (или тап)';
      default:
        return _drawPicks.isEmpty
            ? 'Укажите первую точку (тап или удержание)'
            : 'Укажите вторую точку';
    }
  }

  /// Сохраняет захваченную координату (режим «Координаты»); null — сброс.
  void _captureCoordinate(SnapResult? result, {Offset? raw}) {
    _lastSnapTimer?.cancel();
    if (!mounted) {
      _coordinateResult = result;
      _coordRawPoint = raw;
      return;
    }
    setState(() {
      _coordinateResult = result;
      _coordRawPoint = result == null ? raw : null;
      _lastSnap = result;
      _snapPreview = null;
      _hoverScreen = null;
    });
  }

  /// Точка для действий карточки: привязка, иначе «сырая» точка без привязки.
  Offset? get _coordinateEffectivePoint =>
      _coordinateResult?.point ?? _coordRawPoint;

  /// Копирует X/Y захваченной координаты (числа без единиц и группировки).
  Future<void> _copyCoordinate() async {
    final r = _coordinateResult;
    if (r == null) return;
    final text =
        '${r.point.dx.toStringAsFixed(3)} ${r.point.dy.toStringAsFixed(3)}';
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Скопировано: $text'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось скопировать координаты')),
        );
      }
    }
  }

  /// Начало прицеливания удержанием (лупа + привязки).
  void _startAim(Offset screen) {
    if (_aiming) return;
    if (widget.mode != DrawingMode.measurement &&
        widget.mode != DrawingMode.drawing &&
        widget.mode != DrawingMode.coordinates &&
        widget.mode != DrawingMode.annotation) {
      return;
    }
    // При редактировании текста удержание не прицеливается.
    if (_selectedObject != null) return;
    _aiming = true;
    _aimScreen = screen;
    _aimPointer =
        _pointerPositions.isEmpty ? null : _pointerPositions.keys.first;
    _pinchDistance = null;
    _drawAimWorld = null;
    _cloudPath.clear();
    _updateSnap(screen);
    if (widget.mode == DrawingMode.drawing &&
        _drawTool == DrawnType.cloud &&
        _drawAimWorld != null) {
      _cloudPath.add(_drawAimWorld!);
    }
    if (mounted) setState(() {});
  }

  /// Палец сместился, не отрываясь от экрана — привязка скользит за ним.
  void _updateAim(Offset screen) {
    if (!_aiming) return;
    _aimScreen = screen;
    _updateSnap(screen);
    if (widget.mode == DrawingMode.drawing &&
        _drawTool == DrawnType.cloud &&
        _drawAimWorld != null) {
      final p = _drawAimWorld!;
      if (_cloudPath.isEmpty ||
          (p - _cloudPath.last).distance > 3 / _screenScale) {
        setState(() => _cloudPath.add(p));
      }
    }
    if (mounted) setState(() {});
  }

  /// Отпускание пальца: фиксируем точку (измерение) или завершаем фигуру.
  void _commitAim() {
    if (!_aiming) return;
    final aim = _aimScreen;
    final snap = _snapPreview;
    final aimWorld = _drawAimWorld ??
        (aim == null ? null : _localToDxf(_screenToLocal(aim)));
    _aiming = false;
    _aimScreen = null;
    _aimPointer = null;
    _pinchDistance = null;
    if (widget.mode == DrawingMode.coordinates) {
      _captureCoordinate(snap, raw: aimWorld);
      return;
    }
    if (widget.mode == DrawingMode.annotation) {
      // Точка из режима «Точка»: координаты — точка привязки (или под пальцем).
      // Привязку запрашиваем ещё раз по финальной точке: во время протягивания
      // состояние могло не успеть обновиться.
      SnapResult? pSnap = snap;
      if (pSnap == null && aimWorld != null && _snapSettings.enabled) {
        pSnap = _querySnap(aimWorld);
      }
      final p = pSnap?.point ?? aimWorld;
      _drawAimWorld = null;
      _snapPreview = null;
      if (p != null) widget.onCanvasTap(p.dx, p.dy);
      if (mounted) setState(() {});
      return;
    }
    if (widget.mode == DrawingMode.drawing) {
      _applyDrawingAim(aimWorld);
      return;
    }
    if (aim == null) {
      if (mounted) setState(() {});
      return;
    }
    _addMeasurementPoint(
      world: _localToDxf(_screenToLocal(aim)),
      snap: snap,
    );
  }

  /// Ортогональное/угловое черчение: ограничивает точку от последней вершины.
  Offset _applyDraftingAids(Offset aim) {
    if (widget.mode != DrawingMode.drawing) return aim;
    if (_drawPicks.isEmpty) return aim;
    if (!_draftingApplies(_drawTool)) return aim;
    final from = _drawPicks.last;
    final s = widget.snapSettings;
    final d = aim - from;
    if (d.distance < 1e-9) return aim;
    if (s.ortho) {
      if (d.dx.abs() >= d.dy.abs()) return Offset(aim.dx, from.dy);
      return Offset(from.dx, aim.dy);
    }
    final step = s.polarStep;
    if (step == null || step <= 0) return aim;
    final len = d.distance;
    final stepRad = step * math.pi / 180;
    // Угол откладываем от предыдущего звена (для полилинии — от предыдущего
    // отрезка); для первого отрезка — от горизонтали.
    var base = 0.0;
    if (_drawPicks.length >= 2) {
      final prev = _drawPicks[_drawPicks.length - 2];
      final seg = from - prev;
      if (seg.distance > 1e-9) base = math.atan2(seg.dy, seg.dx);
    }
    final ang = math.atan2(d.dy, d.dx);
    final snapped = base + ((ang - base) / stepRad).roundToDouble() * stepRad;
    return Offset(
      from.dx + math.cos(snapped) * len,
      from.dy + math.sin(snapped) * len,
    );
  }

  /// Инструменты, к которым применимы орто/угловая привязка.
  bool _draftingApplies(DrawnType tool) =>
      tool == DrawnType.line ||
      tool == DrawnType.polyline ||
      tool == DrawnType.ray;

  /// Отпускание пальца в режиме рисования.
  void _applyDrawingAim(Offset? aimWorld) {
    if (aimWorld == null) {
      if (mounted) setState(() {});
      return;
    }
    final tool = _drawTool;
    if (tool == DrawnType.cloud) {
      if (_cloudPath.length >= 3) {
        _emitDrawn(points: List<Offset>.of(_cloudPath));
      } else {
        setState(() => _cloudPath.clear());
      }
      return;
    }
    if (tool == DrawnType.circle && _drawPicks.isNotEmpty) {
      _emitDrawn(points: [_drawPicks.first, aimWorld]);
      return;
    }
    if (tool == DrawnType.dimension && _drawPicks.length == 2) {
      _emitDrawn(points: [_drawPicks[0], _drawPicks[1], aimWorld]);
      return;
    }
    _handleDrawingTap(aimWorld);
  }

  void _handlePointerDown(PointerDownEvent event) {
    // Мышь: средняя кнопка — панорама, правая — завершение текущего
    // рисования; прочие кнопки (4-я, 5-я) ничего не рисуют.
    if (event.kind == PointerDeviceKind.mouse) {
      if (event.buttons & kMiddleMouseButton != 0) {
        _startMiddlePan(event);
        return;
      }
      if (event.buttons & kSecondaryMouseButton != 0) {
        _finishByRightClick();
        return;
      }
      if (event.buttons & kPrimaryMouseButton == 0) return;
    }
    final wasEmpty = _pointerPositions.isEmpty;
    _pointerPositions[event.pointer] = event.localPosition;
    if (wasEmpty) {
      _dragDownScreen = event.localPosition;
      _dragMovedEnough = false;
      _multiPointerGesture = false;
    } else {
      _multiPointerGesture = true;
    }
    if (_selectedObject != null) {
      // Поворот текста за уголок рамки (работает и мышью, и пальцем).
      final rotHandle = _textRotationHandleScreen();
      final base0 = _editedObject ?? _selectedObject;
      if (rotHandle != null &&
          base0 != null &&
          base0.points.isNotEmpty &&
          _pointerPositions.length == 1 &&
          (event.localPosition - rotHandle).distance <= 16) {
        final center = _worldToScreen(base0.points.first);
        _rotStartAngle = math.atan2(
          event.localPosition.dy - center.dy,
          event.localPosition.dx - center.dx,
        );
        _rotStartRotation = base0.rotation;
        _textRotating = true;
        return;
      }
      // Редактирование объекта: один палец — перенос, два — поворот
      // (у текста ещё и масштаб щипком).
      final ids = _pointerPositions.keys.toList();
      final base = _editedObject ?? _selectedObject;
      if (ids.length >= 2) {
        final a = _pointerPositions[ids[0]]!;
        final b = _pointerPositions[ids[1]]!;
        _rotStartAngle = math.atan2(b.dy - a.dy, b.dx - a.dx);
        _rotStartRotation = base!.rotation;
        _pinchStartDist = (a - b).distance;
        _pinchStartHeight = base.height ?? (12 / _screenScale);
      } else {
        _editStartScreen ??= event.localPosition;
        if (base != null && base.points.isNotEmpty) {
          _editStartWorldPos ??= base.points.first;
          _editStartPoints ??= List<Offset>.of(base.points);
        }
      }
      return;
    }
    if (widget.mode == DrawingMode.drawing && _drawTool == DrawnType.cloud) {
      // Облако рисуется сразу от пальца: без удержания, лупы и привязок.
      if (_pointerPositions.length >= 2) {
        _updatePinch();
      } else {
        _startAim(event.localPosition);
      }
      return;
    }
    if (widget.mode == DrawingMode.coordinates) {
      if (_pointerPositions.length >= 2) {
        _startCoordinatePan();
      } else {
        // Первый палец — сразу прицел/захват координаты (без удержания).
        _startAim(event.localPosition);
      }
      return;
    }
    if (_pointerPositions.length >= 2) {
      // Второй палец — жест масштабирования: прицел/привязку не двигаем,
      // иначе вторая точка «прыгает» на место касания второго пальца.
      if (_aiming) _updatePinch();
      return;
    }
    if (_aiming) {
      _updatePinch();
    } else {
      _updateSnap(event.localPosition);
    }
  }

  /// Центроид и максимальная дистанция активных пальцев (для панорамы).
  Offset? _pointerCentroid() {
    if (_pointerPositions.length < 2) return null;
    var sum = Offset.zero;
    for (final p in _pointerPositions.values) {
      sum += p;
    }
    return sum / _pointerPositions.length.toDouble();
  }

  double? _pointerDistance() {
    if (_pointerPositions.length < 2) return null;
    final pts = _pointerPositions.values.toList();
    var d = 0.0;
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        d = math.max(d, (pts[i] - pts[j]).distance);
      }
    }
    return d;
  }

  void _startCoordinatePan() {
    if (_coordPanning) return;
    final c = _pointerCentroid();
    final d = _pointerDistance();
    if (c == null || d == null) return;
    _coordPanning = true;
    _aiming = false;
    _aimScreen = null;
    _aimPointer = null;
    _coordPanStartCentroid = c;
    _coordPanStartDistance = d <= 0 ? 1 : d;
    _coordPanStartMatrix = _transformController.value.clone();
    if (mounted) setState(() {});
  }

  void _updateCoordinatePan() {
    if (!_coordPanning) return;
    final c = _pointerCentroid();
    final d = _pointerDistance();
    final c0 = _coordPanStartCentroid;
    final d0 = _coordPanStartDistance;
    final m0 = _coordPanStartMatrix;
    if (c == null || d == null || c0 == null || d0 == null || m0 == null) {
      return;
    }
    final scale = (d / d0).clamp(0.05, 20.0);
    final zoom = Matrix4.identity()
      ..translateByDouble(c0.dx, c0.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-c0.dx, -c0.dy, 0, 1);
    final pan = Matrix4.translationValues(c.dx - c0.dx, c.dy - c0.dy, 0);
    final next = pan * zoom * m0;
    final s = next.getMaxScaleOnAxis();
    if (s < 1e-6 || s > 1e5) return;
    _transformController.value = next;
  }

  void _endCoordinatePan() {
    if (!_coordPanning) return;
    _coordPanning = false;
    _coordPanStartCentroid = null;
    _coordPanStartDistance = null;
    _coordPanStartMatrix = null;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_middlePanning) {
      _updateMiddlePan(event.localPosition);
      return;
    }
    _pointerPositions[event.pointer] = event.localPosition;
    if (_dragDownScreen != null &&
        (event.localPosition - _dragDownScreen!).distance > 24) {
      _dragMovedEnough = true;
    }
    if (widget.mode == DrawingMode.coordinates) {
      if (_coordPanning) {
        _updateCoordinatePan();
      } else if (_aiming && event.pointer == _aimPointer) {
        _aimScreen = event.localPosition;
        _updateSnap(event.localPosition);
      }
      return;
    }
    if (_selectedObject != null) {
      if (_textRotating) {
        final base = _editedObject ?? _selectedObject!;
        if (base.points.isEmpty) return;
        final center = _worldToScreen(base.points.first);
        final angle = math.atan2(
          event.localPosition.dy - center.dy,
          event.localPosition.dx - center.dx,
        );
        final deltaDeg = _rotStartAngle == null
            ? 0.0
            : (angle - _rotStartAngle!) * 180 / math.pi;
        setState(() {
          _editedObject = base.copyWith(
            rotation: _rotStartRotation - deltaDeg,
          );
          _objectChanged = true;
        });
        return;
      }
      _moveOrRotateObject(event.localPosition);
      return;
    }
    if (_aiming) {
      if (event.pointer == _aimPointer) {
        _aimScreen = event.localPosition;
        // _updateAim (а не только _updateSnap) — он же добавляет точку в путь
        // облака и обновляет превью.
        _updateAim(event.localPosition);
      } else {
        _updatePinch();
      }
    } else if (_pointerPositions.length < 2) {
      // Второй палец (жест масштабирования) привязку не двигает.
      _updateSnap(event.localPosition);
    }
  }

  /// Перемещение (один палец) или поворот/масштаб (два пальца) выбранного
  /// объекта. Текст масштабируется щипком, прямоугольник — только поворот.
  void _moveOrRotateObject(Offset screen) {
    final base = _editedObject ?? _selectedObject;
    if (base == null || base.points.isEmpty) return;
    final ids = _pointerPositions.keys.toList();
    if (ids.length >= 2 && _rotStartAngle != null) {
      final a = _pointerPositions[ids[0]]!;
      final b = _pointerPositions[ids[1]]!;
      final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
      final deltaDeg = (angle - _rotStartAngle!) * 180 / math.pi;
      if (base.type == DrawnType.text) {
        final dist = (a - b).distance;
        final factor = (_pinchStartDist != null && _pinchStartDist! > 0)
            ? dist / _pinchStartDist!
            : 1.0;
        final scale = _screenScale;
        final height = _pinchStartHeight > 0
            ? (_pinchStartHeight * factor).clamp(2 / scale, 20000 / scale)
            : null;
        setState(() {
          _editedObject = base.copyWith(
            rotation: _rotStartRotation - deltaDeg,
            height: height,
          );
          _objectChanged = true;
        });
        return;
      }
      // Прямоугольник: поворот всех углов вокруг центра.
      final startPts = _editStartPoints ?? base.points;
      final center = _centroid(startPts);
      final worldAngle = -deltaDeg * math.pi / 180;
      setState(() {
        _editedObject = base.copyWith(
          points: _rotatePoints(startPts, center, worldAngle),
        );
        _objectChanged = true;
      });
      return;
    }
    final startScreen = _editStartScreen;
    if (startScreen == null) return;
    final scale = _screenScale;
    final dLocal = (screen - startScreen) / scale;
    final dWorld = Offset(dLocal.dx, -dLocal.dy);
    if (base.type == DrawnType.text) {
      final startWorld = _editStartWorldPos;
      if (startWorld == null) return;
      setState(() {
        _editedObject = base.copyWith(points: [startWorld + dWorld]);
        _objectChanged = true;
      });
      return;
    }
    final startPts = _editStartPoints;
    if (startPts == null) return;
    setState(() {
      _editedObject = base.copyWith(
        points: [for (final p in startPts) p + dWorld],
      );
      _objectChanged = true;
    });
  }

  void _handlePointerUp(PointerEvent event) {
    if (_middlePanning &&
        (_middlePanPointer == null || event.pointer == _middlePanPointer)) {
      _endMiddlePan();
      _pointerPositions.remove(event.pointer);
      return;
    }
    if (_selectedObject != null) {
      if (_textRotating) {
        _textRotating = false;
        _rotStartAngle = null;
        _pointerPositions.remove(event.pointer);
        _commitObjectEdit();
        return;
      }
      final wasRotating = _rotStartAngle != null;
      _pointerPositions.remove(event.pointer);
      _pinchDistance = null;
      if (wasRotating) {
        _rotStartAngle = null;
        _pinchStartDist = null;
        _pinchStartHeight = 0;
        _editStartScreen =
            _pointerPositions.isEmpty ? null : _pointerPositions.values.first;
        _editStartWorldPos = _editedObject?.points.first;
        _editStartPoints = _editedObject?.points;
        _commitObjectEdit();
      } else if (_pointerPositions.isEmpty) {
        _editStartScreen = null;
        _editStartWorldPos = null;
        _editStartPoints = null;
        _pinchStartDist = null;
        _pinchStartHeight = 0;
        _commitObjectEdit();
      } else {
        _editStartScreen = _pointerPositions.values.first;
        _editStartWorldPos = _editedObject?.points.first;
        _editStartPoints = _editedObject?.points;
      }
      return;
    }
    if (widget.mode == DrawingMode.coordinates) {
      _pointerPositions.remove(event.pointer);
      _pinchDistance = null;
      _dragDownScreen = null;
      _dragMovedEnough = false;
      _multiPointerGesture = false;
      if (_coordPanning) {
        if (_pointerPositions.length < 2) _endCoordinatePan();
        return;
      }
      if (_aiming && event.pointer == _aimPointer) {
        _commitAim();
      }
      return;
    }
    final wasDrawingSlide = _dragMovedEnough &&
        !_multiPointerGesture &&
        !_aiming &&
        widget.mode == DrawingMode.drawing &&
        _drawAimWorld != null &&
        _isSliderTool(_drawTool);
    _pointerPositions.remove(event.pointer);
    _pinchDistance = null;
    _dragDownScreen = null;
    _dragMovedEnough = false;
    _multiPointerGesture = false;
    if (wasDrawingSlide) {
      // Скольжение одним пальцем ставит точку/радиус/полку (без панорамы).
      _applyDrawingAim(_drawAimWorld);
    } else if (_aiming && event.pointer == _aimPointer) {
      // Рисование, начатое прямо от пальца (облако), завершаем при отпускании
      // именно пальца прицела; второй палец — масштабирование.
      _commitAim();
    }
  }

  /// Инструменты, у которых скольжение одним пальцем ставит точку/фигуру.
  bool _isSliderTool(DrawnType tool) {
    switch (tool) {
      case DrawnType.line:
      case DrawnType.ray:
      case DrawnType.circle:
      case DrawnType.rectangle:
      case DrawnType.dimension:
      case DrawnType.polyline:
        return true;
      case DrawnType.point:
      case DrawnType.cloud:
      case DrawnType.text:
        return false;
    }
  }

  /// Масштабирование двумя пальцами — вокруг точки удержания (прицела).
  /// Работает и когда один палец держит прицел (рисование с лупой), и когда
  /// прицела нет: во втором случае используются два любых пальца.
  void _updatePinch() {
    final aimId = _aimPointer;
    final aimPos = aimId == null ? null : _pointerPositions[aimId];
    final extras = _pointerPositions.entries
        .where((e) => e.key != aimId)
        .map((e) => e.value)
        .toList();
    final Offset a;
    final Offset b;
    if (aimPos != null && extras.isNotEmpty) {
      // Палец прицела + второй палец — это и есть «два пальца» при рисовании.
      a = aimPos;
      b = extras.first;
    } else if (extras.length >= 2) {
      a = extras[0];
      b = extras[1];
    } else {
      _pinchDistance = null;
      return;
    }
    final distance = (a - b).distance;
    if (distance <= 0) return;
    final previous = _pinchDistance;
    _pinchDistance = distance;
    if (previous == null || previous <= 0) return;
    final factor = distance / previous;
    if (!factor.isFinite || factor <= 0 || (factor - 1).abs() < 1e-4) return;
    _zoomAround(_aimScreen ?? extras[0], factor);
  }

  /// Масштабирование относительно экранной точки (центр — палец удержания).
  void _zoomAround(Offset anchor, double factor) {
    final transform = Matrix4.identity()
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);
    final next = transform.multiplied(_transformController.value);
    final scale = next.getMaxScaleOnAxis();
    if (scale < 1e-6 || scale > 1e5) return;
    _transformController.value = next;
  }

  void _zoomAt(Offset screenPoint, double factor) {
    final zoom = Matrix4.identity()
      ..translateByDouble(screenPoint.dx, screenPoint.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-screenPoint.dx, -screenPoint.dy, 0, 1);
    _transformController.value = zoom.multiplied(_transformController.value);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        // Системная панель навигации (Android 15 edge-to-edge) — нижние
        // элементы поднимаем над ней, чтобы она их не перекрывала.
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        final isFirstLayout = _viewport == null;
        if (_fitPending || isFirstLayout) {
          _fitPending = false;
          _viewport = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitToScreen(viewport);
          });
        } else if (_viewport != viewport) {
          // Клавиатура/поворот экрана: масштаб и положение сохраняем.
          _viewport = viewport;
        }

        final doc = widget.document;
        final boxSize = Size(_boxWidth, _boxHeight);
        final rawScale = _transformController.value.getMaxScaleOnAxis();
        final scale = rawScale <= 0 ? 1.0 : rawScale;
        final rayClip = _visibleLocalRect(viewport, scale);
        final clusters = _clusterer.clusterize(
          annotations: widget.annotations,
          document: doc,
          matrix: _transformController.value,
          minDistancePx: 32.0,
        );
        final displayedSnap =
            _aiming ? _snapPreview : (_snapPreview ?? _lastSnap);

        // Уголок-ручка для поворота выбранного текста (мышью удобнее, чем
        // двумя пальцами).
        final rotHandle = _textRotationHandleScreen();

        return SizedBox(
          width: viewport.width,
          height: viewport.height,
          child: Stack(
            children: [
              // Тёмный холст — как в AutoCAD: цвет ACI 7 (белый) виден,
              // а цвета примитивов соответствуют чертежу.
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFF212830)),
              ),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerHover: (event) => _updateSnap(event.localPosition),
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerUp,
                  child: GestureDetector(
                    onTapUp: (details) => _handleTap(details.localPosition),
                    onLongPressStart: (details) =>
                        _startAim(details.localPosition),
                    onLongPressMoveUpdate: (details) =>
                        _updateAim(details.localPosition),
                    // Завершение — только в _handlePointerUp по пальцу прицела:
                    // onLongPressEnd срабатывает и при втором пальце (зуме).
                    child: InteractiveViewer(
                      panEnabled: !_aiming &&
                          _selectedObject == null &&
                          widget.mode != DrawingMode.drawing &&
                          widget.mode != DrawingMode.coordinates,
                      scaleEnabled: !_aiming &&
                          _selectedObject == null &&
                          widget.mode != DrawingMode.coordinates,
                      transformationController: _transformController,
                      // Чертеж больше экрана, поэтому не ограничиваем дочерний размер.
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      minScale: 0.000001,
                      maxScale: 100000,
                      child: Stack(
                        children: [
                          CustomPaint(
                            painter: DxfCanvasPainter(
                              document: doc,
                              hiddenLayers: widget.hiddenLayers,
                              cacheManager: _cacheManager,
                              scale: scale,
                            ),
                            size: boxSize,
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: MeasurementPainter(
                                points: List<Offset>.of(_measurementPoints),
                                scale: scale,
                                closed: _measurementClosed,
                                previewPoint: _previewLocal,
                              ),
                              size: boxSize,
                            ),
                          ),
                          // Нарисованные пользователем объекты (всегда, во всех
                          // режимах — они «остаются на чертеже»).
                          IgnorePointer(
                            child: CustomPaint(
                              painter: DrawnObjectsPainter(
                                objects: _visibleDrawnObjects,
                                minX: doc.minX,
                                maxY: doc.maxY,
                                scale: scale,
                                extent: math.sqrt(_boxWidth * _boxWidth +
                                    _boxHeight * _boxHeight),
                                rayClip: rayClip,
                                selectedId: _selectedObject?.id,
                                edited: _editedObject,
                              ),
                              size: boxSize,
                            ),
                          ),
                          // Живое превью незавершённого рисования.
                          IgnorePointer(
                            child: CustomPaint(
                              painter: DrawingPreviewPainter(
                                tool: _drawTool,
                                picks: List<Offset>.of(_drawPicks),
                                aim: widget.mode == DrawingMode.drawing
                                    ? _drawAimWorld
                                    : null,
                                cloudPath: List<Offset>.of(_cloudPath),
                                minX: doc.minX,
                                maxY: doc.maxY,
                                scale: scale,
                                color: Color(_drawColor),
                                strokePx: _drawStrokePx,
                                rayClip: rayClip,
                              ),
                              size: boxSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Точки и текст — экранные оверлеи (не масштабируются картинкой,
              // поэтому текст не пикселит, а точки не пропадают при зуме).
              IgnorePointer(
                child: CustomPaint(
                  painter: DxfPointPainter(
                    overlays: _overlays,
                    matrix: _transformController.value,
                    minX: doc.minX,
                    maxY: doc.maxY,
                    hiddenLayers: widget.hiddenLayers,
                  ),
                  size: viewport,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: DxfTextPainter(
                    overlays: _overlays,
                    matrix: _transformController.value,
                    minX: doc.minX,
                    maxY: doc.maxY,
                    hiddenLayers: widget.hiddenLayers,
                  ),
                  size: viewport,
                ),
              ),
              // Тексты нарисованных объектов (текст и подпись размера).
              if (widget.drawnObjects.isNotEmpty)
                IgnorePointer(
                  child: CustomPaint(
                    painter: DrawnTextsPainter(
                      objects: _visibleDrawnObjects,
                      matrix: _transformController.value,
                      minX: doc.minX,
                      maxY: doc.maxY,
                      units: widget.units,
                      scale: scale,
                      selectedId: _selectedObject?.id,
                      edited: _editedObject,
                    ),
                    size: viewport,
                  ),
                ),
              // Ручка поворота выбранного текста (перетаскивание за уголок).
              if (rotHandle != null)
                Positioned(
                  left: rotHandle.dx - 11,
                  top: rotHandle.dy - 11,
                  child: IgnorePointer(
                    child: Container(
                      key: const Key('text-rotate-handle'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.rotate_right,
                          size: 13, color: Colors.black87),
                    ),
                  ),
                ),
              // Точки текущего незавершённого инструмента рисования.              if (widget.mode == DrawingMode.drawing && _drawPicks.isNotEmpty)
              IgnorePointer(
                child: CustomPaint(
                  painter: DrawingPicksPainter(
                    points: List<Offset>.of(_drawPicks),
                    matrix: _transformController.value,
                    minX: doc.minX,
                    maxY: doc.maxY,
                    color: Color(_drawColor),
                  ),
                  size: viewport,
                ),
              ),
              // Маркеры рисуются в экранных координатах поверх вьюера,
              // чтобы не масштабироваться вместе с чертежом.
              IgnorePointer(
                child: CustomPaint(
                  painter: ClusteredMarkerPainter(clusters: clusters),
                  size: viewport,
                ),
              ),
              // Подписи длин — в экранных координатах: при сильном зуме
              // шрифт остаётся чётким и не пропадает.
              if (widget.mode == DrawingMode.measurement &&
                  _measurementPoints.isNotEmpty)
                IgnorePointer(
                  child: ClipRect(
                    child: CustomPaint(
                      painter: MeasurementLabelsPainter(
                        points: List<Offset>.of(_measurementPoints),
                        matrix: _transformController.value,
                        units: widget.units,
                        closed: _measurementClosed,
                      ),
                      size: viewport,
                    ),
                  ),
                ),
              if ((widget.mode == DrawingMode.measurement ||
                      widget.mode == DrawingMode.drawing ||
                      widget.mode == DrawingMode.coordinates ||
                      widget.mode == DrawingMode.annotation) &&
                  (_snapSettings.enabled ||
                      widget.mode == DrawingMode.coordinates) &&
                  displayedSnap != null)
                IgnorePointer(
                  child: CustomPaint(
                    painter: SnapMarkerPainter(
                      result: displayedSnap,
                      matrix: _transformController.value,
                      minX: doc.minX,
                      maxY: doc.maxY,
                    ),
                    size: viewport,
                  ),
                ),
              if (widget.mode == DrawingMode.drawing &&
                  _draftingApplies(_drawTool) &&
                  _drawPicks.isNotEmpty &&
                  _drawAimWorld != null &&
                  widget.snapSettings.polarStep != null)
                _buildAngleBadge(viewport),
              if (_aiming &&
                  _aimScreen != null &&
                  !(widget.mode == DrawingMode.drawing &&
                      _drawTool == DrawnType.cloud))
                _buildLoupe(viewport, scale),
              if (widget.mode == DrawingMode.measurement)
                Positioned(
                  bottom: 80 + bottomInset,
                  left: 16,
                  right: 16,
                  child: _buildMeasurementControls(),
                ),
              if (widget.mode == DrawingMode.drawing)
                Positioned(
                  bottom: 80 + bottomInset,
                  left: 16,
                  right: 16,
                  child: _buildDrawingControls(),
                ),
              if (widget.mode == DrawingMode.coordinates)
                Positioned(
                  bottom: 80 + bottomInset,
                  left: 16,
                  right: 16,
                  child: _buildCoordinateControls(),
                ),
              if (widget.mode == DrawingMode.overview &&
                  _selectedObject != null)
                Positioned(
                  bottom: 80 + bottomInset,
                  left: 16,
                  right: 16,
                  child: _buildSelectedObjectPanel(),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Бейдж угла, отложенного от предыдущего звена (у вершины угла).
  Widget _buildAngleBadge(Size viewport) {
    final aim = _drawAimWorld;
    if (aim == null || _drawPicks.isEmpty) return const SizedBox.shrink();
    final from = _drawPicks.last;
    final d = aim - from;
    if (d.distance < 1e-9) return const SizedBox.shrink();
    // Угол между предыдущим звеном и новым направлением (не от горизонтали).
    var deg = math.atan2(d.dy, d.dx) * 180 / math.pi;
    if (_drawPicks.length >= 2) {
      final prev = _drawPicks[_drawPicks.length - 2];
      final seg = from - prev;
      if (seg.distance > 1e-9) {
        deg -= math.atan2(seg.dy, seg.dx) * 180 / math.pi;
      }
    }
    deg = ((deg + 180) % 360 + 360) % 360 - 180;
    deg = deg.abs();
    // Бейдж — у вершины откладываемого угла (последняя точка), а не у пальца.
    final p = _localToScreen(_dxfToLocal(from));
    const w = 62.0, h = 26.0;
    final left = (p.dx + 14).clamp(4.0, viewport.width - w - 4);
    var top = p.dy - h - 14;
    if (top < 4) top = p.dy + 14;
    top = top.clamp(4.0, viewport.height - h - 4);
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '${deg.toStringAsFixed(1)}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Лупа у пальца: увеличенная область вокруг точки привязки.
  Widget _buildLoupe(Size viewport, double scale) {
    final aim = _aimScreen!;
    const loupeSize = 124.0;
    const gap = 28.0;
    var left = aim.dx + gap;
    var top = aim.dy - loupeSize - gap;
    if (left + loupeSize > viewport.width - 8) {
      left = aim.dx - loupeSize - gap;
    }
    if (top < 8) top = aim.dy + gap;
    left = left.clamp(8.0, viewport.width - loupeSize - 8);
    top = top.clamp(8.0, viewport.height - loupeSize - 8);
    final snap = _snapPreview;
    final aimLocal =
        snap != null ? _dxfToLocal(snap.point) : _screenToLocal(aim);
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: SnapLoupe(
          cacheManager: _cacheManager,
          hiddenLayers: widget.hiddenLayers,
          aimLocal: aimLocal,
          snap: snap,
          mainScale: scale,
          measurementPoints: widget.mode == DrawingMode.drawing
              ? List<Offset>.of(_drawPicks)
              : List<Offset>.of(_measurementPoints),
          closed: _measurementClosed,
          drawnObjects: _visibleDrawnObjects,
          minX: widget.document.minX,
          maxY: widget.document.maxY,
          extent: math.sqrt(_boxWidth * _boxWidth + _boxHeight * _boxHeight),
          units: widget.units,
          overlays: _overlays,
          annotations: widget.annotations,
          document: widget.document,
        ),
      ),
    );
  }

  /// Карточка режима «Координаты»: тип привязки, источник, X/Y и действия.
  Widget _buildCoordinateControls() {
    // Во время прицеливания показываем «живые» координаты, после отпускания —
    // зафиксированные. Если привязки нет — показываем координаты точки под
    // пальцем (пустое место чертежа): их тоже нужно уметь снять.
    final display = _aiming ? _snapPreview : _coordinateResult;
    final aimWorld = _aiming && _aimScreen != null
        ? _localToDxf(_screenToLocal(_aimScreen!))
        : null;
    final point = display?.point ?? (_aiming ? aimWorld : _coordRawPoint);
    final hasPoint = point != null;
    final has = _coordinateResult != null || _coordRawPoint != null;
    // H берём из самого объекта: нарисованные объекты лежат в плоскости Z=0,
    // у объектов чертежа — своя отметка (группа 30/38).
    double? elevation;
    if (point != null) {
      elevation = display?.source == SnapSource.drawn
          ? 0.0
          : elevationAtPoint(
              widget.document,
              point,
              hiddenLayers: widget.hiddenLayers,
            );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Координаты',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              if (display != null) ...[
                SnapGlyph(type: display.type, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${display.type.label} · ${display.source.label}',
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else if (hasPoint)
                const Expanded(
                  child: Text(
                    'Без привязки',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                )
              else
                const Expanded(
                  child: Text(
                    'Коснитесь узла или пересечения',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              IconButton(
                key: const Key('coord-clear'),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Сброс',
                visualDensity: VisualDensity.compact,
                onPressed: has ? () => _captureCoordinate(null) : null,
              ),
            ],
          ),
          Row(
            children: [
              _coordinateValue('X', point?.dx),
              const SizedBox(width: 12),
              _coordinateValue('Y', point?.dy),
            ],
          ),
          // H — высота объекта, к которому относится точка (Z из чертежа;
          // для нарисованных объектов — 0, для пустого места — «—»).
          Row(
            key: const Key('coord-h-row'),
            children: [
              _coordinateValue(
                'H',
                elevation,
                fontSize: 14,
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                key: const Key('coord-copy'),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Копировать X,Y',
                    style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: has ? _copyCoordinate : null,
              ),
              TextButton.icon(
                key: const Key('coord-create-point'),
                icon: const Icon(Icons.add_location_alt, size: 16),
                label: const Text('+ Точка', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: (has && widget.onCreatePointAt != null)
                    ? () {
                        final p = _coordinateEffectivePoint;
                        if (p != null) widget.onCreatePointAt!(p.dx, p.dy);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coordinateValue(String axis, double? v, {double fontSize = 18}) {
    return Expanded(
      child: Row(
        children: [
          Text(axis,
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  v == null
                      ? '—'
                      : '${formatCoordinate(v)} ${unitsLabel(widget.units)}',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Панель инструментов рисования: инструменты, 5 толщин, палитра цветов.
  Widget _buildDrawingControls() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ReorderableListView(
              key: const Key('draw-tools'),
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final moved = _drawToolOrder.removeAt(oldIndex);
                  _drawToolOrder.insert(newIndex, moved);
                });
                unawaited(AppPrefs.instance.setDrawToolOrder(
                    [for (final t in _drawToolOrder) t.name]));
              },
              children: [
                for (var i = 0; i < _drawToolOrder.length; i++)
                  ReorderableDelayedDragStartListener(
                    key: ValueKey('draw-tool-order-${_drawToolOrder[i].name}'),
                    index: i,
                    child: _drawToolChip(_drawToolOrder[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Толщины — отдельная строка (чтобы не листать общую ленту).
          SizedBox(
            height: 32,
            child: SingleChildScrollView(
              key: const Key('draw-strokes'),
              controller: _drawSettingsScroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final width in kDrawnStrokeOptions)
                    _drawStrokeChip(width),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Цвета — отдельная строка.
          SizedBox(
            height: 32,
            child: SingleChildScrollView(
              key: const Key('draw-colors'),
              controller: _drawColorsScroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final color in kDrawnColorOptions) _drawColorDot(color),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _drawHint,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_drawTool == DrawnType.polyline ||
                  _drawTool == DrawnType.cloud)
                TextButton(
                  key: const Key('draw-finish'),
                  onPressed: (_drawTool == DrawnType.polyline
                          ? _drawPicks.length >= 2
                          : _drawPicks.length >= 3)
                      ? _finishDrawing
                      : null,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 30),
                  ),
                  child:
                      const Text('Завершить', style: TextStyle(fontSize: 11)),
                ),
              TextButton(
                key: const Key('draw-cancel'),
                onPressed: _drawPicks.isEmpty ? null : _cancelDrawingPicks,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text('Отменить', style: TextStyle(fontSize: 11)),
              ),
              IconButton(
                key: const Key('draw-undo'),
                icon: const Icon(Icons.undo, size: 18),
                tooltip: 'Удалить последний',
                visualDensity: VisualDensity.compact,
                onPressed: (widget.drawnObjects.isNotEmpty &&
                        widget.onUndoLastDrawn != null)
                    ? widget.onUndoLastDrawn
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawToolChip(DrawnType tool) {
    final selected = tool == _drawTool;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        key: Key('draw-tool-${tool.name}'),
        onTap: () => _selectDrawTool(tool),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.withValues(alpha: 0.12) : null,
            border: Border.all(
              color: selected ? Colors.blue : Colors.grey[300]!,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _drawToolIcon(tool),
                size: 16,
                color: selected ? Colors.blue[700] : Colors.black87,
              ),
              const SizedBox(width: 4),
              Text(
                tool.label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.blue[700] : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawStrokeChip(double width) {
    final selected = (width - _drawStrokePx).abs() < 0.01;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        key: Key('draw-stroke-$width'),
        onTap: () => setState(() => _drawStrokePx = width),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 34,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.blue : Colors.grey[300]!,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Container(
              width: 22,
              height: width,
              color: Color(_drawColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawColorDot(int color) {
    final selected = color == _drawColor;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: InkWell(
        key: Key('draw-color-$color'),
        onTap: () => setState(() => _drawColor = color),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Color(color),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.blue : Colors.grey[400]!,
              width: selected ? 2.5 : 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textHeightChip(
    double px,
    double selectedPx,
    ValueChanged<double> onTap,
  ) {
    final selected = (px - selectedPx).abs() < 0.01;
    return InkWell(
      key: Key('text-height-$px'),
      onTap: () => onTap(px),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 34,
        height: 30,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey[300]!,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            'A',
            style: TextStyle(
              fontSize: (px * 0.7).clamp(9.0, 18.0),
              fontWeight: FontWeight.bold,
              color: selected ? Colors.blue : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  IconData _drawToolIcon(DrawnType tool) {
    switch (tool) {
      case DrawnType.point:
        return Icons.radio_button_checked;
      case DrawnType.polyline:
        return Icons.polyline;
      case DrawnType.line:
        return Icons.horizontal_rule;
      case DrawnType.ray:
        return Icons.arrow_right_alt;
      case DrawnType.circle:
        return Icons.circle_outlined;
      case DrawnType.rectangle:
        return Icons.crop_square;
      case DrawnType.cloud:
        return Icons.cloud_queue;
      case DrawnType.text:
        return Icons.text_fields;
      case DrawnType.dimension:
        return Icons.straighten;
    }
  }

  Widget _buildMeasurementControls() {
    final doc = widget.document;
    final isClosed = _measurementClosed && _measurementPoints.length >= 3;
    final temp = PolygonMeasurement(
      id: '',
      drawingId: widget.drawingId,
      createdAt: DateTime.now(),
      points: _measurementPoints,
      closed: isClosed,
    );
    final lengthText = formatLength(temp.getPathLength(), widget.units);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isClosed
                      ? Colors.cyanAccent.withValues(alpha: 0.25)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isClosed ? 'Контур замкнут' : 'Контур открыт',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isClosed ? Colors.teal[800] : Colors.orange[900],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _measurementPoints.isEmpty
                      ? 'Коснитесь чертежа'
                      : (_measurementPoints.length >= 2
                          ? 'Точек: ${_measurementPoints.length} · Длина: $lengthText'
                          : 'Точек: ${_measurementPoints.length}'),
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_lastSnap != null) ...[
            const SizedBox(height: 2),
            Text(
              'Привязка: ${_lastSnap!.type.label}',
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
          if (isClosed) ...[
            const SizedBox(height: 4),
            Text(
              'Периметр: ${formatLength(temp.getPerimeter(), widget.units)} · '
              'Площадь: ${formatArea(temp.getArea(), widget.units)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text(
                    'Отменить',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _measurementPoints.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _measurementPoints.removeLast();
                            if (_measurementPoints.length < 3) {
                              _measurementClosed = false;
                            }
                          });
                        },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    isClosed ? Icons.lock_open : Icons.lock,
                    size: 16,
                  ),
                  label: Text(
                    isClosed ? 'Разомкнуть' : 'Замкнуть',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _measurementPoints.length >= 3
                      ? () => setState(
                          () => _measurementClosed = !_measurementClosed)
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text(
                    'Завершить',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _measurementPoints.length >= 2
                      ? () => _finishMeasurement(doc)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Диалог слоёв: DXF-слои и слои нарисованных объектов.
  void _finishMeasurement(DxfDocument doc) {
    if (_measurementPoints.length < 2) return;
    // Локальные точки -> абсолютные координаты DXF для модели.
    final absPoints = _measurementPoints
        .map((p) => Offset(p.dx + doc.minX, doc.maxY - p.dy))
        .toList();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final Measurement measurement = absPoints.length == 2
        ? DistanceMeasurement(
            id: id,
            drawingId: widget.drawingId,
            createdAt: DateTime.now(),
            point1: absPoints[0],
            point2: absPoints[1],
          )
        : PolygonMeasurement(
            id: id,
            drawingId: widget.drawingId,
            createdAt: DateTime.now(),
            points: List<Offset>.from(absPoints),
            closed: _measurementClosed && absPoints.length >= 3,
          );
    widget.onMeasurementFinished?.call(measurement);
    _lastSnapTimer?.cancel();
    setState(() {
      _measurementPoints.clear();
      _measurementClosed = false;
      _snapPreview = null;
      _lastSnap = null;
      _aiming = false;
      _aimScreen = null;
    });
  }
}

/// Диалог редактирования текста нарисованного объекта.
class _TextEditDialog extends StatefulWidget {
  final String initial;
  const _TextEditDialog({required this.initial});
  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Изменить текст'),
      content: TextField(
        key: const Key('edit-text-field'),
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Текст'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
