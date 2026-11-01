/// Smoke test for the Phase 2A asset pipeline: the 34 sprite icons in
/// `assets/icons/` and the 4 illustrations in `assets/visual/`.
///
/// Four layers, cheapest first:
/// 1. the name lists stay in sync with the files on disk (catches a forgotten
///    extract or a renamed symbol);
/// 2. every asset is declared in pubspec and loads non-empty from rootBundle
///    (catches a missing `assets:` entry — a directory is not recursive);
/// 3. every asset compiles with the exact parser flutter_svg runs at runtime
///    (catches unsupported SVG elements, which flutter_svg swallows silently
///    into its errorBuilder instead of throwing);
/// 4. every widget builds and paints an SvgPicture in the tree.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/theme/app_colors.dart';
import 'package:storyapp/ui/app_icon.dart';
import 'package:storyapp/ui/app_illustration.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vgc;

const double _frameWidth = 300;

Future<void> _pumpIcon(WidgetTester tester, AppIcon icon) async {
  await tester.pumpWidget(
    Directionality(textDirection: TextDirection.ltr, child: Center(child: icon)),
  );
  // The SVG is compiled on the first frame; in debug mode flutter_svg does
  // that synchronously, so one settle is enough for the picture to paint.
  await tester.pumpAndSettle();
}

Future<void> _pumpFrame(WidgetTester tester, AppIllustration art) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: _frameWidth, child: art)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Reads an asset and returns its text, or fails with the path that is wrong.
Future<String> _readAsset(String path) async {
  final ByteData data = await rootBundle.load(path);
  expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
  return utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('icon set', () {
    // 34 symbols come from the prototype sprite; `grid` and `list` were added
    // for the S0 shelf view switch, which the hand-off renders with its own
    // inline glyphs.
    test('ships the 36 symbols of the prototype sprite', () {
      expect(AppIcon.names.length, 36);
      expect(AppIcon.names.toSet().length, 36, reason: 'duplicate icon name');
    });

    test('every icon asset exists, is declared and compiles', () async {
      for (final String name in AppIcon.names) {
        final String xml = await _readAsset(AppIcon.assetPath(name));
        expect(xml, contains('<svg'), reason: '$name.svg is not an SVG document');
        // Same parser and same options the runtime loader uses: flutter_svg
        // disables all three optimizers, so path-ops is never entered here.
        expect(
          () => vgc.parseWithoutOptimizers(xml, warningsAsErrors: true),
          returnsNormally,
          reason: '${AppIcon.assetPath(name)} failed to compile',
        );
      }
    });

    for (final String name in AppIcon.names) {
      testWidgets('AppIcon($name) builds and paints', (WidgetTester tester) async {
        await _pumpIcon(tester, AppIcon(name));

        expect(tester.takeException(), isNull);
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(tester.getSize(find.byType(AppIcon)), const Size(24, 24));
      });
    }

    testWidgets('size, colour and semantics arguments are honoured', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await _pumpIcon(
        tester,
        const AppIcon(
          'play',
          size: AppIconSize.md,
          color: AppColors.primary,
          semanticLabel: 'Play story',
        ),
      );

      expect(tester.getSize(find.byType(AppIcon)), const Size(20, 20));
      final SvgPicture picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        picture.colorFilter,
        const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
      );
      expect(find.bySemanticsLabel('Play story'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('decorative by default', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await _pumpIcon(tester, const AppIcon('settings'));

      expect(find.byType(Semantics), findsNothing);
      // No colour argument means the body ink token, never a literal.
      final SvgPicture picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        picture.colorFilter,
        const ColorFilter.mode(AppColors.ink, BlendMode.srcIn),
      );
      handle.dispose();
    });

    testWidgets('an unknown name asserts in debug instead of loading', (WidgetTester tester) async {
      await _pumpIcon(tester, const AppIcon('not-a-real-icon'));

      expect(tester.takeException(), isAssertionError);
    });
  });

  group('illustrations', () {
    test('every illustration asset exists, is declared and compiles', () async {
      for (final String name in AppIllustration.names) {
        final String xml = await _readAsset(AppIllustration.assetPath(name));
        expect(xml, contains('<svg'), reason: '$name is not an SVG document');
        expect(
          () => vgc.parseWithoutOptimizers(xml, warningsAsErrors: true),
          returnsNormally,
          reason: '${AppIllustration.assetPath(name)} failed to compile',
        );
      }
    });

    for (final String name in AppIllustration.names) {
      testWidgets('AppIllustration($name) builds and paints', (WidgetTester tester) async {
        await _pumpFrame(tester, AppIllustration(name));

        expect(tester.takeException(), isNull);
        expect(find.byType(SvgPicture), findsOneWidget);
        // Default frame is the 3:2 cover ratio, filled edge to edge.
        expect(tester.getSize(find.byType(SvgPicture)), const Size(_frameWidth, 200));
      });
    }

    testWidgets('aspectRatio overrides the default frame', (WidgetTester tester) async {
      await _pumpFrame(
        tester,
        const AppIllustration('scene-rain-window', aspectRatio: AppIllustration.sceneAspectRatio),
      );

      expect(
        tester.getSize(find.byType(SvgPicture)),
        Size(_frameWidth, _frameWidth * 9 / 16),
      );
    });
  });
}
