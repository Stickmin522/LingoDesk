import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listening_desk/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final requests = <(String, Map<String, dynamic>)>[];
  const idle = {'phase': 'idle', 'segments': [], 'sections': []};
  const session = {
    'id': '123',
    'title': '临时录音',
    'pendingSave': true,
    'createdAt': 1700000000000,
    'durationMs': 2000,
    'phase': 'recording',
    'sections': [],
    'segments': [
      {'id': '1', 'text': 'Source sentence', 'translation': '正在翻译的句子'},
    ],
  };
  Map<String, dynamic> current = idle;
  Map<String, dynamic>? saved;

  Future<void> emit() async {
    await messenger.handlePlatformMessage(
      'desk/events',
      const StandardMethodCodec().encodeSuccessEnvelope(jsonEncode(current)),
      (_) {},
    );
  }

  setUp(() async {
    await AppStrings.load('zh');
    requests.clear();
    current = idle;
    saved = null;
    messenger.setMockMethodCallHandler(
      const MethodChannel('desk/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(PlatformDesk.channel, (call) async {
      final args = Map<String, dynamic>.from(
        jsonDecode(call.arguments as String) as Map,
      );
      requests.add((call.method, args));
      switch (call.method) {
        case 'settings':
          return jsonEncode({...defaults, 'effectiveLocale': 'zh'});
        case 'start':
          current = session;
        case 'pause':
          current = {...current, 'phase': 'paused'};
        case 'resume':
          current = {...current, 'phase': 'recording'};
        case 'stop':
          current = {...current, 'phase': 'ended'};
        case 'export':
          return '{"saved":true}';
        case 'core':
          switch (args['op']) {
            case 'list':
              return jsonEncode([?saved]);
            case 'saveRecording':
              saved = {...current, 'pendingSave': false};
              current = saved!;
              await emit();
              return jsonEncode(current);
            case 'discardRecording':
              current = idle;
              await emit();
              return '{"discarded":true}';
          }
          return '{}';
        default:
          return '{}';
      }
      await emit();
      return '{}';
    });
  });

  Future<void> home(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const DeskApp());
    await tester.pumpAndSettle();
    await emit();
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).hitTestable().last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'portrait controls are beneath the captions and TXT does not stop or save the session',
    (tester) async {
      await home(tester);
      final mic = tester.getCenter(
        find.byIcon(Icons.mic_rounded).hitTestable(),
      );
      expect(mic.dx, closeTo(160, 1));
      await tap(tester, '开始录音');
      final caption = find.text('正在翻译的句子').hitTestable();
      final controls = find.text('暂停录音').hitTestable();
      expect(
        tester.getBottomLeft(caption).dy,
        lessThan(tester.getTopLeft(controls).dy),
      );
      await tap(tester, 'TXT');
      expect(requests.where((r) => r.$1 == 'export').single.$2, {
        'id': '123',
        'format': 'txt',
      });
      expect(current['phase'], 'recording');
      expect(saved, isNull);
      await tap(tester, '暂停录音');
      expect(
        find.byIcon(Icons.play_arrow_rounded).hitTestable(),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.stop_rounded).hitTestable(), findsOneWidget);
      await tap(tester, '继续录音');
      expect(current['phase'], 'recording');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('stopping holds a draft until the user saves or discards it', (
    tester,
  ) async {
    await home(tester);
    await tap(tester, '开始录音');
    await tap(tester, '停止录音');
    expect(find.text('录音尚未保存'), findsOneWidget);
    expect(saved, isNull);
    await tap(tester, '记录');
    expect(find.text('临时录音'), findsNothing);
    await tap(tester, '听译');
    await tap(tester, '放弃');
    expect(find.text('正在翻译的句子'), findsNothing);
    expect(saved, isNull);
    await tap(tester, '开始录音');
    await tap(tester, '停止录音');
    await tap(tester, '保存');
    expect(
      requests.where((r) => r.$2['op'] == 'saveRecording').single.$2['id'],
      '123',
    );
    await tap(tester, '记录');
    expect(find.text('临时录音'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('back from a stopped draft discards it before leaving the app', (
    tester,
  ) async {
    var exited = false;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exited = true;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await home(tester);
    await tap(tester, '开始录音');
    await tap(tester, '停止录音');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exited, isTrue);
    expect(current, idle);
    expect(saved, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
