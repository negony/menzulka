import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/annotation.dart';
import 'package:menzulka/screens/create_annotation_sheet.dart';

void main() {
  Future<Annotation?> pumpSheet(
    WidgetTester tester, {
    double x = 1234.5678,
    double y = 5678.9012,
  }) async {
    // Большая поверхность, чтобы блок «Координаты и детали» был в видимой части.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Annotation? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateAnnotationSheet(
            drawingId: 'd1',
            dxfX: x,
            dxfY: y,
            annotationNumber: 1,
            units: 'm',
            onSaved: (a) => saved = a,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets(
      'координаты — в блоке «Координаты и детали», поля X/Y редактируемые',
      (tester) async {
    await pumpSheet(tester);

    // Заголовок — «Точка №» + редактируемый номер, без координат в углу.
    expect(find.text('Точка №'), findsOneWidget);
    expect(find.text('1234.57, 5678.90'), findsNothing);

    // Номер точки можно изменить: поле заполнено предложенным номером.
    final numberField = find.byKey(const Key('point-number'));
    expect(numberField, findsOneWidget);
    expect(tester.widget<TextField>(numberField).controller!.text, '1');

    // Блок развёрнут, поля X и Y заполнены координатами точки.
    expect(find.text('Координаты и детали'), findsOneWidget);
    final xField = find.byKey(const Key('point-x'));
    final yField = find.byKey(const Key('point-y'));
    expect(xField, findsOneWidget);
    expect(yField, findsOneWidget);
    expect(tester.widget<TextField>(xField).controller!.text, '1234.568');
    expect(tester.widget<TextField>(yField).controller!.text, '5678.901');

    // Нет «Гео X»/«Гео Y», «Высота Z» остаётся.
    expect(find.text('Гео X'), findsNothing);
    expect(find.text('Гео Y'), findsNothing);
    expect(find.text('Высота Z'), findsOneWidget);
  });

  testWidgets('изменённые X/Y сохраняются в точке (гео-координат нет)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Annotation? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateAnnotationSheet(
            drawingId: 'd1',
            dxfX: 10,
            dxfY: 20,
            annotationNumber: 2,
            units: 'm',
            onSaved: (a) => saved = a,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('point-x')), '1050.5');
    await tester.enterText(find.byKey(const Key('point-y')), '-230.25');
    await tester.enterText(find.byKey(const Key('point-number')), '77');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.number, 77, reason: 'номер точки задаётся пользователем');
    expect(saved!.dxfX, 1050.5);
    expect(saved!.dxfY, -230.25);
    expect(saved!.geoX, isNull);
    expect(saved!.geoY, isNull);
  });
}
