import 'package:flutter/material.dart';

/// Нижний лист «Слои»: видимость слоёв DXF и рисунков, активный слой,
/// создание нового слоя рисунков. Открывается с главного экрана.
class LayersSheet extends StatefulWidget {
  final List<String> dxfLayers;
  final List<String> drawnLayers;
  final Set<String> hiddenDxfLayers;
  final Set<String> hiddenDrawnLayers;
  final String activeDrawnLayer;
  final void Function(String layer, bool visible) onToggleDxfLayer;
  final void Function(String layer, bool visible) onToggleDrawnLayer;
  final ValueChanged<String> onSetActiveDrawnLayer;
  final ValueChanged<String> onCreateDrawnLayer;

  const LayersSheet({
    super.key,
    required this.dxfLayers,
    required this.drawnLayers,
    required this.hiddenDxfLayers,
    required this.hiddenDrawnLayers,
    required this.activeDrawnLayer,
    required this.onToggleDxfLayer,
    required this.onToggleDrawnLayer,
    required this.onSetActiveDrawnLayer,
    required this.onCreateDrawnLayer,
  });

  @override
  State<LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<LayersSheet> {
  late final Set<String> _hiddenDxf = Set<String>.of(widget.hiddenDxfLayers);
  late final Set<String> _hiddenDrawn =
      Set<String>.of(widget.hiddenDrawnLayers);
  late final List<String> _drawnLayers = [...widget.drawnLayers];
  late String _active = widget.activeDrawnLayer;
  final _newLayerController = TextEditingController();

  @override
  void dispose() {
    _newLayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dxfLayers = [...widget.dxfLayers]..sort();
    final drawnLayers = [..._drawnLayers]..sort();
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Слои',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text(
                      'Чертёж (DXF)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                    for (final layer in dxfLayers)
                      CheckboxListTile(
                        key: Key('dxf-layer-$layer'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.trailing,
                        title: Text(layer,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black)),
                        value: !_hiddenDxf.contains(layer),
                        onChanged: (v) {
                          final visible = v ?? true;
                          setState(() {
                            if (visible) {
                              _hiddenDxf.remove(layer);
                            } else {
                              _hiddenDxf.add(layer);
                            }
                          });
                          widget.onToggleDxfLayer(layer, visible);
                        },
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Рисунки',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                    for (final layer in drawnLayers)
                      ListTile(
                        key: Key('drawn-layer-$layer'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Checkbox(
                          value: !_hiddenDrawn.contains(layer),
                          onChanged: (v) {
                            final visible = v ?? true;
                            setState(() {
                              if (visible) {
                                _hiddenDrawn.remove(layer);
                              } else {
                                _hiddenDrawn.add(layer);
                              }
                            });
                            widget.onToggleDrawnLayer(layer, visible);
                          },
                        ),
                        title: Text(layer,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black)),
                        subtitle:
                            _active == layer ? const Text('активный') : null,
                        trailing: _active == layer
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 20),
                                tooltip: 'Сделать активным',
                                onPressed: () {
                                  setState(() => _active = layer);
                                  widget.onSetActiveDrawnLayer(layer);
                                },
                              ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('drawn-layer-new'),
                            controller: _newLayerController,
                            decoration: const InputDecoration(
                              hintText: 'Новый слой',
                              isDense: true,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const Key('drawn-layer-add'),
                          onPressed: () {
                            final name = _newLayerController.text.trim();
                            if (name.isEmpty) return;
                            setState(() {
                              if (!_drawnLayers.contains(name)) {
                                _drawnLayers.add(name);
                              }
                              _active = name;
                            });
                            widget.onCreateDrawnLayer(name);
                            _newLayerController.clear();
                          },
                          child: const Text('Создать'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
