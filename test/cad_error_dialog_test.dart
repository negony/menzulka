import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/services/cad_conversion_exception.dart';
import 'package:menzulka/widgets/cad_error_dialog.dart';

void main() {
  Future<void> showDialogFor(
    WidgetTester tester,
    CadConversionException error,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    CadErrorDialog.show(context, error, fileName: 'план.dwg'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('неподдерживаемая версия: объяснение и способ решения',
      (tester) async {
    await showDialogFor(
      tester,
      const CadConversionException(2, 'версия новее'),
    );

    expect(find.byKey(const Key('cad-error-dialog')), findsOneWidget);
    expect(find.text('Формат DWG новее поддерживаемого'), findsOneWidget);
    expect(find.textContaining('AutoCAD 2018'), findsOneWidget);
    expect(find.textContaining('план.dwg'), findsOneWidget);
    expect(find.byKey(const Key('cad-error-hint')), findsOneWidget);
    expect(find.textContaining('Код: 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cad-error-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cad-error-dialog')), findsNothing);
  });

  testWidgets('защищённый паролем файл: отдельный заголовок', (tester) async {
    await showDialogFor(
      tester,
      const CadConversionException(4, 'decrypt error'),
    );
    expect(find.text('Чертёж защищён паролем'), findsOneWidget);
    expect(find.textContaining('Снимите защиту'), findsOneWidget);
  });

  testWidgets('отсутствие модуля: подсказка про сборку', (tester) async {
    await showDialogFor(
      tester,
      const CadConversionException(
        CadConversionException.codeUnavailable,
        'нет библиотеки',
      ),
    );
    expect(find.text('Модуль DWG недоступен'), findsOneWidget);
    expect(find.textContaining('DXF открываются как обычно'), findsOneWidget);
  });
}
