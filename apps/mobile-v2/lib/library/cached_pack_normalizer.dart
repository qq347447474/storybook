/// Repair pass over a cached `pack.json` before it reaches the parser.
///
/// Books downloaded from the book server are authored per title, so their
/// `pack.json` often carries only the fields the author cared about: no
/// `schemaVersion`, `locales.content` as a bare string, and a `level` block
/// without the derived readability statistics. The parser treats every one of
/// those as a hard error and drops the book, which used to leave a downloaded
/// book invisible in the shelf.
///
/// This module owns the repair in one place so the boot path and the settings
/// sheet cannot drift apart: [normalizeCachedPack] rewrites the envelope in
/// memory and [isPackShaped] answers "would the parser accept this?" without
/// pulling in `core_content`.
library;

/// Fields every `pack.json` must declare for `parsePack` to succeed.
const int _schemaVersion = 1;
const String _minAppVersion = '1.0.0';
const String _fallbackContentVersion = '1.0.0';

/// Reading speed assumed per CEFR band when the pack ships no `targetWpm`.
const Map<String, int> _cefrWpm = <String, int>{
  'A1': 80,
  'A2': 100,
  'B1': 120,
  'B2': 140,
  'C1': 150,
};

/// `level` keys the parser requires to be present with the right type.
const List<String> _requiredLevelInts = <String>['wordCount', 'targetWpm'];
const List<String> _requiredLevelNums = <String>[
  'avgSentenceLen',
  'ttr',
  'newWordDensity',
];

final RegExp _wordPattern = RegExp(r"[A-Za-z][A-Za-z'-]*");

/// Coerce a scalar or list locale declaration into a non-empty tag list.
List<String> localeTags(Object? raw, String first, {String? extra}) {
  final List<String> fallback = <String>[first, ?extra];
  if (raw is List) {
    final List<String> tags = raw
        .whereType<String>()
        .where((String tag) => tag.isNotEmpty)
        .toList();
    if (tags.isNotEmpty) return tags;
  }
  if (raw is String && raw.isNotEmpty) return <String>[raw, ?extra];
  return fallback;
}

/// Rewrite [raw] so the content parser accepts it.
///
/// Returns the repaired map; the input is not mutated. Callers compare against
/// the original to decide whether to write the file back.
Map<String, dynamic> normalizeCachedPack(Map<String, dynamic> raw) {
  final Map<String, dynamic> data = Map<String, dynamic>.from(raw);

  data.putIfAbsent('schemaVersion', () => _schemaVersion);
  data.putIfAbsent('minAppVersion', () => _minAppVersion);
  data.putIfAbsent('contentVersion', () => _fallbackContentVersion);
  data['locales'] = _normalizedLocales(data['locales']);
  data['books'] = _normalizedBooks(data['books']);
  return data;
}

/// True when [data] already satisfies every field the parser requires.
bool isPackShaped(Map<String, dynamic> data) {
  if (data['schemaVersion'] is! int) return false;
  if (data['minAppVersion'] is! String) return false;

  final Object? locales = data['locales'];
  if (locales is! Map) return false;
  if (locales['content'] is! List || (locales['content'] as List).isEmpty) {
    return false;
  }
  if (locales['gloss'] is! List || (locales['gloss'] as List).isEmpty) {
    return false;
  }

  final Object? books = data['books'];
  if (books is! List || books.isEmpty) return false;

  for (final Object? book in books) {
    if (book is! Map) return false;
    final Object? level = book['level'];
    if (level is! Map) return false;
    if (level['cefr'] is! String) return false;
    for (final String key in _requiredLevelInts) {
      if (level[key] is! int) return false;
    }
    for (final String key in _requiredLevelNums) {
      if (level[key] is! num) return false;
    }
    final Object? chapters = book['chapters'];
    if (chapters is! List || chapters.isEmpty) return false;
  }
  return true;
}

Map<String, dynamic> _normalizedLocales(Object? raw) {
  final Map<String, dynamic> locales =
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  final List<String> content = localeTags(locales['content'], 'en');
  final List<String> gloss = localeTags(locales['gloss'], 'zh-Hans', extra: 'en');
  locales['content'] = content;
  locales['gloss'] = gloss;

  final Object? defaultGloss = locales['defaultGloss'];
  if (defaultGloss is! String || !gloss.contains(defaultGloss)) {
    locales['defaultGloss'] = gloss.first;
  }
  // `ui` belongs to the app settings, not to the pack; the schema rejects it.
  locales.remove('ui');
  return locales;
}

List<dynamic> _normalizedBooks(Object? raw) {
  if (raw is! List) return const <dynamic>[];

  final _WordStats stats = _measure(raw);
  final int sentenceTotal = stats.sentences == 0 ? 1 : stats.sentences;

  return raw.map((Object? book) {
    if (book is! Map) return book;
    final Map<String, dynamic> copy = Map<String, dynamic>.from(book);

    final Object? rawLevel = copy['level'];
    final Map<String, dynamic> level =
        rawLevel is Map ? Map<String, dynamic>.from(rawLevel) : <String, dynamic>{};

    final Object? cefr = level['cefr'];
    if (cefr is! String || !_cefrWpm.containsKey(cefr)) {
      level['cefr'] = 'A2';
    }
    final String band = level['cefr'] as String;

    level.putIfAbsent('wordCount', () => stats.words);
    level.putIfAbsent(
      'avgSentenceLen',
      () => stats.words == 0 ? 0.0 : _round(stats.words / sentenceTotal, 1),
    );
    level.putIfAbsent('ttr', () => stats.ttr);
    level.putIfAbsent(
      'newWordDensity',
      () => stats.words == 0 ? 0.0 : _round(stats.targetWords / stats.words, 3),
    );
    level.putIfAbsent('targetWpm', () => _cefrWpm[band] ?? 100);

    // The schema types these as integers; a float would be rejected.
    for (final String key in _requiredLevelInts) {
      final Object? value = level[key];
      if (value is double) level[key] = value.round();
    }
    copy['level'] = level;
    return copy;
  }).toList();
}

/// Word / sentence / type-token counts over every chapter's reading text.
class _WordStats {
  const _WordStats({
    required this.words,
    required this.sentences,
    required this.ttr,
    required this.targetWords,
  });

  final int words;
  final int sentences;
  final double ttr;
  final int targetWords;
}

_WordStats _measure(List<dynamic> books) {
  int words = 0;
  int sentences = 0;
  int targetWords = 0;
  final Set<String> unique = <String>{};

  for (final Object? book in books) {
    if (book is! Map) continue;
    final Object? chapters = book['chapters'];
    if (chapters is! List) continue;
    for (final Object? chapter in chapters) {
      if (chapter is! Map) continue;
      final Object? vocabulary = chapter['vocabulary'];
      if (vocabulary is List) targetWords += vocabulary.length;

      final Object? reading = chapter['reading'];
      if (reading is! List) continue;
      for (final Object? paragraph in reading) {
        if (paragraph is! Map) continue;
        final Object? text = paragraph['text'];
        if (text is! String) continue;
        for (final Match match in _wordPattern.allMatches(text)) {
          words++;
          unique.add(match.group(0)!.toLowerCase());
        }
        final int stops = '.'.allMatches(text).length +
            '!'.allMatches(text).length +
            '?'.allMatches(text).length;
        sentences += stops == 0 ? 1 : stops;
      }
    }
  }

  return _WordStats(
    words: words,
    sentences: sentences,
    ttr: words == 0 ? 0 : _round(unique.length / words, 3),
    targetWords: targetWords,
  );
}

double _round(double value, int digits) {
  final num factor = _pow10(digits);
  return (value * factor).round() / factor;
}

num _pow10(int digits) {
  num result = 1;
  for (int i = 0; i < digits; i++) {
    result *= 10;
  }
  return result;
}
