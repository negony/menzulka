import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../exporters/dxf_exporter.dart';
import '../models/annotation.dart';
import '../models/drawn_object.dart';
import '../models/dxf_models.dart';
import '../models/measurement.dart';
import '../models/snap_models.dart';
import '../services/cad_conversion_exception.dart';
import '../services/cad_export_version.dart';
import '../services/cad_converter.dart';
import '../services/cad_format.dart';
import '../services/database.dart';
import '../services/dxf_parser.dart';
import '../services/file_share.dart';
import '../services/project_bundle.dart';
import '../services/project_version_service.dart';
import '../utils/empty_dxf.dart';
import '../widgets/about_dialog.dart';
import '../widgets/cad_error_dialog.dart';
import '../widgets/drawing_toolbar.dart';
import '../widgets/dxf_viewer.dart';
import '../widgets/layers_sheet.dart';
import '../widgets/workspace_dock.dart';
import 'annotations_list_screen.dart';
import 'annotation_detail_screen.dart';
import 'create_annotation_sheet.dart';
import 'measurements_history_screen.dart';
import 'project_history_screen.dart';

enum DrawingMode { overview, coordinates, annotation, measurement, drawing }

class DrawingScreen extends StatefulWidget {
  final String? drawingId;

  const DrawingScreen({super.key, this.drawingId});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final _db = DatabaseService.instance;
  final _bundle = ProjectBundle();
  DxfDocument? _document;
  List<Annotation> _annotations = [];
  List<DrawnObject> _drawnObjects = [];
  Set<String> _hiddenLayers = {};
  final Set<String> _hiddenDrawnLayers = {};
  String _activeDrawnLayer = kDefaultDrawnLayer;
  final List<String> _drawnLayers = [kDefaultDrawnLayer];
  DrawingMode _mode = DrawingMode.overview;
  final SnapSettings _snapSettings = SnapSettings();
  String _units = 'm';
  String? _currentFileName;
  String? _drawingId;
  bool _isLoading = false;
  String _loadingMessage = 'Загрузка и парсинг DXF...';
  int _viewerEpoch = 0;
  List<({String id, String name, String path, String units})> _recent = [];

  /// Открыт ли лист создания точки (защита от двойного открытия).
  bool _annotationSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _loadRecentDrawings();
    if (widget.drawingId != null) {
      _loadExistingDrawing();
    }
  }

  int get _nextAnnotationNumber => _annotations.isEmpty
      ? 1
      : _annotations.map((a) => a.number).reduce((a, b) => a > b ? a : b) + 1;

  Future<void> _loadExistingDrawing() async {
    final drawing = await _db.getDrawingById(widget.drawingId!);
    if (drawing == null) return;
    try {
      final bytes = await File(drawing.localFilePath).readAsBytes();
      final document = await DxfParser().parseBytes(bytes);
      final annotations = await _db.getAnnotations(drawingId: drawing.id);
      final drawnObjects = await _db.getDrawnObjects(drawing.id);
      if (!mounted) return;
      _applyDrawing(document, drawing.id, drawing.name, annotations,
          units: drawing.units, drawnObjects: drawnObjects);
    } catch (_) {
      // файл чертежа мог быть удалён — просто остаёмся на пустом экране
    }
  }

  Future<void> _loadRecentDrawings() async {
    try {
      final drawings = await _db.getDrawings();
      if (!mounted) return;
      setState(() {
        _recent = drawings
            .map((d) =>
                (id: d.id, name: d.name, path: d.localFilePath, units: d.units))
            .toList();
      });
    } catch (_) {
      // список чертежей — не критичен для работы
    }
  }

  Future<void> _openRecent(
      ({String id, String name, String path, String units}) d) async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final bytes = await File(d.path).readAsBytes();
      final document = await DxfParser().parseBytes(bytes);
      final annotations = await _db.getAnnotations(drawingId: d.id);
      final drawnObjects = await _db.getDrawnObjects(d.id);
      if (!mounted) return;
      _applyDrawing(document, d.id, d.name, annotations,
          units: d.units, drawnObjects: drawnObjects);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть чертёж: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Directory> _subDir(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final sub = Directory(p.join(dir.path, name));
    if (!await sub.exists()) await sub.create(recursive: true);
    return sub;
  }

  /// Находит/создаёт запись чертежа по SHA-256 содержимого, сохраняет DXF
  /// в постоянное хранилище и возвращает (id, отображаемое имя, units).
  Future<({String id, String name, String units})> _registerDrawing(
      List<int> bytes, String name) async {
    final hash = sha256.convert(bytes).toString();
    final dir = await _subDir('drawings');
    var drawing = await _db.getDrawingByHash(hash);
    if (drawing == null) {
      final id = const Uuid().v4();
      final storedPath = p.join(dir.path, '$id.dxf');
      await File(storedPath).writeAsBytes(bytes);
      await _db.upsertDrawing(
          id: id, name: name, localFilePath: storedPath, contentHash: hash);
      // переносим старые аннотации, привязанные к имени файла
      await _db.migrateLegacyDrawing(name, id);
      drawing = await _db.getDrawingById(id);
    } else if (!await File(drawing.localFilePath).exists()) {
      final storedPath = p.join(dir.path, '${drawing.id}.dxf');
      await File(storedPath).writeAsBytes(bytes);
      await _db.upsertDrawing(
          id: drawing.id,
          name: name,
          localFilePath: storedPath,
          units: drawing.units,
          contentHash: hash);
      drawing = await _db.getDrawingById(drawing.id);
    }
    final d = drawing!;
    return (id: d.id, name: name, units: d.units);
  }

  /// Создаёт новый пустой чертёж (минимальный DXF) и сразу открывает его.
  Future<void> _createNewDrawing() async {
    final name = await _promptNewDrawingName();
    if (name == null || name.isEmpty) return;
    try {
      if (mounted) setState(() => _isLoading = true);
      // Эталонный пустой чертёж (настоящий DXF AutoCAD) — из него собирается
      // корректный файл, который затем без ошибок открывается в AutoCAD.
      final bytes = await loadEmptyDxfTemplate();
      // Каждый новый чертёж — отдельная запись (без дедупликации по хэшу:
      // пустые DXF идентичны по содержимому, но это разные проекты).
      final drawing = await _registerNewDrawing(bytes, name);
      final document = await DxfParser().parseBytes(bytes);
      if (!mounted) return;
      _applyDrawing(document, drawing.id, drawing.name, const [],
          units: drawing.units, drawnObjects: const []);
      await _loadRecentDrawings();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось создать чертёж: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Создаёт новую запись чертежа с собственным id и именем (без дедупликации).
  Future<({String id, String name, String units})> _registerNewDrawing(
      Uint8List bytes, String name) async {
    final dir = await _subDir('drawings');
    final id = const Uuid().v4();
    final storedPath = p.join(dir.path, '$id.dxf');
    await File(storedPath).writeAsBytes(bytes);
    await _db.upsertDrawing(id: id, name: name, localFilePath: storedPath);
    return (id: id, name: name, units: 'm');
  }

  String _defaultDrawingName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Чертёж ${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}-${two(now.minute)}';
  }

  /// Запрашивает имя нового чертежа (с предложенным именем по дате/времени).
  Future<String?> _promptNewDrawingName() async {
    final controller = TextEditingController(text: _defaultDrawingName());
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый чертёж'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Имя чертежа',
            hintText: 'Например: Корпус А ПП +29.150',
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
    final name = result?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<void> _pickAndLoadDxf() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _loadingMessage = 'Открываем файл…';
        });
      }

      // На Android системный выбор файлов фильтрует по MIME, а у DWG
      // стандартного MIME нет — такой файл становится невыделяемым. Поэтому
      // разрешаем любые файлы и определяем формат по содержимому (сигнатуре),
      // расширения важны только на десктопе.
      const typeGroup = XTypeGroup(
        label: 'Чертежи DXF/DWG',
        extensions: ['dxf', 'dwg'],
        mimeTypes: ['*/*'],
      );

      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      var bytes = await file.readAsBytes();

      // DWG — бинарный формат: сначала конвертируем в DXF нативным модулем.
      if (CadFormatDetector.detect(bytes) == CadFormat.dwg) {
        if (!CadFormatDetector.isKnownDwgVersion(bytes)) {
          if (mounted) setState(() => _isLoading = false);
          if (mounted) {
            await CadErrorDialog.show(
              context,
              const CadConversionException(
                2,
                'версия DWG новее поддерживаемой (до R2018 / AC1032)',
              ),
              fileName: file.name,
            );
          }
          return;
        }
        if (!CadConverter.isSupported) {
          if (mounted) setState(() => _isLoading = false);
          if (mounted) {
            await CadErrorDialog.show(
              context,
              const CadConversionException(
                CadConversionException.codeUnavailable,
                'нативный модуль DWG недоступен на этой платформе',
              ),
              fileName: file.name,
            );
          }
          return;
        }
        if (mounted) setState(() => _loadingMessage = 'Читаем DWG…');
        try {
          bytes = await CadConverter.dwgToDxf(bytes);
        } on CadConversionException catch (error) {
          if (mounted) setState(() => _isLoading = false);
          if (mounted) {
            await CadErrorDialog.show(context, error, fileName: file.name);
          }
          return;
        }
      }

      if (mounted) setState(() => _loadingMessage = 'Разбираем чертёж…');
      final document = await DxfParser().parseBytes(bytes);

      // На Android имя из file_selector не всегда содержит расширение
      // (это ID документа), поэтому проверяем содержимое, а не имя.
      if (document.entities.isEmpty && document.layers.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Файл не распознан как DXF (нет объектов)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Имя чертежа — без расширения исходного файла (.dxf/.dwg и т.п.):
      // оно идёт в заголовок и в имя экспортируемого файла («имя.dxf»).
      final drawingName = p.basenameWithoutExtension(file.name);
      final drawing = await _registerDrawing(bytes, drawingName);
      final existing = await _db.getAnnotations(drawingId: drawing.id);
      final drawnObjects = await _db.getDrawnObjects(drawing.id);
      if (!mounted) return;
      _applyDrawing(document, drawing.id, drawing.name, existing,
          units: drawing.units, drawnObjects: drawnObjects);
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке DXF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        debugPrint('Ошибка разбора DXF: $e');
        debugPrint('$stackTrace');
      }
    }
  }

  void _applyDrawing(DxfDocument document, String drawingId, String name,
      List<Annotation> annotations,
      {String units = 'm', List<DrawnObject> drawnObjects = const []}) {
    setState(() {
      _document = document;
      _drawingId = drawingId;
      _currentFileName = p.basenameWithoutExtension(name);
      _units = units;
      _annotations = annotations;
      _drawnObjects = drawnObjects;
      _syncDrawnLayers();
      _hiddenLayers = {};
      _isLoading = false;
    });
  }

  /// Импорт пакета `.abris` (ZIP с DXF, точками и фото).
  Future<void> _importProject() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      const typeGroup = XTypeGroup(
        label: 'Проект абриса',
        extensions: ['abris', 'zip'],
        mimeTypes: ['application/zip', 'application/octet-stream', '*/*'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final result = await _bundle.importFromBytes(await file.readAsBytes());
      final bytes = await File(result.dxfPath).readAsBytes();
      final document = await DxfParser().parseBytes(bytes);
      final annotations = await _db.getAnnotations(drawingId: result.drawingId);
      final drawnObjects = await _db.getDrawnObjects(result.drawingId);
      if (!mounted) return;
      _applyDrawing(document, result.drawingId, result.drawingName, annotations,
          drawnObjects: drawnObjects);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортировано точек: ${annotations.length}')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка импорта: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Диалог выбора качества фото для пакета `.abris`.
  Future<ExportPhotoQuality?> _pickPhotoQuality() {
    return showDialog<ExportPhotoQuality>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Качество фото'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ExportPhotoQuality.compact),
            child: const ListTile(
              leading: Icon(Icons.compress),
              title: Text('Компактно (рекомендуется)'),
              subtitle: Text('до 1600 px, ~200–400 КБ на фото'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ExportPhotoQuality.full),
            child: const ListTile(
              leading: Icon(Icons.photo_outlined),
              title: Text('Полное качество'),
              subtitle: Text('оригиналы, файл заметно больше'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ExportPhotoQuality.none),
            child: const ListTile(
              leading: Icon(Icons.no_photography),
              title: Text('Без фото'),
              subtitle: Text('только чертёж и точки'),
            ),
          ),
        ],
      ),
    );
  }

  /// Собирает пакет `.abris` с индикатором прогресса. Возвращает путь к файлу.
  Future<String?> _buildProjectPackage(
      String id, ExportPhotoQuality quality) async {
    final progress = ValueNotifier<int>(0);
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Экспорт проекта'),
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Обрабатываю фотографии…'),
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text('Готово фото: $value'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final zipPath = await _bundle.exportToZip(
        id,
        photoQuality: quality,
        onProgress: (done, total) => progress.value = done,
      );
      try {
        await ProjectVersionService.instance.addVersionFromFile(id, zipPath);
      } catch (_) {}
      navigator.pop();
      return zipPath;
    } catch (e) {
      navigator.pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Окно «О программе»: название, версия сборки и ссылка на исходный код.
  Future<void> _showAbout() {
    return showDialog<void>(
      context: context,
      builder: (_) => const AboutAppDialog(),
    );
  }

  /// Экспорт текущего проекта в `.abris` и передача (Android) / сохранение (ПК).
  Future<void> _shareProject() async {
    final id = _drawingId;
    if (id == null) return;
    final quality = await _pickPhotoQuality();
    if (quality == null || !mounted) return;
    final zipPath = await _buildProjectPackage(id, quality);
    if (zipPath == null || !mounted) return;
    await _presentExportedFile(zipPath);
  }

  /// Сохранить пакет `.abris` в файл на устройстве (системный диалог «Сохранить как»).
  Future<void> _saveProjectToFile() async {
    final id = _drawingId;
    if (id == null) return;
    final quality = await _pickPhotoQuality();
    if (quality == null || !mounted) return;
    final zipPath = await _buildProjectPackage(id, quality);
    if (zipPath == null || !mounted) return;
    final suggested =
        '${p.basenameWithoutExtension(_currentFileName ?? 'project')}.abris';
    try {
      String? saved;
      if (Platform.isAndroid || Platform.isIOS) {
        // Системный SAF-диалог: файл попадёт в выбранную пользователем папку.
        saved = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить проект',
          fileName: suggested,
          type: FileType.any,
          bytes: await File(zipPath).readAsBytes(),
        );
      } else {
        final location = await getSaveLocation(suggestedName: suggested);
        if (location != null) {
          await File(zipPath).copy(location.path);
          saved = location.path;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved == null
              ? 'Сохранение отменено'
              : 'Проект сохранён: $saved'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить файл: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _presentExportedFile(String zipPath) async {
    final saved = await shareOrSaveFile(zipPath, text: 'Проект абриса');
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сохранено: $saved')),
      );
    }
  }

  /// Экспорт чертежа: DXF, DWG (2018/2013/2007) или DXF + фото (ZIP).
  Future<void> _exportDxf() async {
    final id = _drawingId;
    if (id == null) return;
    final options = await showDialog<DxfExportOptions>(
      context: context,
      builder: (_) => _DxfExportDialog(
        initial: DxfExportOptions(hiddenDrawnLayers: _hiddenDrawnLayers),
      ),
    );
    if (options == null || !mounted) return;
    final service = DxfExportService();
    final dwgVersion = options.dwgVersion;

    if (options.mode == DxfExportMode.withPhotos) {
      final notifier = ValueNotifier<int>(0);
      final navigator = Navigator.of(context, rootNavigator: true);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Экспорт DXF и фото'),
            content: ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (context, value, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Обрабатываю фотографии…'),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('Готово фото: $value'),
                ],
              ),
            ),
          ),
        ),
      );
      try {
        final path = await service.exportToFile(
          id,
          options,
          onProgress: (done, total) => notifier.value = done,
        );
        navigator.pop();
        await _presentDxfFile(path, zip: true);
      } catch (e) {
        navigator.pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка экспорта: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    if (dwgVersion != null) {
      // Запись DWG — в нативном модуле (изолят), показываем прогресс.
      final navigator = Navigator.of(context, rootNavigator: true);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text('Экспорт в DWG ${dwgVersion.label}'),
            content: const Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Сохраняем DWG…')),
              ],
            ),
          ),
        ),
      );
      try {
        final path = await service.exportToFile(id, options);
        navigator.pop();
        await _presentDxfFile(path, dwg: dwgVersion);
      } on CadConversionException catch (e) {
        navigator.pop();
        if (mounted) {
          final message = e.isWriteUnsupported
              ? 'В чертеже есть объекты, которые нельзя записать в DWG. '
                  'Экспортируйте его в DXF.'
              : 'Не удалось записать DWG: ${e.message}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      } catch (e) {
        navigator.pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка экспорта: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    try {
      final path = await service.exportToFile(id, options);
      await _presentDxfFile(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Показывает результат экспорта. На телефоне не «выкидывает» сразу
  /// в share-sheet: пользователь сам решает — «Поделиться» или «Готово»
  /// (экран остаётся в приложении).
  Future<void> _presentDxfFile(String path,
      {bool zip = false, DwgExportVersion? dwg}) async {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      if (!mounted) return;
      final share = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(dwg == null ? 'Экспорт готов' : 'DWG готов'),
          content: Text(
            '${p.basename(path)}\n\n'
            'Файл сохранён в экспорт приложения. Чтобы отправить его '
            '(Telegram, почта, облако), нажмите «Поделиться».',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Готово'),
            ),
            FilledButton(
              key: const Key('dxf-export-share'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Поделиться'),
            ),
          ],
        ),
      );
      if (share != true || !mounted) return;
      // Для DXF — octet-stream, иначе mime-пакет отдаёт image/vnd.dxf,
      // и Telegram показывает файл картинкой (IMG_…jpg).
      await shareOrSaveFile(
        path,
        text: zip
            ? 'DXF + фото (ZIP)'
            : (dwg == null ? 'DXF чертежа' : 'DWG ${dwg.label} чертежа'),
        mimeType: zip ? 'application/zip' : 'application/octet-stream',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Экспорт: ${p.basename(path)}')),
        );
      }
      return;
    }
    final saved = await shareOrSaveFile(
      path,
      text: zip
          ? 'DXF + фото (ZIP)'
          : (dwg == null ? 'DXF чертежа' : 'DWG ${dwg.label} чертежа'),
      mimeType: zip ? 'application/zip' : 'application/octet-stream',
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сохранено: $saved')),
      );
    }
  }

  Future<void> _openHistory() async {
    final id = _drawingId;
    if (id == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectHistoryScreen(
          drawingId: id,
          drawingName: _currentFileName ?? 'Чертеж',
        ),
      ),
    );
    if (changed == true) {
      await _reloadAnnotations();
      if (mounted) setState(() => _viewerEpoch++);
    }
  }

  void _onCanvasTap(double dxfX, double dxfY) {
    if (_mode == DrawingMode.annotation) {
      _openCreateAnnotation(dxfX, dxfY);
    }
  }

  /// Лист создания точки по координате (режим «Точка» и «+ Точка»).
  Future<void> _openCreateAnnotation(double dxfX, double dxfY) async {
    // Защита от повторного открытия: одно нажатие может прийти из нескольких
    // обработчиков (тап и отпускание прицела). Второй лист не открываем —
    // иначе на одном месте появляются две точки с одинаковым номером.
    if (_annotationSheetOpen) return;
    _annotationSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CreateAnnotationSheet(
          drawingId: _drawingId ?? 'unknown',
          dxfX: dxfX,
          dxfY: dxfY,
          annotationNumber: _nextAnnotationNumber,
          units: _units,
          onSaved: (annotation) async {
            await _db.insertAnnotation(annotation);
            setState(() => _annotations.add(annotation));
          },
        ),
      );
    } finally {
      _annotationSheetOpen = false;
    }
  }

  /// Нижний лист слоёв (видимость DXF и рисунков, активный слой).
  Future<void> _openLayersSheet() async {
    final doc = _document;
    if (doc == null) return;
    final dxfLayers = [
      for (final l in doc.layers)
        if (l.name.isNotEmpty) l.name,
    ];
    final drawnLayers = <String>{
      ..._drawnLayers,
      for (final o in _drawnObjects) o.layer,
    }.toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LayersSheet(
        dxfLayers: dxfLayers,
        drawnLayers: drawnLayers,
        hiddenDxfLayers: _hiddenLayers,
        hiddenDrawnLayers: _hiddenDrawnLayers,
        activeDrawnLayer: _activeDrawnLayer,
        onToggleDxfLayer: _onToggleDxfLayer,
        onToggleDrawnLayer: _onToggleDrawnLayer,
        onSetActiveDrawnLayer: _onSetActiveDrawnLayer,
        onCreateDrawnLayer: _onCreateDrawnLayer,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openAnnotation(Annotation ann) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnotationDetailScreen(annotation: ann, units: _units),
      ),
    );
    await _reloadAnnotations();
  }

  /// Несколько точек в одном месте: выбор конкретной точки или новая точка.
  Future<void> _openAnnotationCluster(
      List<Annotation> anns, Offset world) async {
    if (anns.isEmpty) return;
    // Возвращаем: точку — открыть её; строку 'new' — создать новую точку;
    // null (тап по пустому месту) — просто вернуться на план, ничего не создавать.
    final chosen = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Несколько точек в одном месте',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            for (final ann in anns)
              ListTile(
                key: Key('cluster-point-${ann.number}'),
                leading: const Icon(Icons.place, color: Colors.red),
                title: Text('Точка №${ann.number}'),
                subtitle: Text(
                  '${ann.dxfX.toStringAsFixed(2)}, ${ann.dxfY.toStringAsFixed(2)}',
                ),
                onTap: () => Navigator.pop(ctx, ann),
              ),
            const Divider(height: 1),
            ListTile(
              key: const Key('cluster-create'),
              leading: const Icon(Icons.add_location_alt),
              title: const Text('Новая точка здесь'),
              onTap: () => Navigator.pop(ctx, 'new'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen is Annotation) {
      await _openAnnotation(chosen);
    } else if (chosen == 'new') {
      await _openCreateAnnotation(world.dx, world.dy);
    }
    // Иначе лист закрыли тапом по пустому месту — остаёмся на плане.
  }

  Future<void> _reloadAnnotations() async {
    final drawingId = _drawingId ?? 'unknown';
    final anns = await _db.getAnnotations(drawingId: drawingId);
    if (mounted) setState(() => _annotations = anns);
  }

  void _onMeasurementFinished(Measurement measurement) {
    _db.insertMeasurement(measurement);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(measurement.formatResult(_units))),
    );
  }

  Future<void> _onDrawnObjectCreated(DrawnObject object) async {
    try {
      await _db.insertDrawnObject(object);
      if (!mounted) return;
      setState(() => _drawnObjects = [..._drawnObjects, object]);
      _syncDrawnLayers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить объект: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Текст перемещён/повёрнут — сохранить обновление.
  Future<void> _onDrawnObjectUpdated(DrawnObject object) async {
    try {
      await _db.insertDrawnObject(object);
      if (!mounted) return;
      setState(() {
        _drawnObjects = [
          for (final o in _drawnObjects)
            if (o.id == object.id) object else o,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить текст: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Нарисованный объект удалён — убрать из базы и с экрана.
  Future<void> _onDrawnObjectDeleted(DrawnObject object) async {
    try {
      await _db.deleteDrawnObject(object.id);
      if (!mounted) return;
      setState(() {
        _drawnObjects = [
          for (final o in _drawnObjects)
            if (o.id != object.id) o,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось удалить объект: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Дополнить список известных слоёв рисунков слоями загруженных объектов.
  void _syncDrawnLayers() {
    for (final o in _drawnObjects) {
      if (!_drawnLayers.contains(o.layer)) _drawnLayers.add(o.layer);
    }
  }

  void _onToggleDxfLayer(String layer, bool visible) {
    setState(() {
      if (visible) {
        _hiddenLayers.remove(layer);
      } else {
        _hiddenLayers.add(layer);
      }
    });
  }

  void _onToggleDrawnLayer(String layer, bool visible) {
    setState(() {
      if (visible) {
        _hiddenDrawnLayers.remove(layer);
      } else {
        _hiddenDrawnLayers.add(layer);
      }
    });
  }

  void _onSetActiveDrawnLayer(String layer) {
    setState(() {
      if (!_drawnLayers.contains(layer)) _drawnLayers.add(layer);
      _activeDrawnLayer = layer;
      _hiddenDrawnLayers.remove(layer);
    });
  }

  void _onCreateDrawnLayer(String layer) {
    setState(() {
      if (!_drawnLayers.contains(layer)) _drawnLayers.add(layer);
      _activeDrawnLayer = layer;
      _hiddenDrawnLayers.remove(layer);
    });
  }

  Future<void> _undoLastDrawn() async {
    if (_drawnObjects.isEmpty) return;
    final last = _drawnObjects.last;
    try {
      await _db.deleteDrawnObject(last.id);
      if (!mounted) return;
      setState(() {
        _drawnObjects = _drawnObjects.sublist(0, _drawnObjects.length - 1);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось удалить объект: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentFileName != null ? 'DXF: $_currentFileName' : 'Мензулка',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Открыть DXF/DWG',
            onPressed: _pickAndLoadDxf,
          ),
          if (_document != null) ...[
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Список аннотаций',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnnotationsListScreen(
                      drawingId: _drawingId ?? 'unknown',
                      drawingName: _currentFileName ?? 'Чертеж',
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'История измерений',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeasurementsHistoryScreen(),
                  ),
                );
              },
            ),
          ],
          PopupMenuButton<String>(
            tooltip: 'Проект',
            onSelected: (value) {
              if (value == 'share') _shareProject();
              if (value == 'saveProject') _saveProjectToFile();
              if (value == 'import') _importProject();
              if (value == 'history') _openHistory();
              if (value == 'exportDxf') _exportDxf();
              if (value == 'about') _showAbout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'share',
                enabled: _drawingId != null,
                child: const Text('Поделиться проектом'),
              ),
              PopupMenuItem(
                value: 'saveProject',
                enabled: _drawingId != null,
                child: const Text('Сохранить проект в файл…'),
              ),
              PopupMenuItem(
                value: 'exportDxf',
                enabled: _drawingId != null,
                child: const Text('Экспорт в DXF…'),
              ),
              PopupMenuItem(
                value: 'history',
                enabled: _drawingId != null,
                child: const Text('История и версии'),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Text('Импортировать проект'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'about',
                child: Text('О программе'),
              ),
            ],
          ),
        ],
        bottom: _document == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: DrawingToolbar(
                  snapSettings: _snapSettings,
                  hiddenLayersCount: _hiddenLayers.length,
                  onLayers: _openLayersSheet,
                  onChanged: () => setState(() {}),
                ),
              ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_loadingMessage),
                ],
              ),
            )
          : _document == null
              ? _buildEmptyState()
              : Stack(
                  children: [
                    DxfViewer(
                      key: ValueKey('viewer_$_viewerEpoch'),
                      document: _document!,
                      annotations: _annotations,
                      hiddenLayers: _hiddenLayers,
                      mode: _mode,
                      units: _units,
                      drawingId: _drawingId ?? '',
                      snapSettings: _snapSettings,
                      onCanvasTap: _onCanvasTap,
                      onCreatePointAt: _openCreateAnnotation,
                      onMeasurementFinished: _onMeasurementFinished,
                      onAnnotationTap: _openAnnotation,
                      onAnnotationClusterTap: _openAnnotationCluster,
                      drawnObjects: _drawnObjects,
                      onDrawnObjectCreated: _onDrawnObjectCreated,
                      onUndoLastDrawn: _undoLastDrawn,
                      onDrawnObjectUpdated: _onDrawnObjectUpdated,
                      onDrawnObjectDeleted: _onDrawnObjectDeleted,
                      hiddenDrawnLayers: _hiddenDrawnLayers,
                      activeDrawnLayer: _activeDrawnLayer,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      // Белая подложка уходит под системную панель навигации,
                      // а сами кнопки подняты над ней (Android 15 edge-to-edge).
                      child: Container(
                        color: Colors.white,
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewPadding.bottom,
                        ),
                        child: WorkspaceDock(
                          currentMode: _mode,
                          onModeChanged: (mode) => setState(() => _mode = mode),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Начните новый чертёж или откройте существующий',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Создать чертёж'),
              onPressed: _createNewDrawing,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Открыть DXF/DWG'),
              onPressed: _pickAndLoadDxf,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Импортировать проект'),
              onPressed: _importProject,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            if (_recent.isNotEmpty) ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Последние чертежи',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._recent.take(6).map((d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(p.basenameWithoutExtension(d.name),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(d.units),
                    onTap: () => _openRecent(d),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Диалог параметров экспорта в DXF.
class _DxfExportDialog extends StatefulWidget {
  final DxfExportOptions initial;

  const _DxfExportDialog({required this.initial});

  @override
  State<_DxfExportDialog> createState() => _DxfExportDialogState();
}

class _DxfExportDialogState extends State<_DxfExportDialog> {
  late DxfExportMode _mode = widget.initial.mode;
  late DwgExportVersion? _dwgVersion = widget.initial.dwgVersion;
  late bool _includePoints = widget.initial.includePoints;
  late bool _includeMeasurements = widget.initial.includeMeasurements;
  late bool _visibleLayersOnly = widget.initial.visibleLayersOnly;

  bool get _isDwg => _dwgVersion != null;
  bool get _isZip => _mode == DxfExportMode.withPhotos && !_isDwg;

  DxfExportOptions _result() => DxfExportOptions(
        mode: _isZip ? DxfExportMode.withPhotos : DxfExportMode.geometry,
        includePoints: _includePoints,
        includeMeasurements: _includeMeasurements,
        visibleLayersOnly: _visibleLayersOnly,
        hiddenDrawnLayers: widget.initial.hiddenDrawnLayers,
        photoQuality: widget.initial.photoQuality,
        dwgVersion: _dwgVersion,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Экспорт чертежа'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modeTile(
              key: const Key('dxf-export-mode-geometry'),
              selected: _mode == DxfExportMode.geometry && !_isDwg,
              title: 'DXF (геометрия)',
              subtitle:
                  'Все исходные примитивы + нарисованные объекты по слоям',
              onTap: () => setState(() {
                _mode = DxfExportMode.geometry;
                _dwgVersion = null;
              }),
            ),
            _modeTile(
              key: const Key('dxf-export-mode-dwg'),
              selected: _isDwg,
              title: 'DWG (AutoCAD)',
              subtitle: 'Тот же чертёж, записанный в формате DWG',
              onTap: () => setState(() {
                _mode = DxfExportMode.geometry;
                _dwgVersion ??= DwgExportVersion.r2018;
              }),
            ),
            if (_isDwg)
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final version in DwgExportVersion.values)
                      ChoiceChip(
                        key: Key('dwg-version-${version.label}'),
                        label: Text(version.label),
                        selected: _dwgVersion == version,
                        onSelected: (_) =>
                            setState(() => _dwgVersion = version),
                      ),
                  ],
                ),
              ),
            _modeTile(
              key: const Key('dxf-export-mode-photos'),
              selected: _isZip,
              title: 'DXF + фото (ZIP)',
              subtitle: 'Тот же DXF + фотографии точек, points.csv и README',
              onTap: () => setState(() {
                _mode = DxfExportMode.withPhotos;
                _dwgVersion = null;
              }),
            ),
            const Divider(height: 16),
            CheckboxListTile(
              key: const Key('dxf-export-points'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.trailing,
              title: const Text('Точки с номерами'),
              subtitle: const Text('Слой «Точки»: кружки и номера'),
              value: _includePoints,
              onChanged: (v) => setState(() => _includePoints = v ?? true),
            ),
            CheckboxListTile(
              key: const Key('dxf-export-measurements'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.trailing,
              title: const Text('Измерения'),
              subtitle: const Text('Слой «Измерения»: линии и подписи'),
              value: _includeMeasurements,
              onChanged: (v) =>
                  setState(() => _includeMeasurements = v ?? true),
            ),
            CheckboxListTile(
              key: const Key('dxf-export-visible'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.trailing,
              title: const Text('Только видимые слои'),
              subtitle: const Text('Пропустить нарисованное на скрытых слоях'),
              value: _visibleLayersOnly,
              onChanged: (v) => setState(() => _visibleLayersOnly = v ?? false),
            ),
            if (_isDwg) ...[
              const Divider(height: 16),
              Text(
                'DWG ${_dwgVersion!.label}: открывается в AutoCAD '
                '${_dwgVersion!.label}+. Объекты Civil 3D (поверхности, '
                'трубопроводы) в DWG не переносятся — для них используйте DXF.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('dxf-export-submit'),
          onPressed: () => Navigator.pop(context, _result()),
          child: const Text('Экспортировать'),
        ),
      ],
    );
  }

  Widget _modeTile({
    required Key key,
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
