/// App-wide user settings: UI locale and gloss locale are independent
/// (decision ③, docs/08 S7), plus the reduce-motion preference.
///
/// The values persist in the progress document's `settings` block and take
/// effect immediately (no restart): listeners rebuild on every change and
/// `L10nScope` publishes the freshly loaded catalog.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/foundation.dart';

import '../i18n/app_localizations.dart';

class AppSettings extends ChangeNotifier {
  AppSettings({
    required this.store,
    required this.packId,
    required this.appVersion,
  });

  final ProgressStore store;
  final String packId;

  /// Real application version (package_info_plus in production), shown on
  /// S7 and compared against `minAppVersion`.
  String appVersion;

  /// UI copy language (i18n catalog).
  String uiLocale = 'en';

  /// Language of gloss/explanation/hint fields (independent of [uiLocale]).
  String glossLocale = 'zh-Hans';

  bool reduceMotion = false;

  /// Cached catalog for [uiLocale]; loaded on demand, never re-read.
  AppLocalizations? l10n;

  /// Loads persisted settings; defaults stay in place when nothing saved.
  Future<void> load() async {
    final ProgressDoc doc = await store.load(packId);
    uiLocale = doc.settings.uiLocale;
    glossLocale = doc.settings.glossLocale;
    reduceMotion = doc.settings.reduceMotion;
    l10n = await AppLocalizations.load(uiLocale);
    notifyListeners();
  }

  /// Switches the UI language and takes effect immediately (no restart).
  Future<void> setUiLocale(String tag) async {
    if (tag == uiLocale) return;
    uiLocale = tag;
    l10n = await AppLocalizations.load(tag);
    notifyListeners();
    await _persist();
  }

  /// Switches the gloss language independently of [uiLocale] (decision ③).
  Future<void> setGlossLocale(String tag) async {
    if (tag == glossLocale) return;
    glossLocale = tag;
    notifyListeners();
    await _persist();
  }

  Future<void> setReduceMotion(bool value) async {
    if (value == reduceMotion) return;
    reduceMotion = value;
    notifyListeners();
    await _persist();
  }

  /// Saves only the settings block; chapter progress written by
  /// ReadingController is preserved (fresh load, field-level replace).
  Future<void> _persist() async {
    final ProgressDoc doc = await store.load(packId);
    doc.settings = ProgressSettings(
      uiLocale: uiLocale,
      glossLocale: glossLocale,
      reduceMotion: reduceMotion,
    );
    await store.save(doc);
  }
}
