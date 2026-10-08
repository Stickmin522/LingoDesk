import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listening_desk/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String selectedLocale = 'en';
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformDesk.channel, (call) async {
          if (call.method == 'settings') {
            return jsonEncode({
              ...defaults,
              'effectiveLocale': selectedLocale,
              'uiLanguage': selectedLocale,
            });
          }
          if (call.method == 'core') return '[]';
          return '{}';
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('desk/events'),
          (_) async => null,
        );
  });
  test('all service languages have complete lightweight catalogs', () async {
    await AppStrings.initialize();
    expect(AppStrings.languages.length, 60);
    expect(AppStrings.languages.map((l) => l.code).toSet().length, 60);
    final english =
        jsonDecode(await rootBundle.loadString('assets/i18n/en.json')) as Map;
    for (final language in AppStrings.languages) {
      final translated = jsonDecode(
        await rootBundle.loadString('assets/i18n/${language.code}.json'),
      ) as Map;
      expect(
        translated.keys.toSet(),
        english.keys.toSet(),
        reason: language.code,
      );
      expect(
        translated.values.every((v) => v is String && v.trim().isNotEmpty),
        isTrue,
        reason: language.code,
      );
    }
  });
  testWidgets(
    'language picker excludes the other side and searches all languages',
    (tester) async {
      await tester.runAsync(() => AppStrings.load('en'));
      String? selection;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LanguageField(
              value: 'ja',
              label: 'Language 1',
              exclude: 'zh',
              onChanged: (v) => selection = v,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      final duplicate = tester.widget<ListTile>(
        find.byKey(const ValueKey('language-zh')),
      );
      expect(duplicate.enabled, isFalse);
      expect(duplicate.onTap, isNull);
      await tester.enterText(find.byType(TextField), 'Welsh');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-cy')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-cy')));
      await tester.pumpAndSettle();
      expect(selection, 'cy');
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'caption direction follows its content independently of the interface',
    () {
      expect(contentDirection('مرحبا بكم'), TextDirection.rtl);
      expect(contentDirection('שלום'), TextDirection.rtl);
      expect(contentDirection('Hello'), TextDirection.ltr);
      expect(contentDirection('こんにちは'), TextDirection.ltr);
    },
  );
  testWidgets('all 60 interfaces fit a small phone and floating window', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(AppStrings.initialize);
    for (final language in AppStrings.languages) {
      selectedLocale = language.code;
      await tester.runAsync(() => AppStrings.load(selectedLocale));
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(DeskApp(key: ValueKey('main-$selectedLocale')));
      await tester.pumpAndSettle();
      expect(find.text(tr('开始录音')), findsOneWidget, reason: selectedLocale);
      expect(tester.takeException(), isNull, reason: '$selectedLocale main');
      final homeContext = tester.element(find.byType(DeskHome));
      expect(
        Directionality.of(homeContext),
        AppStrings.rtl ? TextDirection.rtl : TextDirection.ltr,
      );
      await tester.tap(find.byTooltip(tr('录音设置')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-right')), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '$selectedLocale controls',
      );
      Navigator.of(tester.element(find.byKey(const ValueKey('language-left'))))
          .pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('设置')).last);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$selectedLocale settings',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(200, 120);
      await tester.pumpWidget(
        DeskApp(key: ValueKey('overlay-$selectedLocale'), overlay: true),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip(tr('回到应用')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$selectedLocale overlay');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
