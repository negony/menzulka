import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/widgets/drawing_toolbar.dart';
import 'package:menzulka/widgets/layers_sheet.dart';

void main() {
  testWidgets('верхняя панель: слои, меню привязок, орто и угол',
      (tester) async {
    final settings = SnapSettings();
    var changes = 0;
    var layersTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: DrawingToolbar(
                snapSettings: settings,
                hiddenLayersCount: 2,
                onLayers: () => layersTaps++,
                onChanged: () => changes++,
              ),
            ),
          ),
          body: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('layers-button')), findsOneWidget);
    expect(find.byKey(const Key('snap-menu')), findsOneWidget);
    expect(find.byKey(const Key('ortho-toggle')), findsOneWidget);
    expect(find.byKey(const Key('polar-menu')), findsOneWidget);

    // Раскрывающийся список привязок: выключить «Пересечение».
    await tester.tap(find.byKey(const Key('snap-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('snap-toggle-vertex')), findsOneWidget);
    await tester.tap(find.byKey(const Key('snap-toggle-intersection')));
    await tester.pumpAndSettle();
    expect(settings.intersection, isFalse);
    expect(changes, greaterThan(0));

    // Мастер привязок.
    await tester.tap(find.byKey(const Key('snap-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('snap-master')));
    await tester.pumpAndSettle();
    expect(settings.enabled, isFalse);

    // Ортогональное черчение — отдельная иконка.
    await tester.tap(find.byKey(const Key('ortho-toggle')));
    await tester.pumpAndSettle();
    expect(settings.ortho, isTrue);

    // Угловая привязка — список шагов; орто при этом выключается.
    await tester.tap(find.byKey(const Key('polar-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('polar-45')), findsOneWidget);
    expect(find.byKey(const Key('polar-5')), findsOneWidget);
    await tester.tap(find.byKey(const Key('polar-45')));
    await tester.pumpAndSettle();
    expect(settings.polarStep, 45);
    expect(settings.ortho, isFalse);

    await tester.tap(find.byKey(const Key('layers-button')));
    await tester.pump();
    expect(layersTaps, 1);
  });

  testWidgets('лист слоёв: видимость, активный слой, создание', (tester) async {
    final dxfToggles = <({String layer, bool visible})>[];
    final drawnToggles = <({String layer, bool visible})>[];
    var active = '';
    final created = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: LayersSheet(
              dxfLayers: const ['0', 'SNAP'],
              drawnLayers: const ['Слой 1', 'Слой 2'],
              hiddenDxfLayers: const {},
              hiddenDrawnLayers: const {},
              activeDrawnLayer: 'Слой 1',
              onToggleDxfLayer: (l, v) =>
                  dxfToggles.add((layer: l, visible: v)),
              onToggleDrawnLayer: (l, v) =>
                  drawnToggles.add((layer: l, visible: v)),
              onSetActiveDrawnLayer: (l) => active = l,
              onCreateDrawnLayer: created.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dxf-layer-0')), findsOneWidget);
    expect(find.byKey(const Key('drawn-layer-Слой 1')), findsOneWidget);
    expect(find.text('активный'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dxf-layer-0')));
    await tester.pumpAndSettle();
    expect(dxfToggles, isNotEmpty);
    expect(dxfToggles.last.layer, '0');
    expect(dxfToggles.last.visible, isFalse);

    final drawnCheckbox = find.descendant(
      of: find.byKey(const Key('drawn-layer-Слой 1')),
      matching: find.byType(Checkbox),
    );
    await tester.tap(drawnCheckbox);
    await tester.pumpAndSettle();
    expect(drawnToggles, isNotEmpty);
    expect(drawnToggles.last.visible, isFalse);

    // Сделать «Слой 2» активным.
    final setActive = find.descendant(
      of: find.byKey(const Key('drawn-layer-Слой 2')),
      matching: find.byIcon(Icons.check_circle_outline),
    );
    await tester.tap(setActive);
    await tester.pumpAndSettle();
    expect(active, 'Слой 2');

    await tester.enterText(
        find.byKey(const Key('drawn-layer-new')), 'Новый слой');
    await tester.tap(find.byKey(const Key('drawn-layer-add')));
    await tester.pumpAndSettle();
    expect(created, ['Новый слой']);
    // Созданный слой сразу в списке и становится активным.
    expect(find.byKey(const Key('drawn-layer-Новый слой')), findsOneWidget);
    expect(find.text('активный'), findsOneWidget);
  });
}
