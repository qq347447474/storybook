/// Settings screen (S7) + AppSettings tests: uiLocale and glossLocale are
/// independent (decision ③), the picker sheet applies a choice immediately
/// without a restart, reduceMotion persists, and the offline card reports the
/// content as ready.
library;

import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/settings/app_settings.dart';
import 'package:storyapp/settings/settings_screen.dart';

Future<AppSettings> makeSettings(Directory tmp) async {
  final settings = AppSettings(
    store: FileProgressStore(directory: tmp.path),
    packId: 'the-paper-boat',
    appVersion: '9.9.9',
  );
  await settings.load();
  return settings;
}

Widget wrap(Widget child) => MaterialApp(home: child);

/// Narrow-phone harness: 360 × 740 dp with a text scale override applied
/// *above* the screen but *below* [MaterialApp] (which installs its own
/// MediaQuery from the view).
Widget wrapNarrow(Widget child, {required double textScale}) {
  return MaterialApp(
    builder: (BuildContext context, Widget? nav) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: nav!,
    ),
    home: child,
  );
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('settings_screen_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('uiLocale and glossLocale switch independently (decision 3)',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final settings = await makeSettings(tmp);
    expect(settings.uiLocale, 'en');
    expect(settings.glossLocale, 'zh-Hans');

    await settings.setUiLocale('zh-Hans');
    expect(settings.uiLocale, 'zh-Hans');
    expect(settings.glossLocale, 'zh-Hans', reason: 'gloss unaffected');

    await settings.setGlossLocale('en');
    expect(settings.glossLocale, 'en');
    expect(settings.uiLocale, 'zh-Hans', reason: 'ui unaffected');

    // S7 dropdowns drive the same settings.
    await tester.pumpWidget(wrap(SettingsScreen(
      settings: settings,
      glossLocales: const <String>['zh-Hans', 'en'],
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('Word meaning language'), findsOneWidget);
  });

  testWidgets('uiLocale switch takes effect immediately without restart',
      (WidgetTester tester) async {
    // Prime both catalogs (real asset IO needs runAsync in widget tests).
    await tester.runAsync(() => AppLocalizations.load('en'));
    await tester.runAsync(() => AppLocalizations.load('qps-ploc'));
    final settings = await makeSettings(tmp);

    Widget probe() => ListenableBuilder(
          listenable: settings,
          builder: (BuildContext context, Widget? _) {
            final AppLocalizations l10n = settings.l10n ??
                AppLocalizations('en', const <String, String>{});
            return L10nScope(
              l10n: l10n,
              child: MaterialApp(
                home: Builder(
                  builder: (BuildContext context) => Scaffold(
                    body: Text(
                      L10nScope.of(context).t('quiz.correct'),
                      key: const Key('probe'),
                    ),
                  ),
                ),
              ),
            );
          },
        );

    await tester.pumpWidget(probe());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('probe')), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);

    await settings.setUiLocale('qps-ploc'); // no pumpWidget re-create
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsNothing);
    expect(find.text('⟦Çóŕŕéçţ··⟧'), findsOneWidget,
        reason: 'same widget tree now renders ploc copy');
  });

  testWidgets('reduceMotion switch persists across reloads',
      (WidgetTester tester) async {
    await tester.runAsync(() => AppLocalizations.load('en'));
    final settings = await makeSettings(tmp);
    await tester.pumpWidget(wrap(SettingsScreen(
      settings: settings,
      glossLocales: const <String>['zh-Hans', 'en'],
      l10n: settings.l10n,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-reduce-motion')));
    await tester.pumpAndSettle();
    expect(settings.reduceMotion, isTrue);

    // The control reflects the stored preference, not its own local state.
    final Switch control =
        tester.widget<Switch>(find.byKey(const Key('settings-reduce-motion')));
    expect(control.value, isTrue);

    final reloaded = await makeSettings(tmp);
    expect(reloaded.reduceMotion, isTrue, reason: 'persisted to progress doc');
  });

  testWidgets('version row shows the real app version', (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final settings = await makeSettings(tmp);
    await tester.pumpWidget(wrap(SettingsScreen(
      settings: settings,
      glossLocales: const <String>['zh-Hans', 'en'],
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Version 9.9.9'), findsOneWidget);
  });

  testWidgets('offline card carries the content-ready badge',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final settings = await makeSettings(tmp);
    await tester.pumpWidget(wrap(SettingsScreen(
      settings: settings,
      glossLocales: const <String>['zh-Hans', 'en'],
      l10n: l10n,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-offline-card')), findsOneWidget);
    expect(find.text('Built offline'), findsOneWidget);
    expect(find.text('Content ready'), findsOneWidget);
  });

  testWidgets('gloss language switches through the picker sheet alone',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final settings = await makeSettings(tmp);
    await settings.setUiLocale('zh-Hans');
    expect(settings.glossLocale, 'zh-Hans');

    await tester.pumpWidget(wrap(SettingsScreen(
      settings: settings,
      glossLocales: const <String>['zh-Hans', 'en'],
      l10n: l10n,
    )));
    await tester.pumpAndSettle();

    // The row opens a listbox sheet instead of an inline dropdown.
    await tester.tap(find.byKey(const Key('settings-row-gloss-locale')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings-locale-option-zh-Hans')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings-locale-option-en')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-locale-option-en')));
    await tester.pumpAndSettle();

    expect(settings.glossLocale, 'en', reason: 'applied on tap, no save step');
    expect(settings.uiLocale, 'zh-Hans', reason: 'interface language unchanged');
  });

  testWidgets('S7 lays out on a 360 dp phone at 130% text scale',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final settings = await makeSettings(tmp);
    await tester.pumpWidget(wrapNarrow(
      SettingsScreen(
        settings: settings,
        glossLocales: const <String>['zh-Hans', 'en'],
        l10n: l10n,
      ),
      textScale: 1.3,
    ));
    await tester.pumpAndSettle();

    // The badge row is the tight spot: title + status pill on one line.
    expect(tester.takeException(), isNull);

    // The picker sheet must fit the same viewport. `ListView(children:)` builds
    // lazily, so at 130 % text the row may not exist yet — scroll it into
    // range instead of assuming it is already mounted.
    final Finder glossRow = find.byKey(const Key('settings-row-gloss-locale'));
    await tester.scrollUntilVisible(
      glossRow,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(glossRow);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-locale-option-en')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
