/// Parsing and validation pipeline for `pack.json`.
///
/// Never throws: every problem is collected into [PackError] entries whose
/// `code` values mirror the `contentctl` rule codes (`docs/02-content-spec.md`
/// §9). Lenient field extraction keeps scanning after a fault so one load can
/// report multiple problems.
library;

import 'dart:convert';

import 'models.dart';
import 'pack_error.dart';

/// Parses and validates a content pack from JSON text.
///
/// Returns [PackOk] when the pack is structurally and semantically clean,
/// otherwise [PackInvalid] with every problem found. When `minAppVersion`
/// exceeds [appVersion] the pack still loads with `upgradeRecommended = true`
/// (C5).
PackLoadResult parsePack(String jsonText, {required String appVersion}) {
  dynamic raw;
  try {
    raw = json.decode(jsonText);
  } on FormatException catch (e) {
    return PackInvalid(<PackError>[
      PackError(
        code: 'SCHEMA-BROKEN',
        pointer: '<root>',
        message: 'Pack JSON is not parseable: ${e.message}',
      ),
    ]);
  }
  if (raw is! Map<String, dynamic>) {
    return PackInvalid(<PackError>[
      const PackError(
        code: 'TOP-SCHEMA',
        pointer: '<root>',
        message: 'Pack root must be a JSON object',
      ),
    ]);
  }
  final ctx = _Ctx();
  final pack = _contentPack(ctx, raw);
  if (ctx.errors.isNotEmpty) {
    return PackInvalid(List<PackError>.unmodifiable(ctx.errors));
  }
  final upgrade = compareSemver(pack.minAppVersion, appVersion) > 0;
  return PackOk(pack: pack, upgradeRecommended: upgrade);
}

/// Compares two `x.y.z` version strings. Returns a positive number when
/// [a] is newer than [b], negative when older, 0 when equal.
int compareSemver(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  for (var i = 0; i < 3; i++) {
    final va = i < pa.length ? (int.tryParse(pa[i]) ?? 0) : 0;
    final vb = i < pb.length ? (int.tryParse(pb[i]) ?? 0) : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

final RegExp _idPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,63}$');
final RegExp _semverPattern = RegExp(r'^[0-9]+[.][0-9]+[.][0-9]+$');
final RegExp _localeTagPattern = RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$');

const Set<String> _posValues = <String>{
  'noun',
  'verb',
  'adjective',
  'adverb',
  'preposition',
  'phrase',
};
const Set<String> _cefrValues = <String>{'A1', 'A2', 'B1', 'B2', 'C1'};
const Set<String> _skillValues = <String>{
  'detail',
  'inference',
  'vocabulary',
  'vocabInContext',
  'sequence',
  'mainIdea',
};
const Set<String> _generatorValues = <String>{
  'human',
  'ai-assisted',
  'ai-generated',
};

String _join(String ptr, String key) => ptr.isEmpty ? key : '$ptr.$key';

/// Accumulates errors plus pack-wide id sets (ids must be unique across the
/// whole pack, mirroring contentctl).
class _Ctx {
  final List<PackError> errors = <PackError>[];
  final Set<String> bookIds = <String>{};
  final Set<String> chapterIds = <String>{};
  final Set<String> paragraphIds = <String>{};
  final Set<String> vocabIds = <String>{};
  final Set<String> quizIds = <String>{};
  final Set<String> sceneIds = <String>{};
  List<String> gloss = const <String>[];

  void err(String code, String pointer, String message) {
    errors.add(PackError(code: code, pointer: pointer, message: message));
  }

  // ---- typed field readers (lenient: log + fall back) ----

  Map<String, dynamic>? obj(String ptr, String key, Map<String, dynamic> m) {
    final v = m[key];
    if (v == null) {
      err('SCHEMA', _join(ptr, key), 'Required object field is missing');
      return null;
    }
    if (v is! Map<String, dynamic>) {
      err('SCHEMA', _join(ptr, key), 'Expected an object');
      return null;
    }
    return v;
  }

  List<dynamic> arr(String ptr, String key, Map<String, dynamic> m) {
    final v = m[key];
    if (v == null) {
      err('SCHEMA', _join(ptr, key), 'Required array field is missing');
      return const <dynamic>[];
    }
    if (v is! List) {
      err('SCHEMA', _join(ptr, key), 'Expected an array');
      return const <dynamic>[];
    }
    return v;
  }

  String str(
    String ptr,
    String key,
    Map<String, dynamic> m, {
    bool optional = false,
  }) {
    final v = m[key];
    if (v == null) {
      if (!optional) {
        err('SCHEMA', _join(ptr, key), 'Required string field is missing');
      }
      return '';
    }
    if (v is! String) {
      err('SCHEMA', _join(ptr, key), 'Expected a string');
      return '';
    }
    if (v.isEmpty) {
      err('SCHEMA', _join(ptr, key), 'String must not be empty');
    }
    return v;
  }

  int integer(
    String ptr,
    String key,
    Map<String, dynamic> m, {
    int fallback = 0,
  }) {
    final v = m[key];
    if (v == null) {
      err('SCHEMA', _join(ptr, key), 'Required integer field is missing');
      return fallback;
    }
    if (v is! int) {
      err('SCHEMA', _join(ptr, key), 'Expected an integer');
      return fallback;
    }
    return v;
  }

  double decimal(
    String ptr,
    String key,
    Map<String, dynamic> m, {
    double fallback = 0.0,
  }) {
    final v = m[key];
    if (v == null) {
      err('SCHEMA', _join(ptr, key), 'Required number field is missing');
      return fallback;
    }
    if (v is! num) {
      err('SCHEMA', _join(ptr, key), 'Expected a number');
      return fallback;
    }
    return v.toDouble();
  }

  bool flag(
    String ptr,
    String key,
    Map<String, dynamic> m, {
    bool fallback = false,
  }) {
    final v = m[key];
    if (v == null) {
      err('SCHEMA', _join(ptr, key), 'Required boolean field is missing');
      return fallback;
    }
    if (v is! bool) {
      err('SCHEMA', _join(ptr, key), 'Expected a boolean');
      return fallback;
    }
    return v;
  }

  /// Required id field: non-empty string matching the id pattern.
  String idOf(String ptr, String key, Map<String, dynamic> m) {
    final v = m[key];
    if (v == null || v is! String || v.isEmpty) {
      err('SCHEMA', _join(ptr, key), 'Required id is missing or empty');
      return '';
    }
    if (!_idPattern.hasMatch(v)) {
      err(
        'SCHEMA',
        _join(ptr, key),
        'id "$v" does not match ^[a-z0-9][a-z0-9-]{1,63}\$',
      );
    }
    return v;
  }

  /// Required enum field; violations get the domain-specific [code].
  String enumOf(
    String ptr,
    String key,
    Map<String, dynamic> m,
    Set<String> allowed,
    String code,
  ) {
    final v = m[key];
    if (v is! String || !allowed.contains(v)) {
      err(code, _join(ptr, key), 'Illegal value: $v');
      return allowed.first;
    }
    return v;
  }

  /// Required semver field at pack top level.
  String semverOf(String ptr, String key, Map<String, dynamic> m) {
    final v = m[key];
    if (v == null || v is! String || v.isEmpty) {
      err('TOP-SCHEMA', _join(ptr, key), 'Required semver field is missing');
      return '0.0.0';
    }
    if (!_semverPattern.hasMatch(v)) {
      err('TOP-SCHEMA', _join(ptr, key), 'Not an x.y.z semver: $v');
    }
    return v;
  }

  /// Localized text: required unless [optional]; must cover every gloss
  /// locale and hold non-empty translations.
  LocalizedText? localized(String ptr, dynamic v, {bool optional = false}) {
    if (v == null) {
      if (!optional) {
        err('I18N-MISSING', ptr, 'Missing localized text object');
      }
      return null;
    }
    if (v is! Map<String, dynamic>) {
      err('SCHEMA', ptr, 'Expected a localized text object');
      return null;
    }
    final by = <String, String>{};
    v.forEach((dynamic k, dynamic val) {
      if (val is! String) {
        err('SCHEMA', '$ptr.$k', 'Expected a string translation');
        return;
      }
      if (val.trim().isEmpty) {
        err('I18N-EMPTY', '$ptr.$k', 'Translation is empty');
      }
      by[k] = val;
    });
    final missing =
        gloss.where((String g) => !by.containsKey(g)).toList(growable: false);
    if (missing.isNotEmpty) {
      err('I18N-INCOMPLETE', ptr, 'Missing gloss locales: ${missing.join(', ')}');
    }
    return LocalizedText(by);
  }
}

// ---------------------------------------------------------------------------
// Model builders
// ---------------------------------------------------------------------------

ContentPack _contentPack(_Ctx ctx, Map<String, dynamic> raw) {
  if (raw['schemaVersion'] != 1) {
    ctx.err('TOP-SCHEMA', 'schemaVersion', 'schemaVersion must be 1');
  }
  final contentVersion = ctx.semverOf('', 'contentVersion', raw);
  final minAppVersion = ctx.semverOf('', 'minAppVersion', raw);

  final localesMap = ctx.obj('', 'locales', raw);
  final locales = localesMap == null
      ? const Locales(content: <String>[], gloss: <String>[], defaultGloss: '')
      : _locales(ctx, localesMap);
  ctx.gloss = locales.gloss;

  final booksRaw = ctx.arr('', 'books', raw);
  if (booksRaw.isEmpty) {
    ctx.err('BOOKS-EMPTY', 'books', 'A pack needs at least one book');
  }
  final books = <Book>[];
  for (var i = 0; i < booksRaw.length; i++) {
    final m = booksRaw[i];
    final ptr = 'books[$i]';
    if (m is! Map<String, dynamic>) {
      ctx.err('SCHEMA', ptr, 'Expected an object');
      continue;
    }
    books.add(_book(ctx, m, ptr));
  }

  return ContentPack(
    schemaVersion: raw['schemaVersion'] is int ? raw['schemaVersion'] as int : 0,
    contentVersion: contentVersion,
    minAppVersion: minAppVersion,
    locales: locales,
    books: books,
  );
}

Locales _locales(_Ctx ctx, Map<String, dynamic> m) {
  const ptr = 'locales';
  final contentRaw = ctx.arr(ptr, 'content', m);
  final glossRaw = ctx.arr(ptr, 'gloss', m);
  final content = <String>[];
  for (final dynamic t in contentRaw) {
    final tag = _localeTag(ctx, ptr, 'content', t);
    if (tag != null) content.add(tag);
  }
  final gloss = <String>[];
  for (final dynamic t in glossRaw) {
    final tag = _localeTag(ctx, ptr, 'gloss', t);
    if (tag != null) gloss.add(tag);
  }
  if (content.isEmpty) {
    ctx.err('I18N-CONTENT-EMPTY', 'locales.content', 'No content locale declared');
  }
  if (gloss.isEmpty) {
    ctx.err('I18N-GLOSS-EMPTY', 'locales.gloss', 'No gloss locale declared');
  }
  final defaultGloss = ctx.str(ptr, 'defaultGloss', m);
  if (defaultGloss.isNotEmpty && !gloss.contains(defaultGloss)) {
    ctx.err(
      'I18N-DEFAULT',
      'locales.defaultGloss',
      'defaultGloss "$defaultGloss" is not in locales.gloss',
    );
  }
  return Locales(content: content, gloss: gloss, defaultGloss: defaultGloss);
}

String? _localeTag(_Ctx ctx, String ptr, String key, dynamic v) {
  if (v is! String || v.isEmpty) {
    ctx.err('SCHEMA', _join(ptr, key), 'Expected a non-empty locale tag');
    return null;
  }
  if (!_localeTagPattern.hasMatch(v)) {
    ctx.err('SCHEMA', _join(ptr, key), 'Illegal locale tag: $v');
  }
  return v;
}

Book _book(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final id = ctx.idOf(ptr, 'id', m);
  if (ctx.bookIds.contains(id)) {
    ctx.err('ID-DUP-BOOK', ptr, 'Duplicate book id: $id');
  }
  ctx.bookIds.add(id);

  final title = ctx.str(ptr, 'title', m);
  final blurb = ctx.localized('$ptr.blurb', m['blurb'], optional: true);
  final seriesMap = ctx.obj(ptr, 'series', m);
  final series = seriesMap == null
      ? const Series(id: '', name: '', order: 1)
      : _series(ctx, seriesMap, '$ptr.series');
  final levelMap = m['level'];
  final Level level;
  if (levelMap is! Map<String, dynamic>) {
    ctx.err('LEVEL-MISSING', '$ptr.level', 'Level object is missing');
    level = const Level(
      cefr: 'A1',
      wordCount: 0,
      avgSentenceLen: 0,
      ttr: 0,
      newWordDensity: 0,
      targetWpm: 0,
    );
  } else {
    level = _level(ctx, levelMap, '$ptr.level');
  }
  final attrMap = ctx.obj(ptr, 'attribution', m);
  final attribution = attrMap == null
      ? const Attribution(
          author: '',
          license: '',
          generator: 'human',
          sourceNote: '',
        )
      : _attribution(ctx, attrMap, '$ptr.attribution');
  final coverMap = ctx.obj(ptr, 'cover', m);
  final cover = coverMap == null
      ? Cover(
          url: '',
          aspect: 1,
          alt: LocalizedText(const <String, String>{}),
        )
      : _cover(ctx, coverMap, '$ptr.cover');

  final chaptersRaw = ctx.arr(ptr, 'chapters', m);
  if (chaptersRaw.isEmpty) {
    ctx.err('CHAPTERS-EMPTY', '$ptr.chapters', 'A book needs at least one chapter');
  }
  final chapters = <Chapter>[];
  for (var i = 0; i < chaptersRaw.length; i++) {
    final cm = chaptersRaw[i];
    final cptr = '$ptr.chapters[$i]';
    if (cm is! Map<String, dynamic>) {
      ctx.err('SCHEMA', cptr, 'Expected an object');
      continue;
    }
    chapters.add(_chapter(ctx, cm, cptr));
  }

  return Book(
    id: id,
    title: title,
    blurb: blurb,
    series: series,
    level: level,
    attribution: attribution,
    cover: cover,
    chapters: chapters,
  );
}

Series _series(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  return Series(
    id: ctx.idOf(ptr, 'id', m),
    name: ctx.str(ptr, 'name', m),
    order: ctx.integer(ptr, 'order', m, fallback: 1),
  );
}

Level _level(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  // Missing declared fields use the LEVEL-MISSING code (mirrors contentctl).
  String levelEnum(String key) {
    final v = m[key];
    if (v is! String || !_cefrValues.contains(v)) {
      ctx.err('LEVEL-MISSING', _join(ptr, key), 'Missing or illegal $key: $v');
      return 'A1';
    }
    return v;
  }

  int levelInt(String key) {
    final v = m[key];
    if (v is! int) {
      ctx.err('LEVEL-MISSING', _join(ptr, key), 'Missing or illegal $key: $v');
      return 0;
    }
    return v;
  }

  double levelNum(String key) {
    final v = m[key];
    if (v is! num) {
      ctx.err('LEVEL-MISSING', _join(ptr, key), 'Missing or illegal $key: $v');
      return 0;
    }
    return v.toDouble();
  }

  return Level(
    cefr: levelEnum('cefr'),
    wordCount: levelInt('wordCount'),
    avgSentenceLen: levelNum('avgSentenceLen'),
    ttr: levelNum('ttr'),
    newWordDensity: levelNum('newWordDensity'),
    targetWpm: levelInt('targetWpm'),
  );
}

Attribution _attribution(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  return Attribution(
    author: ctx.str(ptr, 'author', m),
    illustrator: ctx.str(ptr, 'illustrator', m, optional: true),
    license: ctx.str(ptr, 'license', m),
    generator: ctx.enumOf(ptr, 'generator', m, _generatorValues, 'SCHEMA'),
    sourceNote: ctx.str(ptr, 'sourceNote', m),
  );
}

Cover _cover(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final alt = ctx.localized('$ptr.alt', m['alt']);
  return Cover(
    url: ctx.str(ptr, 'url', m),
    aspect: ctx.decimal(ptr, 'aspect', m, fallback: 1.0),
    blurhash: ctx.str(ptr, 'blurhash', m, optional: true),
    alt: alt ?? LocalizedText(const <String, String>{}),
  );
}

Chapter _chapter(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final id = ctx.idOf(ptr, 'id', m);
  if (ctx.chapterIds.contains(id)) {
    ctx.err('ID-DUP-CHAPTER', ptr, 'Duplicate chapter id: $id');
  }
  ctx.chapterIds.add(id);

  final readingRaw = ctx.arr(ptr, 'reading', m);
  if (readingRaw.isEmpty) {
    ctx.err('READING-EMPTY', '$ptr.reading', 'A chapter needs at least one paragraph');
  }
  final reading = <Paragraph>[];
  final paraIds = <String>{};
  for (var i = 0; i < readingRaw.length; i++) {
    final pm = readingRaw[i];
    final pptr = '$ptr.reading[$i]';
    if (pm is! Map<String, dynamic>) {
      ctx.err('SCHEMA', pptr, 'Expected an object');
      continue;
    }
    final para = _paragraph(ctx, pm, pptr);
    if (!ctx.paragraphIds.add(para.id)) {
      ctx.err('ID-DUP-PARA', pptr, 'Duplicate paragraph id: ${para.id}');
    }
    paraIds.add(para.id);
    reading.add(para);
  }

  final vocabularyRaw = ctx.arr(ptr, 'vocabulary', m);
  final vocabulary = <VocabItem>[];
  for (var i = 0; i < vocabularyRaw.length; i++) {
    final vm = vocabularyRaw[i];
    final vptr = '$ptr.vocabulary[$i]';
    if (vm is! Map<String, dynamic>) {
      ctx.err('SCHEMA', vptr, 'Expected an object');
      continue;
    }
    final item = _vocabItem(ctx, vm, vptr, paraIds);
    if (!ctx.vocabIds.add(item.id)) {
      ctx.err('ID-DUP-VOCAB', vptr, 'Duplicate vocabulary id: ${item.id}');
    }
    vocabulary.add(item);
  }

  final quizRaw = ctx.arr(ptr, 'quiz', m);
  final quiz = <QuizItem>[];
  for (var i = 0; i < quizRaw.length; i++) {
    final qm = quizRaw[i];
    final qptr = '$ptr.quiz[$i]';
    if (qm is! Map<String, dynamic>) {
      ctx.err('SCHEMA', qptr, 'Expected an object');
      continue;
    }
    final item = _quizItem(ctx, qm, qptr, paraIds);
    if (!ctx.quizIds.add(item.id)) {
      ctx.err('ID-DUP-QUIZ', qptr, 'Duplicate quiz id: ${item.id}');
    }
    quiz.add(item);
  }

  final retellMap = ctx.obj(ptr, 'retell', m);
  final retell = retellMap == null
      ? Retell(
          scenes: const <Scene>[],
          rubric: const Rubric(
            minWords: 0,
            maxSeconds: 0,
            conceptWeight: 0,
            fluencyWeight: 0,
            completenessWeight: 0,
            wpmTargetRange: <int>[0, 0],
          ),
        )
      : _retell(ctx, retellMap, '$ptr.retell');

  return Chapter(
    id: id,
    order: ctx.integer(ptr, 'order', m, fallback: 1),
    title: ctx.str(ptr, 'title', m),
    available: ctx.flag(ptr, 'available', m, fallback: true),
    estimatedMinutes: ctx.integer(ptr, 'estimatedMinutes', m, fallback: 1),
    reading: reading,
    vocabulary: vocabulary,
    quiz: quiz,
    retell: retell,
  );
}

Paragraph _paragraph(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final audioMap = ctx.obj(ptr, 'audio', m);
  final audio = audioMap == null
      ? const AudioTimeline(url: '', durationMs: 1, sentences: <SpokenSentence>[])
      : _audioTimeline(ctx, audioMap, '$ptr.audio');
  return Paragraph(
    id: ctx.idOf(ptr, 'id', m),
    text: ctx.str(ptr, 'text', m),
    audio: audio,
  );
}

AudioTimeline _audioTimeline(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final durationMs = ctx.integer(ptr, 'durationMs', m, fallback: 1);
  if (durationMs <= 0) {
    ctx.err('AUDIO-DURATION', '$ptr.durationMs', 'durationMs must be positive');
  }

  final sentencesRaw = ctx.arr(ptr, 'sentences', m);
  if (sentencesRaw.isEmpty) {
    ctx.err(
      'AUDIO-SENTENCES',
      '$ptr.sentences',
      'sentences must not be empty (highlighting needs the timeline)',
    );
  }
  final sentences = <SpokenSentence>[];
  var prevEnd = 0;
  for (var i = 0; i < sentencesRaw.length; i++) {
    final sm = sentencesRaw[i];
    final sptr = '$ptr.sentences[$i]';
    if (sm is! Map<String, dynamic>) {
      ctx.err('SCHEMA', sptr, 'Expected an object');
      continue;
    }
    final startMs = ctx.integer(sptr, 'startMs', sm);
    final endMs = ctx.integer(sptr, 'endMs', sm, fallback: 1);
    if (endMs <= startMs) {
      ctx.err('AUDIO-RANGE', sptr, 'endMs ($endMs) must be greater than startMs ($startMs)');
    }
    if (startMs < prevEnd) {
      ctx.err('AUDIO-OVERLAP', sptr, 'Overlaps the previous sentence (ends at $prevEnd)');
    }
    if (endMs > prevEnd) prevEnd = endMs;
    sentences.add(SpokenSentence(
      text: ctx.str(sptr, 'text', sm),
      startMs: startMs,
      endMs: endMs,
    ));
  }
  if (prevEnd > durationMs) {
    ctx.err(
      'AUDIO-EXCEED',
      ptr,
      'Sentence timeline ends at $prevEnd, beyond durationMs $durationMs',
    );
  }

  return AudioTimeline(
    url: ctx.str(ptr, 'url', m),
    durationMs: durationMs,
    sentences: sentences,
  );
}

VocabItem _vocabItem(
  _Ctx ctx,
  Map<String, dynamic> m,
  String ptr,
  Set<String> paraIds,
) {
  final sourceParagraphId = ctx.str(ptr, 'sourceParagraphId', m);
  if (sourceParagraphId.isNotEmpty && !paraIds.contains(sourceParagraphId)) {
    ctx.err(
      'VOCAB-PARA',
      '$ptr.sourceParagraphId',
      'Unknown paragraph id: $sourceParagraphId',
    );
  }
  final gloss = ctx.localized('$ptr.gloss', m['gloss']);
  // Optional: `ctx.obj` reports a missing field as an error, which is right for
  // `series` but wrong here — a pack generated before word clips existed simply
  // has no `audio`, and the card keeps its speaker disabled.
  final dynamic audioRaw = m['audio'];
  ClipRef? audio;
  if (audioRaw is Map<String, dynamic>) {
    audio = _clipRef(ctx, audioRaw, '$ptr.audio');
  } else if (audioRaw != null) {
    ctx.err('SCHEMA', '$ptr.audio', 'Expected an object');
  }
  final dynamic exampleRaw = m['exampleAudio'];
  ClipRef? exampleAudio;
  if (exampleRaw is Map<String, dynamic>) {
    exampleAudio = _clipRef(ctx, exampleRaw, '$ptr.exampleAudio');
  } else if (exampleRaw != null) {
    ctx.err('SCHEMA', '$ptr.exampleAudio', 'Expected an object');
  }
  return VocabItem(
    id: ctx.idOf(ptr, 'id', m),
    lemma: ctx.str(ptr, 'lemma', m),
    surfaceForm: ctx.str(ptr, 'surfaceForm', m),
    partOfSpeech: ctx.enumOf(ptr, 'partOfSpeech', m, _posValues, 'VOCAB-POS'),
    senseKey: ctx.str(ptr, 'senseKey', m),
    definition: ctx.str(ptr, 'definition', m),
    gloss: gloss ?? LocalizedText(const <String, String>{}),
    sourceSentence: ctx.str(ptr, 'sourceSentence', m),
    sourceParagraphId: sourceParagraphId,
    cefr: ctx.enumOf(ptr, 'cefr', m, _cefrValues, 'VOCAB-CEFR'),
    isTarget: ctx.flag(ptr, 'isTarget', m),
    audio: audio,
    exampleAudio: exampleAudio,
  );
}

/// `$defs/clip` — a standalone pronunciation (no timeline).
ClipRef _clipRef(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final durationMs = ctx.integer(ptr, 'durationMs', m, fallback: 1);
  if (durationMs <= 0) {
    ctx.err('AUDIO-DURATION', '$ptr.durationMs', 'durationMs must be positive');
  }
  return ClipRef(
    url: ctx.str(ptr, 'url', m),
    durationMs: durationMs,
  );
}

QuizItem _quizItem(
  _Ctx ctx,
  Map<String, dynamic> m,
  String ptr,
  Set<String> paraIds,
) {
  final optionsRaw = ctx.arr(ptr, 'options', m);
  final options = <String>[];
  var optionsClean = true;
  for (var i = 0; i < optionsRaw.length; i++) {
    final dynamic o = optionsRaw[i];
    if (o is! String || o.isEmpty) {
      ctx.err('SCHEMA', '$ptr.options[$i]', 'Expected a non-empty string option');
      optionsClean = false;
      continue;
    }
    options.add(o);
  }
  if (optionsRaw.length != 4) {
    ctx.err('SCHEMA', '$ptr.options', 'Expected exactly 4 options, got ${optionsRaw.length}');
  }
  if (optionsClean && options.toSet().length != options.length) {
    ctx.err('QUIZ-DUP-OPTION', '$ptr.options', 'Duplicate option texts');
  }

  final dynamic answerRaw = m['answer'];
  var answer = 0;
  if (answerRaw is! int) {
    ctx.err('QUIZ-ANSWER', '$ptr.answer', 'answer must be an integer, got: $answerRaw');
  } else {
    answer = answerRaw;
    if (answerRaw < 0 || answerRaw >= options.length) {
      ctx.err(
        'QUIZ-ANSWER',
        '$ptr.answer',
        'answer $answerRaw is out of range for ${options.length} options',
      );
    }
  }

  final evidence = ctx.str(ptr, 'evidence', m);
  if (evidence.isNotEmpty && !paraIds.contains(evidence)) {
    ctx.err('QUIZ-EVIDENCE', '$ptr.evidence', 'Unknown paragraph id: $evidence');
  }

  final promptGloss = ctx.localized('$ptr.promptGloss', m['promptGloss'], optional: true);
  final explanation = ctx.localized('$ptr.explanation', m['explanation']);
  return QuizItem(
    id: ctx.idOf(ptr, 'id', m),
    skill: ctx.enumOf(ptr, 'skill', m, _skillValues, 'QUIZ-SKILL'),
    prompt: ctx.str(ptr, 'prompt', m),
    promptGloss: promptGloss,
    options: options,
    answer: answer,
    explanation: explanation ?? LocalizedText(const <String, String>{}),
    evidence: evidence,
  );
}

Retell _retell(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final scenesRaw = ctx.arr(ptr, 'scenes', m);
  if (scenesRaw.isEmpty) {
    ctx.err('RETELL-SCENES', '$ptr.scenes', 'At least one retell scene is required');
  }
  final scenes = <Scene>[];
  for (var i = 0; i < scenesRaw.length; i++) {
    final sm = scenesRaw[i];
    final sptr = '$ptr.scenes[$i]';
    if (sm is! Map<String, dynamic>) {
      ctx.err('SCHEMA', sptr, 'Expected an object');
      continue;
    }
    scenes.add(_scene(ctx, sm, sptr));
  }

  final rubricMap = m['rubric'];
  final Rubric rubric;
  if (rubricMap is! Map<String, dynamic>) {
    ctx.err('RUBRIC-MISSING', '$ptr.rubric', 'Rubric object is missing');
    rubric = const Rubric(
      minWords: 0,
      maxSeconds: 0,
      conceptWeight: 0,
      fluencyWeight: 0,
      completenessWeight: 0,
      wpmTargetRange: <int>[0, 0],
    );
  } else {
    rubric = _rubric(ctx, rubricMap, '$ptr.rubric');
  }
  return Retell(scenes: scenes, rubric: rubric);
}

Scene _scene(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final id = ctx.idOf(ptr, 'id', m);
  if (ctx.sceneIds.contains(id)) {
    ctx.err('ID-DUP-SCENE', ptr, 'Duplicate scene id: $id');
  }
  ctx.sceneIds.add(id);

  final imageMap = ctx.obj(ptr, 'image', m);
  final image = imageMap == null
      ? Media(url: '', alt: LocalizedText(const <String, String>{}))
      : _media(ctx, imageMap, '$ptr.image');

  final conceptsRaw = ctx.arr(ptr, 'concepts', m);
  if (conceptsRaw.isEmpty) {
    ctx.err('RETELL-CONCEPTS', '$ptr.concepts', 'At least one scoring concept is required');
  }
  final concepts = <Concept>[];
  final conceptIds = <String>{};
  for (var i = 0; i < conceptsRaw.length; i++) {
    final cm = conceptsRaw[i];
    final cptr = '$ptr.concepts[$i]';
    if (cm is! Map<String, dynamic>) {
      ctx.err('SCHEMA', cptr, 'Expected an object');
      continue;
    }
    final concept = _concept(ctx, cm, cptr);
    if (!conceptIds.add(concept.id)) {
      ctx.err('RETELL-CONCEPT-DUP', cptr, 'Duplicate concept id: ${concept.id}');
    }
    concepts.add(concept);
  }

  final hint1 = ctx.localized('$ptr.hint1', m['hint1']);
  final hint2 = ctx.localized('$ptr.hint2', m['hint2']);
  return Scene(
    id: id,
    order: ctx.integer(ptr, 'order', m, fallback: 1),
    image: image,
    prompt: ctx.str(ptr, 'prompt', m),
    concepts: concepts,
    hint1: hint1 ?? LocalizedText(const <String, String>{}),
    hint2: hint2 ?? LocalizedText(const <String, String>{}),
    suggestedAnswer: ctx.str(ptr, 'suggestedAnswer', m),
    targetWordCount: ctx.integer(ptr, 'targetWordCount', m, fallback: 5),
  );
}

Concept _concept(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final termsRaw = ctx.arr(ptr, 'terms', m);
  if (termsRaw.isEmpty) {
    ctx.err('RETELL-TERMS', '$ptr.terms', 'terms must not be empty');
  }
  final terms = <String>[];
  for (var i = 0; i < termsRaw.length; i++) {
    final dynamic t = termsRaw[i];
    if (t is! String || t.isEmpty) {
      ctx.err('SCHEMA', '$ptr.terms[$i]', 'Expected a non-empty string term');
      continue;
    }
    terms.add(t);
  }
  final label = ctx.localized('$ptr.label', m['label']);
  return Concept(
    id: ctx.idOf(ptr, 'id', m),
    label: label ?? LocalizedText(const <String, String>{}),
    terms: terms,
    required: ctx.flag(ptr, 'required', m),
  );
}

Media _media(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  final alt = ctx.localized('$ptr.alt', m['alt']);
  return Media(
    url: ctx.str(ptr, 'url', m),
    alt: alt ?? LocalizedText(const <String, String>{}),
  );
}

Rubric _rubric(_Ctx ctx, Map<String, dynamic> m, String ptr) {
  double weight(String key) {
    final v = m[key];
    if (v == null) {
      ctx.err('RUBRIC-MISSING', _join(ptr, key), 'Missing weight field: $key');
      return 0.0;
    }
    if (v is! num) {
      ctx.err('RUBRIC-MISSING', _join(ptr, key), 'Illegal weight field: $key');
      return 0.0;
    }
    return v.toDouble();
  }

  final conceptWeight = weight('conceptWeight');
  final fluencyWeight = weight('fluencyWeight');
  final completenessWeight = weight('completenessWeight');
  final total = conceptWeight + fluencyWeight + completenessWeight;
  if ((total - 1.0).abs() > 0.001) {
    ctx.err(
      'RUBRIC-SUM',
      ptr,
      'Weights must sum to 1.0, got ${total.toStringAsFixed(3)}',
    );
  }

  final rangeRaw = ctx.arr(ptr, 'wpmTargetRange', m);
  final range = <int>[];
  for (final dynamic v in rangeRaw) {
    if (v is! int) {
      ctx.err('SCHEMA', '$ptr.wpmTargetRange', 'Expected integer bounds');
      continue;
    }
    range.add(v);
  }
  if (rangeRaw.length != 2) {
    ctx.err('SCHEMA', '$ptr.wpmTargetRange', 'Expected exactly 2 bounds');
  } else if (range.length == 2 && range[0] > range[1]) {
    ctx.err('RUBRIC-WPM', '$ptr.wpmTargetRange', 'Lower bound exceeds upper bound');
  }

  return Rubric(
    minWords: ctx.integer(ptr, 'minWords', m),
    maxSeconds: ctx.integer(ptr, 'maxSeconds', m),
    conceptWeight: conceptWeight,
    fluencyWeight: fluencyWeight,
    completenessWeight: completenessWeight,
    wpmTargetRange: range,
  );
}
