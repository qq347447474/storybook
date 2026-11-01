/// Minimal app localizations: loads UI copy from the generated
/// `assets/i18n/*.json` files (single source of truth: `/i18n` at the repo
/// root, kept in sync by `scripts/sync_assets.py`).
///
/// C4: user-visible copy never lives in Dart code; callers look keys up with
/// [t]. Unknown keys fall back to the key itself — never blank (docs/08 §3.2).
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.localeTag, this._values);

  /// Locale tag of the loaded catalog, e.g. `en`, `zh-Hans`, `qps-ploc`.
  final String localeTag;
  final Map<String, String> _values;

  /// Locale tags with a catalog in `/i18n`.
  static const List<String> supportedTags = <String>['en', 'zh-Hans', 'qps-ploc'];

  /// Loaded catalogs by tag (switching languages must not re-read assets).
  static final Map<String, AppLocalizations> _cache = <String, AppLocalizations>{};

  /// Loads the catalog for [localeTag] from `assets/i18n/<tag>.json`.
  /// Results are cached; repeated calls return the same instance.
  static Future<AppLocalizations> load(
    String localeTag, {
    AssetBundle? bundle,
  }) async {
    final AppLocalizations? cached = _cache[localeTag];
    if (cached != null) return cached;
    final String raw =
        await (bundle ?? rootBundle).loadString('assets/i18n/$localeTag.json');
    final Map<String, dynamic> json =
        jsonDecode(raw) as Map<String, dynamic>;
    json.remove('_meta');
    final values = <String, String>{};
    json.forEach((String key, dynamic value) {
      if (value is String) values[key] = value;
    });
    final AppLocalizations l10n = AppLocalizations(localeTag, values);
    _cache[localeTag] = l10n;
    return l10n;
  }

  /// Already-loaded catalog for [localeTag], or null when never loaded.
  static AppLocalizations? cached(String localeTag) => _cache[localeTag];

  /// Returns the copy for [key]; falls back to the key name itself.
  /// `{name}` placeholders are substituted from [args] (callers pass
  /// formatted numbers, never language copy).
  String t(String key, {Map<String, Object> args = const <String, Object>{}}) {
    var value = _values[key] ?? key;
    args.forEach((String name, Object replacement) {
      value = value.replaceAll('{$name}', '$replacement');
    });
    return value;
  }
}

/// Publishes the active [AppLocalizations] down the tree. Language switches
/// swap the instance and rebuild every dependent route without a restart
/// (docs/08 S7).
class L10nScope extends InheritedWidget {
  const L10nScope({super.key, required this.l10n, required super.child});

  final AppLocalizations l10n;

  static AppLocalizations of(BuildContext context) {
    final L10nScope? scope =
        context.dependOnInheritedWidgetOfExactType<L10nScope>();
    assert(scope != null, 'L10nScope is missing above this context');
    return scope!.l10n;
  }

  @override
  bool updateShouldNotify(L10nScope oldWidget) => oldWidget.l10n != l10n;
}

/// Minimal delegate wiring [AppLocalizations] into `MaterialApp`.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedTags.contains(locale.toLanguageTag());

  @override
  Future<AppLocalizations> load(Locale locale) =>
      AppLocalizations.load(locale.toLanguageTag());

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
