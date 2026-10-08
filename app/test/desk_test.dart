import 'dart:convert';
import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listening_desk/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await AppStrings.load('zh');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformDesk.channel, (call) async {
          if (call.method == 'settings') {
            return jsonEncode({...defaults, 'effectiveLocale': 'zh'});
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
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(800, 360),
    const Size(1200, 800),
  ]) {
    testWidgets('adaptive interface at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const DeskApp());
      await tester.pumpAndSettle();
      expect(find.text('开始录音'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
      expect(find.text('连接与显示'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('floating interface at small size', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(296, 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DeskApp(overlay: true));
    await tester.pumpAndSettle();
    expect(find.byTooltip('关闭悬浮字幕'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final vertical in [true, false]) {
    testWidgets(
      'fold hinge avoids content (${vertical ? "vertical" : "horizontal"})',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1080, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final hinge = vertical
            ? const Rect.fromLTWH(532, 0, 16, 800)
            : const Rect.fromLTWH(0, 390, 1080, 20);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(1080, 800),
                displayFeatures: [
                  DisplayFeature(
                    bounds: hinge,
                    type: DisplayFeatureType.hinge,
                    state: DisplayFeatureState.postureHalfOpened,
                  ),
                ],
              ),
              child: DeskHome(settings: defaults, reload: () async {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (vertical) {
          for (final card in find.byType(Card).evaluate()) {
            expect(
              tester.getRect(find.byWidget(card.widget)).overlaps(hinge),
              isFalse,
            );
          }
        }
      },
    );
  }
  testWidgets('complete captions and explicit follow after scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rows = List.generate(
      1800,
      (i) => {
        'id': '$i',
        'text': '原文 $i',
        'translation': '译文 $i',
        'startMs': i * 1000,
        'speaker': '1',
      },
    );
    Widget feed() => MaterialApp(
      home: Scaffold(
        body: CaptionFeed(record: {'segments': rows}, settings: defaults),
      ),
    );
    await tester.pumpWidget(feed());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('回到底部并跟随'), findsOneWidget);
    rows.add({
      'id': '1800',
      'text': '原文 1800',
      'translation': '译文 1800',
      'startMs': 1800000,
      'speaker': '1',
    });
    await tester.pumpWidget(feed());
    await tester.pumpAndSettle();
    expect(find.text('回到底部并跟随'), findsOneWidget);
    await tester.tap(find.text('回到底部并跟随'));
    await tester.pumpAndSettle();
    expect(find.text('译文 1800'), findsOneWidget);
    expect(find.text('回到底部并跟随'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
