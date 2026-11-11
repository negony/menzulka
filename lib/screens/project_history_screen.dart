import 'package:flutter/material.dart';

import '../models/history_event.dart';
import '../models/project_version.dart';
import '../services/database.dart';
import '../services/file_share.dart';
import '../services/project_version_service.dart';
import '../utils/format_utils.dart';

/// История изменений проекта и версии-снимки `.abris`.
class ProjectHistoryScreen extends StatefulWidget {
  final String drawingId;
  final String drawingName;

  const ProjectHistoryScreen({
    super.key,
    required this.drawingId,
    required this.drawingName,
  });

  @override
  State<ProjectHistoryScreen> createState() => _ProjectHistoryScreenState();
}

class _ProjectHistoryScreenState extends State<ProjectHistoryScreen> {
  final _db = DatabaseService.instance;
  bool _loading = true;
  List<HistoryEvent> _events = [];
  List<ProjectVersion> _versions = [];
  String _search = '';
  HistoryCategory? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final events = await _db.getHistory(
      drawingId: widget.drawingId,
      types: _filter == null ? null : historyCategoryTypes[_filter],
      search: _search,
    );
    final versions = await _db.getProjectVersions(widget.drawingId);
    if (!mounted) return;
    setState(() {
      _events = events;
      _versions = versions;
      _loading = false;
    });
  }

  Future<void> _createVersion() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    _showProgress('Создаю снимок проекта…');
    try {
      await ProjectVersionService.instance.createVersion(widget.drawingId);
      if (!mounted) return;
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Версия проекта создана')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось создать версию: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restore(ProjectVersion version) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Восстановить версию?'),
        content: Text(
          'Текущее состояние проекта будет заменено версией «${version.label}».\n\n'
          'Перед восстановлением автоматически создаётся страховочная версия.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    _showProgress('Восстанавливаю версию…');
    try {
      await ProjectVersionService.instance.restore(version);
      if (!mounted) return;
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Восстановлена версия «${version.label}»')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось восстановить: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _share(ProjectVersion version) async {
    final saved =
        await shareOrSaveFile(version.filePath, text: 'Версия проекта');
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сохранено: $saved')),
      );
    }
  }

  Future<void> _delete(ProjectVersion version) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить версию?'),
        content:
            Text('«${version.label}» будет удалена без возможности отмены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ProjectVersionService.instance.delete(version);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Версия удалена')),
      );
      await _load();
    }
  }

  void _showProgress(String text) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'История: ${widget.drawingName}',
            style: const TextStyle(fontSize: 16),
          ),
          bottom: const TabBar(
            tabs: [Tab(text: 'Изменения'), Tab(text: 'Версии')],
          ),
        ),
        body: TabBarView(
          children: [_buildHistoryTab(), _buildVersionsTab()],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final chips = <Widget>[
      ChoiceChip(
        label: const Text('Все'),
        selected: _filter == null,
        onSelected: (_) {
          setState(() => _filter = null);
          _load();
        },
      ),
      for (final category in HistoryCategory.values)
        ChoiceChip(
          label: Text(_categoryLabel(category)),
          selected: _filter == category,
          onSelected: (_) {
            setState(() => _filter = category);
            _load();
          },
        ),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Поиск по журналу...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              _search = value;
              _load();
            },
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final chip in chips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: chip,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _events.isEmpty
                  ? const Center(child: Text('Пока нет событий'))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final showHeader = index == 0 ||
                            formatHistoryDate(_events[index - 1].createdAt) !=
                                formatHistoryDate(event.createdAt);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeader)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                child: Text(
                                  formatHistoryDate(event.createdAt),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey[700],
                                  ),
                                ),
                              ),
                            ListTile(
                              leading: CircleAvatar(
                                radius: 16,
                                child: Icon(
                                  _eventIcon(event.type),
                                  size: 18,
                                ),
                              ),
                              title: Text(event.summary),
                              subtitle:
                                  Text(formatHistoryTime(event.createdAt)),
                            ),
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildVersionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Снимки проекта (до ${ProjectVersionService.maxVersions})',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              FilledButton.icon(
                onPressed: _createVersion,
                icon: const Icon(Icons.bookmark_add),
                label: const Text('Создать версию'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _versions.isEmpty
                  ? const Center(child: Text('Версий пока нет'))
                  : ListView.builder(
                      itemCount: _versions.length,
                      itemBuilder: (context, index) {
                        final version = _versions[index];
                        final showHeader = index == 0 ||
                            formatHistoryDate(_versions[index - 1].createdAt) !=
                                formatHistoryDate(version.createdAt);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeader)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                child: Text(
                                  formatHistoryDate(version.createdAt),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey[700],
                                  ),
                                ),
                              ),
                            ListTile(
                              leading: const CircleAvatar(
                                radius: 16,
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                ),
                              ),
                              title: Text(version.label),
                              subtitle: Text(
                                '${formatHistoryTime(version.createdAt)} · '
                                '${version.contentsLabel} · '
                                '${formatBytes(version.sizeBytes)}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'share') _share(version);
                                  if (value == 'restore') _restore(version);
                                  if (value == 'delete') _delete(version);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'share',
                                    child: Text('Поделиться'),
                                  ),
                                  PopupMenuItem(
                                    value: 'restore',
                                    child: Text('Восстановить'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Удалить'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String _categoryLabel(HistoryCategory category) {
    switch (category) {
      case HistoryCategory.points:
        return 'Точки';
      case HistoryCategory.photos:
        return 'Фото';
      case HistoryCategory.audio:
        return 'Заметки';
      case HistoryCategory.measurements:
        return 'Измерения';
      case HistoryCategory.system:
        return 'Система';
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case HistoryEventType.annotationCreated:
        return Icons.add_location_alt;
      case HistoryEventType.annotationUpdated:
        return Icons.edit_location_alt;
      case HistoryEventType.annotationDeleted:
        return Icons.delete_outline;
      case HistoryEventType.annotationRestored:
        return Icons.restore;
      case HistoryEventType.photoAdded:
        return Icons.add_a_photo;
      case HistoryEventType.photoRemoved:
        return Icons.hide_image;
      case HistoryEventType.audioAdded:
        return Icons.mic;
      case HistoryEventType.audioRemoved:
        return Icons.mic_off;
      case HistoryEventType.measurementCreated:
        return Icons.straighten;
      case HistoryEventType.measurementDeleted:
        return Icons.straighten;
      case HistoryEventType.projectExported:
        return Icons.upload_file;
      case HistoryEventType.projectImported:
        return Icons.download;
      case HistoryEventType.dxfExported:
        return Icons.file_download;
      case HistoryEventType.versionCreated:
        return Icons.bookmark_add;
      case HistoryEventType.versionRestored:
        return Icons.settings_backup_restore;
      default:
        return Icons.history;
    }
  }
}
