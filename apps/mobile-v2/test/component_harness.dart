/// Shared helpers for the `lib/ui/components/` widget tests.
///
/// Not a test file: it is imported by the three component suites so each one
/// stays inside the 300-line budget while still pumping through the real app
/// theme (`buildAppTheme()`), on a 360 dp column — the baseline canvas of
/// design-spec §2.4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/theme/app_theme.dart';
import 'package:storyapp/ui/app_icon.dart';
import 'package:storyapp/ui/components/app_toast.dart';

/// Pumps [child] inside the app theme, on a scrollable 360 dp column.
Future<void> pumpInApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 360, child: Center(child: child)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps [child] with an enlarged text scale, to prove nothing clips.
Future<void> pumpScaled(WidgetTester tester, Widget child, double scale) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 360, child: Center(child: child)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The `Container` a component paints its background with.
Container boxOf(WidgetTester tester, Finder scope) {
  return tester.widget<Container>(
    find.descendant(of: scope, matching: find.byType(Container)).first,
  );
}

/// True when an [AppIcon] named [name] is on screen — the icon set is chosen
/// by name, so a test asserts semantics rather than a widget type.
Finder iconNamed(String name) =>
    find.byWidgetPredicate((Widget widget) => widget is AppIcon && widget.name == name);

/// True when some rich-text run of [text] is painted in [color].
bool hasRun(WidgetTester tester, String text, Color color) {
  bool found = false;
  for (final RichText rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text == text && span.style?.color == color) {
        found = true;
        return false;
      }
      return true;
    });
  }
  return found;
}

/// The style of the rich-text run that renders exactly [text], or null.
TextStyle? runStyle(WidgetTester tester, String text) {
  for (final RichText rich in tester.widgetList<RichText>(find.byType(RichText))) {
    TextStyle? found;
    rich.text.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text == text) {
        found = span.style;
        return false;
      }
      return true;
    });
    if (found != null) return found;
  }
  return null;
}

/// A `MaterialApp` whose only button shows a toast, so the overlay is reachable.
Widget toastHost(String message) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => Center(
          child: TextButton(
            onPressed: () => showAppToast(context, message),
            child: const Text('show'),
          ),
        ),
      ),
    ),
  );
}

/// Two toast buttons — for the "a second toast replaces the first" case.
Widget toastPairHost(String first, String second) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextButton(
                onPressed: () => showAppToast(context, first),
                child: const Text('one'),
              ),
              TextButton(
                onPressed: () => showAppToast(context, second),
                child: const Text('two'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
