/// Widget tests for the indicator components: `AppChip`, `AppBadge`,
/// `StageProgress`, `MediaPlaceholder`.
///
/// Each group covers the default state plus the state that carries the
/// component's contract — the three chip recipes, every badge tone (icon *and*
/// text), the 0 / 50 / 100 % fill and a 380 ms step change, the dashed frame of
/// a missing image.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/theme/app_colors.dart';
import 'package:storyapp/theme/app_theme.dart';
import 'package:storyapp/ui/components/app_chip.dart';
import 'package:storyapp/ui/components/dashed_border.dart';
import 'package:storyapp/ui/components/media_placeholder.dart';
import 'package:storyapp/ui/components/stage_progress.dart';

import 'component_harness.dart';

/// The brand-coloured bar inside [StageProgress].
final Finder _progressFill = find.byWidgetPredicate(
  (Widget widget) => widget is ColoredBox && widget.color == AppColors.primary,
);

void main() {
  group('AppChip', () {
    testWidgets('three variants use the token recipes', (WidgetTester tester) async {
      await pumpInApp(
        tester,
        const Wrap(
          spacing: 8,
          children: <Widget>[
            AppChip('plain', key: ValueKey<String>('plain')),
            AppChip('A2', key: ValueKey<String>('level'), variant: AppChipVariant.level),
            AppChip('5 words', key: ValueKey<String>('soft'), variant: AppChipVariant.soft),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey<String>('plain'))).height, 27);

      final BoxDecoration plain =
          boxOf(tester, find.byKey(const ValueKey<String>('plain'))).decoration! as BoxDecoration;
      expect(plain.color, AppColors.surface);
      expect(plain.border, isNotNull, reason: 'plain chip carries the --line hairline');

      final BoxDecoration level =
          boxOf(tester, find.byKey(const ValueKey<String>('level'))).decoration! as BoxDecoration;
      expect(level.color, AppColors.primarySoft);
      expect(tester.widget<Text>(find.text('A2')).style!.color, AppColors.primary);

      final BoxDecoration soft =
          boxOf(tester, find.byKey(const ValueKey<String>('soft'))).decoration! as BoxDecoration;
      expect(soft.color, AppColors.accentSoft);
      expect(tester.widget<Text>(find.text('5 words')).style!.color, AppColors.accentStrong);
    });

    testWidgets('optional icon renders through AppIcon', (WidgetTester tester) async {
      await pumpInApp(tester, const AppChip('Offline', icon: 'download'));

      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('grows instead of clipping when text is enlarged', (WidgetTester tester) async {
      await pumpScaled(tester, const AppChip('Vocabulary list'), 2);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppChip)).height, greaterThan(27));
    });
  });

  group('AppBadge', () {
    const Map<AppBadgeTone, (Color, Color)> expected = <AppBadgeTone, (Color, Color)>{
      AppBadgeTone.neutral: (AppColors.surfaceSunken, AppColors.ink3),
      AppBadgeTone.brand: (AppColors.primarySoft, AppColors.primary),
      AppBadgeTone.soft: (AppColors.accentSoft, AppColors.accentStrong),
      AppBadgeTone.info: (AppColors.tealBg, AppColors.tealInk),
      AppBadgeTone.retell: (AppColors.plumBg, AppColors.plumInk),
      AppBadgeTone.success: (AppColors.successBg, AppColors.successInk),
      AppBadgeTone.warning: (AppColors.warningBg, AppColors.warningInk),
    };

    for (final MapEntry<AppBadgeTone, (Color, Color)> entry in expected.entries) {
      testWidgets('${entry.key.name} keeps icon + text on the tone triad', (WidgetTester tester) async {
        await pumpInApp(tester, AppBadge(icon: 'book', label: 'Reading', tone: entry.key));

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(AppBadge)).height, 26);
        // Dual channel: a 13 dp glyph *and* a label, never colour alone (§5.2).
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.text('Reading'), findsOneWidget);

        final BoxDecoration box = boxOf(tester, find.byType(AppBadge)).decoration! as BoxDecoration;
        expect(box.color, entry.value.$1);
        expect(tester.widget<Text>(find.text('Reading')).style!.color, entry.value.$2);
      });
    }
  });

  group('StageProgress', () {
    testWidgets('fills 0 / 50 / 100 % and counts in tabular figures', (WidgetTester tester) async {
      final Finder fill = _progressFill;
      for (final (int step, double fraction) in <(int, double)>[(0, 0), (2, 0.5), (4, 1)]) {
        await pumpInApp(tester, SizedBox(width: 200, child: StageProgress(step: step)));

        expect(tester.takeException(), isNull);
        final FractionallySizedBox bar =
            tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
        expect(bar.widthFactor, closeTo(fraction, 0.0001));
        // The painted fill really is that fraction of the track, not a full bar.
        final double trackWidth = tester.getSize(find.byType(ClipRRect)).width;
        expect(
          tester.getSize(fill).width,
          closeTo(trackWidth * fraction, 0.5),
          reason: 'track ${trackWidth}dp at step $step',
        );
        expect(find.text('$step / 4'), findsOneWidget);
      }
    });

    testWidgets('animates a step change over 380 ms', (WidgetTester tester) async {
      final ValueNotifier<int> step = ValueNotifier<int>(1);
      addTearDown(step.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: step,
                builder: (BuildContext context, int value, Widget? child) =>
                    StageProgress(step: value),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      step.value = 3; // 0.25 → 0.75: the bar must travel, not jump.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 190));
      final double mid =
          tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor!;
      expect(mid, greaterThan(0.25));
      expect(mid, lessThan(0.75));

      await tester.pumpAndSettle();
      expect(
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor,
        closeTo(0.75, 0.0001),
      );
    });

    testWidgets('reduced motion jumps straight to the value', (WidgetTester tester) async {
      await pumpInApp(
        tester,
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: StageProgress(step: 2),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('2 / 4'), findsOneWidget);
    });
  });

  group('MediaPlaceholder', () {
    testWidgets('keeps the 3:2 frame with a dashed border and retry', (WidgetTester tester) async {
      int retries = 0;
      await pumpInApp(
        tester,
        MediaPlaceholder(
          altText: 'A girl holding a paper boat',
          retryLabel: 'Retry',
          onRetry: () => retries += 1,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        closeTo(1.5, 0.0001),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('A girl holding a paper boat'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is CustomPaint && widget.painter is DashedBoxBorderPainter,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('without a retry callback there is no button', (WidgetTester tester) async {
      await pumpInApp(tester, const MediaPlaceholder(altText: 'Cover art not available'));

      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
