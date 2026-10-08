import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listening_desk/main.dart';

final saved = <String, dynamic>{
  'id': '1001',
  'title': '以前的录音',
  'createdAt': 1700000000000,
  'durationMs': 1000,
  'phase': 'ended',
  'source': 'mic',
  'pair': 'ja-zh',
  'segments': [
    {
      'id': '1:first',
      'text': '保存的原文',
      'translation': '保存的译文',
      'speaker': '1',
      'startMs': 0,
      'endMs': 1000,
    },
  ],
  'sections': [
    {
      'title': '章节标题',
      'points': [
        {'id': 's1-p1', 'text': '正文要点'},
      ],
    },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformDesk.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'settings') {
            return jsonEncode({...defaults, 'hasKey': true});
          }
          if (call.method == 'digest') {
            return jsonEncode({...saved, 'digestStatus': 'ready'});
          }
          if (call.method == 'core') return jsonEncode([saved]);
          return '{}';
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('desk/events'),
          (_) async => null,
        );
  });
  testWidgets('website primary color is exact blue', (tester) async {
    await tester.pumpWidget(const DeskApp());
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('开始录音'))).colorScheme.primary,
      const Color(0xff245ce8),
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('digest has a separate tab and only readable points', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionPanels(
            record: saved,
            settings: defaults,
            onError: (_) {},
            saved: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('保存的译文').hitTestable(), findsOneWidget);
    expect(find.text('正文要点').hitTestable(), findsNothing);
    await tester.tap(find.text('实时纪要'));
    await tester.pumpAndSettle();
    expect(find.text('正文要点').hitTestable(), findsOneWidget);
    expect(find.text('保存的译文').hitTestable(), findsNothing);
    expect(find.textContaining('s1-p1'), findsNothing);
    expect(find.textContaining('{id'), findsNothing);
    await tester.tap(find.text('双语字幕'));
    await tester.pumpAndSettle();
    expect(find.text('保存的译文').hitTestable(), findsOneWidget);
    expect(
      calls.where((c) => ['start', 'pause', 'resume', 'stop'].contains(c)),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [const Size(200, 120), const Size(400, 300)]) {
    testWidgets('floating window only has return and close controls at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const DeskApp(overlay: true));
      await tester.pumpAndSettle();
      expect(find.byType(IconButton), findsNWidgets(2));
      expect(find.byTooltip('回到应用'), findsOneWidget);
      expect(find.byTooltip('关闭悬浮字幕'), findsOneWidget);
      expect(find.byTooltip('暂停'), findsNothing);
      expect(find.byTooltip('结束并保存'), findsNothing);
      await tester.tap(find.byTooltip('关闭悬浮字幕'));
      await tester.pumpAndSettle();
      expect(calls.contains('closeOverlay'), isTrue);
      expect(calls.contains('stop'), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('history route keeps live updates and never sends stop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DeskApp());
    await tester.pumpAndSettle();
    Future<void> emit(int ms) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'desk/events',
            const StandardMethodCodec().encodeSuccessEnvelope(
              jsonEncode({
                'id': '9999',
                'phase': 'recording',
                'durationMs': ms,
                'segments': [],
                'sections': [],
              }),
            ),
            (_) {},
          );
      await tester.pumpAndSettle();
    }

    await emit(2000);
    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('以前的录音'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryDetail), findsOneWidget);
    expect(find.text('保存的译文').hitTestable(), findsOneWidget);
    await emit(10000);
    expect(find.textContaining('后台录音与翻译继续 · 00:00:10'), findsOneWidget);
    expect(calls.contains('stop'), isFalse);
    expect(calls.contains('pause'), isFalse);
    await tester.tap(find.text('返回当前录音'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryDetail), findsNothing);
    expect(find.text('00:00:10'), findsOneWidget);
    expect(calls.contains('stop'), isFalse);
    await tester.tap(find.text('停止并保存'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'stop').length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'floating controls hide during live updates and reclaim caption space',
    (tester) async {
      await tester.pumpWidget(const DeskApp(overlay: true));
      await tester.pumpAndSettle();
      final initialHeight = tester.getSize(find.byType(CaptionFeed)).height;
      for (var i = 0; i < 4; i++) {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'desk/events',
              const StandardMethodCodec().encodeSuccessEnvelope(
                jsonEncode({
                  ...saved,
                  'phase': 'recording',
                  'durationMs': i * 1000,
                }),
              ),
              (_) {},
            );
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(find.byTooltip('回到应用'), findsNothing);
      expect(find.byTooltip('关闭悬浮字幕'), findsNothing);
      expect(
        tester.getSize(find.byType(CaptionFeed)).height,
        greaterThan(initialHeight + 40),
      );
      expect(find.text('保存的译文'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byType(CaptionFeed)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('回到应用'), findsOneWidget);
      expect(find.byTooltip('关闭悬浮字幕'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.tapAt(tester.getCenter(find.byType(CaptionFeed)));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byTooltip('回到应用'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byTooltip('回到应用'), findsNothing);
      expect(
        calls.where((c) => ['start', 'pause', 'resume', 'stop'].contains(c)),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('native dragging holds controls and reopening rearms the timer', (
    tester,
  ) async {
    Future<void> notify(String method, [dynamic arguments]) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'desk/overlay',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            (_) {},
          );
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(const DeskApp(overlay: true));
    await tester.pumpAndSettle();
    await notify('interaction', true);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byTooltip('回到应用'), findsOneWidget);
    await notify('interaction', false);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byTooltip('回到应用'), findsNothing);
    await notify('shown');
    expect(find.byTooltip('回到应用'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byTooltip('回到应用'), findsNothing);
    await notify('interaction', true);
    await notify('interaction', false);
    await tester.tap(find.byTooltip('关闭悬浮字幕'));
    expect(calls.contains('closeOverlay'), isTrue);
    expect(calls.contains('stop'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
