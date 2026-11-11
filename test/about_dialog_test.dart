import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:menzulka/app_info.dart';
import 'package:menzulka/widgets/about_dialog.dart';

void main() {
  Future<PackageInfo> fakeInfo() async => PackageInfo(
        appName: 'Мензулка (тест)',
        packageName: 'ru.menzulka.app',
        version: '1.16.2',
        buildNumber: '48',
      );

  test('AppInfo.versionLabel: варианты версии', () {
    expect(AppInfo.versionLabel('1.16.2', '48'), '1.16.2 (сборка 48)');
    expect(AppInfo.versionLabel('1.16.2', ''), '1.16.2');
    expect(AppInfo.versionLabel('', ''), '—');
    expect(AppInfo.githubUrl, startsWith('https://github.com/'));
  });

  testWidgets('окно «О программе»: название, версия и ссылка на GitHub',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AboutAppDialog(infoLoader: fakeInfo)),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about-dialog')), findsOneWidget);
    expect(find.text('Мензулка'), findsOneWidget);
    expect(find.textContaining('1.16.2'), findsOneWidget);
    expect(find.textContaining('сборка 48'), findsOneWidget);
    expect(find.byKey(const Key('about-github-url')), findsOneWidget);
    expect(find.text(AppInfo.githubUrl), findsOneWidget);
    expect(find.byKey(const Key('about-close')), findsOneWidget);
  });

  testWidgets('кнопка «Закрыть» закрывает окно', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AboutAppDialog(infoLoader: fakeInfo),
              ),
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('about-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-dialog')), findsNothing);
  });
}
