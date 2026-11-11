import 'package:flutter/material.dart';

import '../models/snap_models.dart';
import 'drafting_icons.dart';
import 'osnap_icon.dart';
import 'snap_glyph.dart';

/// Верхняя панель главного экрана: слои, привязки (раскрывающийся список),
/// ортогональное черчение и угловая привязка с выбором шага.
class DrawingToolbar extends StatelessWidget {
  final SnapSettings snapSettings;
  final int hiddenLayersCount;
  final VoidCallback onLayers;
  final VoidCallback onChanged;

  const DrawingToolbar({
    super.key,
    required this.snapSettings,
    required this.hiddenLayersCount,
    required this.onLayers,
    required this.onChanged,
  });

  static const List<double> polarSteps = [45, 30, 20, 15, 10, 5];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          IconButton(
            key: const Key('layers-button'),
            icon: Badge(
              isLabelVisible: hiddenLayersCount > 0,
              label: Text('$hiddenLayersCount'),
              child: const Icon(Icons.layers, size: 22),
            ),
            tooltip: 'Слои',
            visualDensity: VisualDensity.compact,
            onPressed: onLayers,
          ),
          _divider(),
          // Привязки: только иконка, типы — в раскрывающемся списке.
          PopupMenuButton<String>(
            key: const Key('snap-menu'),
            tooltip: 'Привязки',
            padding: EdgeInsets.zero,
            onSelected: _onSnapMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const Key('snap-master'),
                value: 'master',
                child: _menuRow(
                  checked: snapSettings.enabled,
                  label: 'Включить привязки',
                ),
              ),
              const PopupMenuDivider(),
              for (final type in SnapType.values)
                PopupMenuItem(
                  key: Key('snap-toggle-${type.name}'),
                  value: 'type-${type.name}',
                  child: _menuRow(
                    checked: _typeEnabled(type),
                    label: type.label,
                    glyph: type,
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: OsnapIcon(size: 22, enabled: snapSettings.enabled),
            ),
          ),
          _divider(),
          IconButton(
            key: const Key('ortho-toggle'),
            icon: OrthoIcon(size: 22, enabled: snapSettings.ortho),
            tooltip: snapSettings.ortho
                ? 'Ортогональное черчение: вкл'
                : 'Ортогональное черчение: выкл',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              snapSettings.ortho = !snapSettings.ortho;
              if (snapSettings.ortho) snapSettings.polarStep = null;
              onChanged();
            },
          ),
          PopupMenuButton<double>(
            key: const Key('polar-menu'),
            tooltip: 'Угловая привязка',
            onSelected: (step) {
              snapSettings.polarStep = step <= 0 ? null : step;
              if (snapSettings.polarStep != null) {
                snapSettings.ortho = false;
              }
              onChanged();
            },
            itemBuilder: (context) => [
              PopupMenuItem<double>(
                key: const Key('polar-off'),
                value: 0,
                child: _menuRow(
                  checked: snapSettings.polarStep == null,
                  label: 'Выключена',
                ),
              ),
              const PopupMenuDivider(),
              for (final step in polarSteps)
                PopupMenuItem<double>(
                  key: Key('polar-${step.toInt()}'),
                  value: step,
                  child: _menuRow(
                    checked: snapSettings.polarStep == step,
                    label: '${step.toInt()}°',
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PolarIcon(
                    size: 22,
                    enabled: snapSettings.polarStep != null,
                  ),
                  if (snapSettings.polarStep != null) ...[
                    const SizedBox(width: 2),
                    Text(
                      '${snapSettings.polarStep!.toInt()}°',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSnapMenu(String value) {
    if (value == 'master') {
      snapSettings.enabled = !snapSettings.enabled;
    } else if (value.startsWith('type-')) {
      final name = value.substring(5);
      for (final type in SnapType.values) {
        if (type.name == name) {
          _setType(type, !_typeEnabled(type));
          break;
        }
      }
    }
    onChanged();
  }

  Widget _menuRow({
    required bool checked,
    required String label,
    SnapType? glyph,
  }) {
    return Row(
      children: [
        Icon(
          checked ? Icons.check_box : Icons.check_box_outline_blank,
          size: 18,
          color: checked ? Colors.blue : Colors.grey,
        ),
        const SizedBox(width: 8),
        if (glyph != null) ...[
          SnapGlyph(type: glyph, size: 18),
          const SizedBox(width: 6),
        ],
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 22,
        color: Colors.grey.withValues(alpha: 0.4),
      );

  bool _typeEnabled(SnapType type) {
    switch (type) {
      case SnapType.vertex:
        return snapSettings.vertex;
      case SnapType.point:
        return snapSettings.point;
      case SnapType.intersection:
        return snapSettings.intersection;
      case SnapType.perpendicular:
        return snapSettings.perpendicular;
      case SnapType.tangent:
        return snapSettings.tangent;
      case SnapType.nearest:
        return snapSettings.nearest;
    }
  }

  void _setType(SnapType type, bool value) {
    switch (type) {
      case SnapType.vertex:
        snapSettings.vertex = value;
      case SnapType.point:
        snapSettings.point = value;
      case SnapType.intersection:
        snapSettings.intersection = value;
      case SnapType.perpendicular:
        snapSettings.perpendicular = value;
      case SnapType.tangent:
        snapSettings.tangent = value;
      case SnapType.nearest:
        snapSettings.nearest = value;
    }
  }
}
