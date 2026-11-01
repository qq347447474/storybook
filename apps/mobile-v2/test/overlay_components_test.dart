/// Widget tests for the overlay family: the record key, the unlock panel, the
/// bottom sheet and the confirm dialog — plus the back-face speaker's hot zone.
///
/// The record-key group never calls `pumpAndSettle` while the key listens: the
/// pulse repeats for as long as the take runs, so a settle would spin forever.
/// Time is advanced explicitly instead, which is also how the hold is measured.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/theme/app_colors.dart';
import 'package:storyapp/theme/app_theme.dart';
import 'package:storyapp/ui/components/app_chip.dart';
import 'package:storyapp/ui/components/app_sheet.dart';
import 'package:storyapp/ui/components/confirm_dialog.dart';
import 'package:storyapp/ui/components/record_button.dart';
import 'package:storyapp/ui/components/unlock_panel.dart';
import 'package:storyapp/ui/components/word_card.dart';

import 'component_harness.dart';

/// Pumps [child] on the app theme, optionally with animations disabled.
///
/// `pump()` rather than `pumpAndSettle()`: the recording pulse never settles.
Future<void> pumpKey(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Pumps a screen holding one button that opens [onOpen].
Future<void> pumpLauncher(
  WidgetTester tester,
  void Function(BuildContext context) onOpen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => onOpen(context),
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

/// The 74 dp key as the S5 dock would hand it to us.
RecordButton keyOf({
  RecordState state = RecordState.idle,
  double heldSeconds = 0,
  int maxSeconds = 30,
  VoidCallback? onTooShort,
  ValueChanged<Duration>? onHoldEnd,
  VoidCallback? onTimeout,
  VoidCallback? onHoldStart,
}) {
  return RecordButton(
    state: state,
    maxSeconds: maxSeconds,
    heldSeconds: heldSeconds,
    label: 'Hold to record',
    onHoldStart: onHoldStart,
    onHoldEnd: onHoldEnd,
    onTooShort: onTooShort,
    onTimeout: onTimeout,
    processingProgress: state == RecordState.processing ? 0.4 : null,
  );
}

/// The key's own painted circle.
AnimatedContainer keyFace(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));

void main() {
  group('RecordButton', () {
    testWidgets('paints one face per state', (WidgetTester tester) async {
      await pumpKey(tester, keyOf());
      expect(
        (keyFace(tester).decoration! as BoxDecoration).color,
        AppColors.primary,
      );
      expect(iconNamed('mic'), findsOneWidget);

      await pumpKey(tester, keyOf(state: RecordState.recording, heldSeconds: 4));
      expect(
        (keyFace(tester).decoration! as BoxDecoration).color,
        AppColors.recordRed,
      );
      expect(iconNamed('pause'), findsOneWidget);

      await pumpKey(tester, keyOf(state: RecordState.processing));
      expect(
        (keyFace(tester).decoration! as BoxDecoration).color,
        AppColors.ink2,
      );

      await pumpKey(tester, keyOf(state: RecordState.disabled));
      expect(
        (keyFace(tester).decoration! as BoxDecoration).color,
        AppColors.recordDisabled,
      );
      expect(tester.widget<RecordButton>(find.byType(RecordButton)).state,
          RecordState.disabled);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap shorter than 800 ms is too short, not a take',
        (WidgetTester tester) async {
      int tooShort = 0;
      int ended = 0;
      await pumpKey(
        tester,
        keyOf(onTooShort: () => tooShort += 1, onHoldEnd: (_) => ended += 1),
      );

      final TestGesture press =
          await tester.startGesture(tester.getCenter(find.byType(RecordButton)));
      await tester.pump(const Duration(milliseconds: 400));
      await press.up();
      await tester.pump();

      expect(tooShort, 1);
      expect(ended, 0);
    });

    testWidgets('a long hold reports the duration it actually held',
        (WidgetTester tester) async {
      int tooShort = 0;
      Duration? held;
      int started = 0;
      await pumpKey(
        tester,
        keyOf(
          onHoldStart: () => started += 1,
          onTooShort: () => tooShort += 1,
          onHoldEnd: (Duration value) => held = value,
        ),
      );

      final TestGesture press =
          await tester.startGesture(tester.getCenter(find.byType(RecordButton)));
      await tester.pump();
      expect(started, 1);
      await tester.pump(const Duration(milliseconds: 1200));
      await press.up();
      await tester.pump();

      expect(tooShort, 0);
      expect(held, isNotNull);
      expect((held!.inMilliseconds - 1200).abs() < 60, isTrue,
          reason: 'reported ${held!.inMilliseconds} ms for a 1200 ms hold');
    });

    testWidgets('reaching the limit times out once, and the release is silent',
        (WidgetTester tester) async {
      int timeouts = 0;
      int ended = 0;
      await pumpKey(
        tester,
        keyOf(state: RecordState.recording, heldSeconds: 29.5, onTimeout: () => timeouts += 1),
      );
      expect(timeouts, 0);

      await pumpKey(
        tester,
        keyOf(state: RecordState.recording, heldSeconds: 30, onTimeout: () => timeouts += 1, onHoldEnd: (_) => ended += 1),
      );
      await tester.pump();
      expect(timeouts, 1);

      // Still at the limit on the next build: the limit must not fire again.
      await pumpKey(
        tester,
        keyOf(state: RecordState.recording, heldSeconds: 30, onTimeout: () => timeouts += 1),
      );
      await tester.pump();
      expect(timeouts, 1);
      expect(ended, 0);
    });

    testWidgets('the release still lands after the caller flips to recording',
        (WidgetTester tester) async {
      // The real flow: `onHoldStart` switches the key to `recording` while the
      // finger is still down. If the press handler dropped its end callback
      // there, the take would never be told to stop.
      final ValueNotifier<RecordState> state =
          ValueNotifier<RecordState>(RecordState.idle);
      Duration? held;
      await pumpKey(
        tester,
        ValueListenableBuilder<RecordState>(
          valueListenable: state,
          builder: (BuildContext context, RecordState value, Widget? child) =>
              RecordButton(
            state: value,
            maxSeconds: 30,
            label: 'Hold to record',
            onHoldStart: () => state.value = RecordState.recording,
            onHoldEnd: (Duration value) => held = value,
          ),
        ),
      );

      final TestGesture press =
          await tester.startGesture(tester.getCenter(find.byType(RecordButton)));
      await tester.pump();
      expect(state.value, RecordState.recording);
      await tester.pump(const Duration(milliseconds: 900));
      await press.up();
      await tester.pump();

      expect(held, isNotNull);
      expect((held!.inMilliseconds - 900).abs() < 60, isTrue);

      // Back to idle so no controller is left ticking at the end of the test.
      state.value = RecordState.idle;
      await tester.pump();
      state.dispose();
    });

    testWidgets('reduced motion drops the pulse but keeps the state legible',
        (WidgetTester tester) async {
      await pumpKey(
        tester,
        keyOf(state: RecordState.recording, heldSeconds: 3),
        reduceMotion: true,
      );

      // The pulse ring is keyed: AnimatedScale is a ScaleTransition inside too,
      // so the type alone cannot tell "no pulse" from "key not pressed".
      expect(find.byKey(RecordButton.pulseKey), findsNothing);
      expect(
        (keyFace(tester).decoration! as BoxDecoration).color,
        AppColors.recordRed,
      );
      // Two non-animated signals stay: the glyph and the countdown ring.
      expect(iconNamed('pause'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('UnlockPanel', () {
    testWidgets('shows the heading, the four ticked steps and one CTA',
        (WidgetTester tester) async {
      int taps = 0;
      await pumpLauncher(
        tester,
        (BuildContext context) => showUnlockPanel(
          context,
          title: '可以复述了',
          body: '你读完了这一章。这一步不计分，只看你讲到了什么。',
          steps: <String>['阅读', '生词', '测验', '复述'],
          ctaLabel: '去复述',
          onCta: () => taps += 1,
        ),
      );

      expect(find.text('可以复述了'), findsOneWidget);
      expect(find.textContaining('不计分'), findsOneWidget);
      expect(find.byType(AppChip), findsNWidgets(4));
      expect(iconNamed('check'), findsNWidgets(4));
      expect(iconNamed('unlock'), findsOneWidget);

      await tester.tap(find.text('去复述'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.text('可以复述了'), findsNothing);
    });
  });

  group('AppSheet', () {
    testWidgets('opens with a title and its child, closes on the scrim',
        (WidgetTester tester) async {
      await pumpLauncher(
        tester,
        (BuildContext context) => showAppSheet<void>(
          context,
          title: '选择章节',
          subtitle: '共 4 章',
          child: const Text('row one'),
        ),
      );

      expect(find.text('选择章节'), findsOneWidget);
      expect(find.text('共 4 章'), findsOneWidget);
      expect(find.text('row one'), findsOneWidget);
      expect(tester.getTopLeft(find.text('选择章节')).dy, greaterThan(300));

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('选择章节'), findsNothing);
    });
  });

  group('ConfirmDialog', () {
    Future<void> open(
      WidgetTester tester, {
      required VoidCallback onDeny,
      required VoidCallback onAllow,
    }) {
      return pumpLauncher(
        tester,
        (BuildContext context) => showConfirmDialog(
          context,
          title: '可以打开麦克风吗？',
          body: '复述需要录音。录音只在本机识别，不会上传。',
          denyLabel: '暂不',
          allowLabel: '允许',
          onDeny: onDeny,
          onAllow: onAllow,
        ),
      );
    }

    testWidgets('two 52 dp buttons, each reporting its own answer',
        (WidgetTester tester) async {
      int denies = 0;
      int allows = 0;
      await open(tester, onDeny: () => denies += 1, onAllow: () => allows += 1);

      expect(find.text('可以打开麦克风吗？'), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(FilledButton, '暂不')).height,
        52,
      );
      expect(
        tester.getSize(find.widgetWithText(FilledButton, '允许')).height,
        52,
      );

      await tester.tap(find.text('允许'));
      await tester.pumpAndSettle();
      expect(allows, 1);
      expect(denies, 0);
      expect(find.text('可以打开麦克风吗？'), findsNothing);
    });

    testWidgets('dismissing on the scrim counts as a denial',
        (WidgetTester tester) async {
      int denies = 0;
      int allows = 0;
      await open(tester, onDeny: () => denies += 1, onAllow: () => allows += 1);

      await tester.tapAt(const Offset(6, 6));
      await tester.pumpAndSettle();
      expect(denies, 1);
      expect(allows, 0);
    });

    testWidgets('Escape counts as a denial too', (WidgetTester tester) async {
      int denies = 0;
      int allows = 0;
      await open(tester, onDeny: () => denies += 1, onAllow: () => allows += 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(denies, 1);
      expect(allows, 0);
      expect(find.text('可以打开麦克风吗？'), findsNothing);
    });
  });

  group('WordCard back face', () {
    testWidgets('the 36 dp speaker answers on a 44 dp hot zone',
        (WidgetTester tester) async {
      int speaks = 0;
      await pumpInApp(
        tester,
        WordCard(
          word: 'tapped',
          phonetic: '/tæpt/',
          partOfSpeech: 'verb',
          revealed: true,
          definition: '轻敲；轻叩',
          frontHint: 'Tap the card for the meaning',
          backHint: 'Tap to go back',
          onSpeakExample: () => speaks += 1,
        ),
      );

      final Finder hotZone = find.ancestor(
        of: iconNamed('speaker'),
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is SizedBox &&
              w.width == WordCard.backSpeakTarget &&
              w.height == WordCard.backSpeakTarget,
        ),
      );
      expect(hotZone, findsOneWidget);
      expect(tester.getSize(hotZone), const Size.square(44));

      // 20 dp right of the centre: outside the 36 dp circle, inside the zone.
      final Offset centre = tester.getCenter(iconNamed('speaker'));
      await tester.tapAt(centre + const Offset(20, 0));
      expect(speaks, 1);
      // The tap must not also flip the card.
      expect(find.text('轻敲；轻叩'), findsOneWidget);
    });
  });
}
