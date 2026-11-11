import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/photo_annotation.dart';
import '../widgets/photo_annotation_painter.dart';

/// Редактор рисования поверх фотографии: карандаш, линия, прямоугольник,
/// круг, стрелка и текст, с отменой и удалением отдельных объектов.
///
/// Возвращает [PhotoEditResult] (замена оригинала или новое фото) либо null.
class PhotoAnnotatorScreen extends StatefulWidget {
  const PhotoAnnotatorScreen({
    super.key,
    required this.imagePath,
    this.debugImage,
    this.debugImageSize,
  });

  final String imagePath;

  /// Заранее декодированное изображение — только для тестов, чтобы не зависеть
  /// от асинхронного декодера в тестовом окружении.
  final ui.Image? debugImage;

  /// Размер изображения без декодирования — только для тестов.
  final Size? debugImageSize;

  @override
  State<PhotoAnnotatorScreen> createState() => _PhotoAnnotatorScreenState();
}

class _PhotoAnnotatorScreenState extends State<PhotoAnnotatorScreen> {
  static const List<Color> _colors = [
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFFFDD835),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];
  static const List<double> _widths = [3, 7, 13];
  static const double _textSize = 44;

  ui.Image? _image;
  Size _imageSize = Size.zero;
  final List<PhotoShape> _shapes = [];
  PhotoShape? _current;
  PhotoTool _tool = PhotoTool.pencil;
  Color _color = _colors.first;
  double _strokeWidth = _widths[1];
  bool _eraseMode = false;
  bool _saving = false;
  bool _loadingError = false;

  @override
  void initState() {
    super.initState();
    final debug = widget.debugImage;
    if (debug != null) {
      _image = debug;
      _imageSize = Size(debug.width.toDouble(), debug.height.toDouble());
    } else if (widget.debugImageSize != null) {
      _imageSize = widget.debugImageSize!;
    } else {
      _loadImage();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image = frame.image;
        _imageSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _loadingError = true);
    }
  }

  Offset _normalize(Offset local, Size viewSize) => Offset(
        (local.dx / viewSize.width).clamp(0.0, 1.0),
        (local.dy / viewSize.height).clamp(0.0, 1.0),
      );

  void _startShape(DragStartDetails details, Size viewSize) {
    if (_eraseMode || _tool == PhotoTool.text) return;
    setState(() {
      _current = PhotoShape(
        tool: _tool,
        points: [_normalize(details.localPosition, viewSize)],
        color: _color,
        strokeWidth: _strokeWidth,
        textSize: _textSize,
      );
    });
  }

  void _updateShape(DragUpdateDetails details, Size viewSize) {
    final current = _current;
    if (current == null) return;
    final point = _normalize(details.localPosition, viewSize);
    setState(() {
      if (current.tool == PhotoTool.pencil) {
        _current = current.copyWith(points: [...current.points, point]);
      } else {
        _current = current.copyWith(points: [current.points.first, point]);
      }
    });
  }

  void _finishShape(Size viewSize) {
    final current = _current;
    if (current == null) return;
    setState(() {
      _current = null;
      if (_isLongEnough(current)) _shapes.add(current);
    });
  }

  bool _isLongEnough(PhotoShape shape) {
    if (shape.tool == PhotoTool.pencil) return shape.points.length > 1;
    if (shape.points.length < 2) return false;
    final a = shape.points.first;
    final b = shape.points.last;
    final dx = (a.dx - b.dx) * _imageSize.width;
    final dy = (a.dy - b.dy) * _imageSize.height;
    return math.sqrt(dx * dx + dy * dy) > 8;
  }

  Future<void> _onTap(TapUpDetails details, Size viewSize) async {
    final point = _normalize(details.localPosition, viewSize);
    if (_eraseMode) {
      final index = _hitShapeIndex(point);
      if (index != null) setState(() => _shapes.removeAt(index));
      return;
    }
    if (_tool != PhotoTool.text) return;
    final text = await _askText();
    if (text == null || !mounted) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _shapes.add(PhotoShape(
        tool: PhotoTool.text,
        points: [point],
        color: _color,
        strokeWidth: _strokeWidth,
        text: trimmed,
        textSize: _textSize,
      ));
    });
  }

  int? _hitShapeIndex(Offset point) {
    // Допуск для пальца: ~3 % от короткой стороны фото (у 2048 px это ~46 px
    // изображения ≈ 25 px на экране) — иначе попасть по тонкой линии сложно.
    final tolerance = math.max(
      _imageSize.shortestSide * 0.03,
      _strokeWidth * 2,
    );
    for (var i = _shapes.length - 1; i >= 0; i--) {
      if (_shapes[i].hitTest(point, _imageSize, tolerancePx: tolerance)) {
        return i;
      }
    }
    return null;
  }

  Future<String?> _askText() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _PhotoTextDialog(),
    );
  }

  void _undo() {
    if (_shapes.isEmpty) return;
    setState(() => _shapes.removeLast());
  }

  Future<void> _clear() async {
    if (_shapes.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить рисунок?'),
        content: const Text('Будут удалены все нарисованные объекты.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Очистить')),
        ],
      ),
    );
    if (confirm == true) setState(_shapes.clear);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_shapes.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Сохранить рисунок'),
        children: [
          SimpleDialogOption(
            key: const Key('photo-save-replace'),
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: const ListTile(
              leading: Icon(Icons.save),
              title: Text('Заменить фото'),
              subtitle: Text('рисунок останется на месте'),
            ),
          ),
          SimpleDialogOption(
            key: const Key('photo-save-copy'),
            onPressed: () => Navigator.pop(ctx, 'copy'),
            child: const ListTile(
              leading: Icon(Icons.copy),
              title: Text('Сохранить как новое фото'),
              subtitle: Text('оригинал останется без изменений'),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final bytes = await _composePng();
      if (bytes == null) throw StateError('не удалось подготовить изображение');
      if (choice == 'replace') {
        await File(widget.imagePath).writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        Navigator.pop(context, PhotoEditResult.replaced(widget.imagePath));
      } else {
        final dir = await getTemporaryDirectory();
        final name = 'annotated_${DateTime.now().millisecondsSinceEpoch}.png';
        final path = p.join(dir.path, name);
        await File(path).writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        Navigator.pop(context, PhotoEditResult.added(path));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Не удалось сохранить рисунок: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  /// Сводит фото и нарисованные объекты в один PNG в полном разрешении.
  Future<List<int>?> _composePng() async {
    final image = _image;
    if (image == null) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    PhotoAnnotationPainter(shapes: List.of(_shapes), imageSize: _imageSize)
        .paint(canvas, _imageSize);
    final picture = recorder.endRecording();
    final composed = await picture.toImage(image.width, image.height);
    final data = await composed.toByteData(format: ui.ImageByteFormat.png);
    composed.dispose();
    picture.dispose();
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Рисование', style: TextStyle(fontSize: 18)),
        leading: IconButton(
          key: const Key('photo-annotator-close'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            key: const Key('photo-undo'),
            tooltip: 'Отменить',
            icon: const Icon(Icons.undo),
            onPressed: _shapes.isEmpty ? null : _undo,
          ),
          IconButton(
            key: const Key('photo-clear'),
            tooltip: 'Очистить',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _shapes.isEmpty ? null : _clear,
          ),
          IconButton(
            key: const Key('photo-save'),
            tooltip: 'Сохранить',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loadingError) {
      return const Center(
        child: Text('Не удалось открыть фото',
            style: TextStyle(color: Colors.white70)),
      );
    }
    final image = _image;
    if (_imageSize.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.biggest;
              final fitted = applyBoxFit(BoxFit.contain, _imageSize, available);
              final rect = Alignment.center
                  .inscribe(fitted.destination, Offset.zero & available);
              final viewSize = rect.size;
              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: rect,
                    child: image != null
                        ? RawImage(image: image, fit: BoxFit.fill)
                        : const ColoredBox(color: Color(0xFF37474F)),
                  ),
                  Positioned.fromRect(
                    rect: rect,
                    child: GestureDetector(
                      key: const Key('photo-annotator-canvas'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _startShape(d, viewSize),
                      onPanUpdate: (d) => _updateShape(d, viewSize),
                      onPanEnd: (_) => _finishShape(viewSize),
                      onTapUp: (d) => _onTap(d, viewSize),
                      child: CustomPaint(
                        painter: PhotoAnnotationPainter(
                          shapes: [
                            ..._shapes,
                            if (_current != null) _current!,
                          ],
                          imageSize: _imageSize,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _buildTools(),
      ],
    );
  }

  Widget _buildTools() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _toolChip(PhotoTool.pencil, Icons.edit, 'Карандаш'),
                _toolChip(PhotoTool.line, Icons.remove, 'Линия'),
                _toolChip(PhotoTool.rect, Icons.crop_square, 'Прямоугольник'),
                _toolChip(PhotoTool.circle, Icons.circle_outlined, 'Круг'),
                _toolChip(PhotoTool.arrow, Icons.arrow_forward, 'Стрелка'),
                _toolChip(PhotoTool.text, Icons.title, 'Текст'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final color in _colors)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    key: Key('photo-color-${_colors.indexOf(color)}'),
                    onTap: () => setState(() {
                      _color = color;
                      _eraseMode = false;
                    }),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == color && !_eraseMode
                              ? Colors.blue
                              : Colors.black26,
                          width: _color == color && !_eraseMode ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              for (var i = 0; i < _widths.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    key: Key('photo-width-$i'),
                    onTap: () => setState(() {
                      _strokeWidth = _widths[i];
                      _eraseMode = false;
                    }),
                    child: Container(
                      width: 34,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _strokeWidth == _widths[i]
                            ? Colors.blue.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _strokeWidth == _widths[i]
                              ? Colors.blue
                              : Colors.black26,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 18,
                          height: _widths[i] / 2 + 1,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('photo-erase-toggle'),
                  onPressed: () => setState(() => _eraseMode = !_eraseMode),
                  icon: Icon(_eraseMode ? Icons.auto_fix_high : Icons.healing,
                      size: 18),
                  label: Text(_eraseMode ? 'Ластик включён' : 'Ластик'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _eraseMode ? Colors.white : Colors.black87,
                    backgroundColor:
                        _eraseMode ? Colors.redAccent : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('photo-undo-bottom'),
                  onPressed: _shapes.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text('Отменить (${_shapes.length})'),
                ),
              ),
            ],
          ),
          if (_eraseMode)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Нажмите на нарисованный объект, чтобы удалить его',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolChip(PhotoTool tool, IconData icon, String label) {
    final selected = _tool == tool && !_eraseMode;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        key: Key('photo-tool-${tool.name}'),
        onTap: () => setState(() {
          _tool = tool;
          _eraseMode = false;
        }),
        child: Container(
          width: 104,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:
                selected ? Colors.blue.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Colors.blue : Colors.black26,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20, color: selected ? Colors.blue : Colors.black87),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.blue : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Диалог ввода текста. Владеет своим контроллером, чтобы он не был
/// освобождён, пока маршрут диалога ещё проигрывает анимацию закрытия.
class _PhotoTextDialog extends StatefulWidget {
  const _PhotoTextDialog();

  @override
  State<_PhotoTextDialog> createState() => _PhotoTextDialogState();
}

class _PhotoTextDialogState extends State<_PhotoTextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Текст на фото'),
      content: TextField(
        key: const Key('photo-text-field'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Например: люк'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        TextButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Добавить')),
      ],
    );
  }
}
