/// Gloss resolution for support-language fields (decision ③).
library;

import 'package:core_content/core_content.dart';

/// Resolves a [LocalizedText]: the active gloss locale first, then the
/// pack's `defaultGloss`, then any available translation. Never returns
/// blank when at least one translation exists.
String glossOf(LocalizedText text, String glossLocale, String defaultGloss) {
  final Map<String, String> by = text.byLocale;
  return by[glossLocale] ??
      by[defaultGloss] ??
      (by.isNotEmpty ? by.values.first : '');
}
