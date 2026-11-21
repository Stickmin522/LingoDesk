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
      {
        'id': '1',
        'text': 'Source sentence',
        'translation': '正在翻译的句子',
        'speaker': '4',
      },
    ],
  };
  Map<String, dynamic> current = idle;
  Map<String, dynamic>? saved;
  bool overlay = true;
  String source = 'mic';

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
    overlay = defaults['overlay'] as bool;
    source = 'mic';
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
          return jsonEncode({
            ...defaults,
            'effectiveLocale': 'zh',
            'overlay': overlay,
            'overlayPermission': true,
            'source': source,
          });
        case 'saveSettings':
          source = args['source'] as String? ?? source;
          return '{}';
        case 'overlay':
          overlay = args['enabled'] as bool;
          return '{}';
        case 'start':
          current = {...session, 'source': source};
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
    final button = find.byTooltip(label).hitTestable();
    await tester.tap(
      button.evaluate().isEmpty ? find.text(label).hitTestable().last : button,
    );
    await tester.pumpAndSettle();
  }

  void expectControlColor(WidgetTester tester, String label, Color color) {
    final button = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == label,
      ),
    );
    expect(button.style?.foregroundColor?.resolve({}), color);
  }

  testWidgets(
    'portrait captions extend under the floating controls and can export live TXT',
    (tester) async {
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPadding);
      await home(tester);
      final colors = Theme.of(tester.element(find.byType(DeskHome)))
          .colorScheme;
      expectControlColor(tester, '开始录音', colors.primary);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(SegmentedButton<int>), findsNothing);
      final sourceSelector = find.byKey(
        const ValueKey('audio-source-selector'),
      );
      final sourceStatus = find.byKey(const ValueKey('active-audio-source'));
      final sourcePanel = tester.getRect(sourceSelector);
      expect(sourcePanel.center.dx, closeTo(160, 1));
      expect(sourcePanel.top, closeTo(30, 1));
      expect(sourceStatus, findsNothing);
      final sourceOptions = tester.widget<SegmentedButton<String>>(
        sourceSelector,
      );
      expect(sourceOptions.segments.map((segment) => segment.value), [
        'mic',
        'system',
        'both',
      ]);
      expect(sourceOptions.selected, {'mic'});
      await tap(tester, '系统内部音频');
      expect(source, 'system');
      await tap(tester, '麦克风 + 系统');
      expect(source, 'both');
      expect(tester.widget<SegmentedButton<String>>(sourceSelector).selected, {
        'both',
      });
      expect(find.text('听译台'), findsNothing);
      expect(find.text('准备就绪'), findsNothing);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
      final mic = tester.getCenter(
        find.byIcon(Icons.mic_none_rounded).hitTestable(),
      );
      expect(mic.dx, closeTo(160, 1));
      final floating = find.byKey(
        const ValueKey('floating-recording-controls'),
      );
      final idlePanel = tester.getRect(floating);
      expect(idlePanel.width, lessThan(240));
      expect(idlePanel.bottom, closeTo(592, 1));
      final scaffold = find.byType(Scaffold).first;
      final statusBar = find
          .ancestor(
            of: scaffold,
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first;
      void expectMatchingStatusBar() {
        expect(
          tester
              .widget<AnnotatedRegion<SystemUiOverlayStyle>>(statusBar)
              .value
              .statusBarColor,
          tester.widget<Scaffold>(scaffold).backgroundColor,
        );
      }

      expectMatchingStatusBar();
      final left = find.byKey(const ValueKey('language-left'));
      final right = find.byKey(const ValueKey('language-right'));
      expect(tester.getBottomLeft(left).dy, lessThan(idlePanel.top));
      expect(tester.getBottomRight(right).dy, lessThan(idlePanel.top));
      await tap(tester, '开始录音');
      expectMatchingStatusBar();
      expect(left, findsNothing);
      expect(right, findsNothing);
      expect(sourceSelector, findsNothing);
      expect(tester.widget<Text>(sourceStatus).data, '麦克风 + 系统');
      expectControlColor(tester, '暂停录音', colors.outline);
      expectControlColor(tester, '停止录音', colors.error);
      expect(find.textContaining('说话人 4'), findsOneWidget);
      final sentence = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null &&
            (widget.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(14),
      );
      for (final text in ['Source sentence', '正在翻译的句子']) {
        expect(
          find.descendant(of: sentence, matching: find.text(text)),
          findsOneWidget,
        );
      }
      final caption = find.text('正在翻译的句子').hitTestable();
      final controls = find.byTooltip('暂停录音').hitTestable();
      final pane = find.byKey(const ValueKey('portrait-pane-selector'));
      final selector = tester.getRect(pane);
      expect(selector.center.dx, closeTo(160, 1));
      expect(selector.top, closeTo(30, 1));
      expect(find.text('录音设置'), findsNothing);
      final captions = tester.getRect(find.byType(SessionPanels));
      expect(captions.top, greaterThanOrEqualTo(selector.bottom));
      expect(captions.width, closeTo(320, 1));
      final sourceLabel = tester.getRect(sourceStatus);
      expect(sourceLabel.left, closeTo(12, 1));
      expect(sourceLabel.bottom, lessThan(captions.top));
      expect(sourceLabel.bottom, lessThan(tester.getTopLeft(caption).dy));
      final recordingPanel = tester.getRect(floating);
      expect(recordingPanel.width, lessThan(320));
      expect(recordingPanel.center.dx, closeTo(160, 1));
      expect(captions.bottom, greaterThan(recordingPanel.bottom));
      expect(
        tester.getBottomLeft(caption).dy,
        lessThan(tester.getTopLeft(controls).dy),
      );
      await tap(tester, '实时纪要');
      expect(caption, findsNothing);
      await tap(tester, '双语字幕');
      expect(caption, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('capture-options')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byType(SegmentedButton<int>), findsNothing);
      final overlaySwitch = find.byKey(
        const ValueKey('floating-caption-switch'),
      );
      final scrollable = find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      final apiField = find.byType(TextField);
      expect(
        tester.widget<TextField>(apiField).decoration?.labelText,
        'API Key',
      );
      expect(tester.getBottomLeft(apiField).dy, lessThan(240));
      expect(overlaySwitch.hitTestable(), findsNothing);
      await tester.scrollUntilVisible(
        overlaySwitch,
        240,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(overlaySwitch.hitTestable(), findsOneWidget);
      expect(tester.widget<SwitchListTile>(overlaySwitch).value, isTrue);
      await tester.tap(overlaySwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(overlaySwitch).value, isFalse);
      expect(requests.where((r) => r.$1 == 'overlay').single.$2, {
        'enabled': false,
      });
      await tap(tester, '听译');
      expect(caption, findsOneWidget);
      await tap(tester, 'TXT');
      expect(requests.where((r) => r.$1 == 'export').single.$2, {
        'id': '123',
        'format': 'txt',
      });
      expect(current['phase'], 'recording');
      expect(saved, isNull);
      await tap(tester, '暂停录音');
      expect(sourceSelector, findsNothing);
      expect(tester.widget<Text>(sourceStatus).data, '麦克风 + 系统');
      expectControlColor(tester, '继续录音', colors.primary);
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

  testWidgets(
    'the last line of a long transcript stays above the floating controls',
    (tester) async {
      await home(tester);
      await tap(tester, '开始录音');
      current = {
        ...current,
        'segments': [
          for (var i = 0; i < 40; i++)
            {'id': '$i', 'text': 'Sentence $i', 'translation': '译文第 $i 句'},
        ],
      };
      await emit();
      await tester.pumpAndSettle();
      final panel = tester.getRect(
        find.byKey(const ValueKey('floating-recording-controls')),
      );
      final lastLine = find.text('译文第 39 句').hitTestable();
      expect(lastLine, findsOneWidget);
      expect(tester.getRect(lastLine).bottom, lessThan(panel.top));
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
    expect(find.byKey(const ValueKey('audio-source-selector')), findsOneWidget);
    expectControlColor(
      tester,
      '回放',
      Theme.of(tester.element(find.byType(DeskHome))).colorScheme.primary,
    );
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
