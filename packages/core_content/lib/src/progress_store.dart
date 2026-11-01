/// Progress persistence (`docs/07-modules.md` §5).
///
/// Writes are atomic (temp file + rename, C7). Loading never throws at the
/// caller: a missing or corrupt document degrades to an empty progress
/// document so the learner simply starts fresh.
library;

import 'dart:convert';
import 'dart:io';

import 'chapter_state.dart';
import 'progress_doc.dart';

/// Loads and saves a [ProgressDoc] for one content pack.
abstract class ProgressStore {
  /// Loads the document for [packId]; empty document when none is stored.
  Future<ProgressDoc> load(String packId);

  /// Atomically replaces the stored document.
  Future<void> save(ProgressDoc doc);
}

/// File-backed [ProgressStore]; one JSON file per pack inside [directory].
class FileProgressStore implements ProgressStore {
  FileProgressStore({required this.directory});

  /// Absolute path of the directory holding the progress files.
  final String directory;

  File _fileFor(String packId) =>
      File('$directory${Platform.pathSeparator}$packId.progress.json');

  @override
  Future<ProgressDoc> load(String packId) async {
    final File file = _fileFor(packId);
    if (!file.existsSync()) return ProgressDoc.empty(packId);
    String text;
    try {
      text = file.readAsStringSync();
    } on Exception catch (e) {
      // Corrupt/unreadable -> degraded empty document (never throw, C5).
      stdout.writeln('progress load failed for $packId: $e');
      return ProgressDoc.empty(packId);
    }
    try {
      final dynamic raw = json.decode(text);
      if (raw is! Map<String, dynamic> || raw['schemaVersion'] != 1) {
        return ProgressDoc.empty(packId);
      }
      return _docFromJson(raw, packId);
    } on Exception catch (e) {
      stdout.writeln('progress parse failed for $packId: $e');
      return ProgressDoc.empty(packId);
    }
  }

  @override
  Future<void> save(ProgressDoc doc) async {
    final File file = _fileFor(doc.packId);
    file.parent.createSync(recursive: true);
    doc.updatedAt = DateTime.now().toUtc().toIso8601String();
    final String text = json.encode(doc.toJson());
    final File tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(text, flush: true);
    // Atomic replace on the same filesystem (C7).
    tmp.renameSync(file.path);
  }

  /// Parses the schema-defined document shape; malformed inner values fall
  /// back to safe defaults instead of throwing.
  ProgressDoc _docFromJson(Map<String, dynamic> raw, String packId) {
    final doc = ProgressDoc.empty(packId);
    if (raw['contentVersion'] is String) {
      doc.contentVersion = raw['contentVersion'] as String;
    }
    if (raw['updatedAt'] is String) {
      doc.updatedAt = raw['updatedAt'] as String;
    }
    final dynamic chapters = raw['chapters'];
    if (chapters is Map<String, dynamic>) {
      chapters.forEach((String key, dynamic value) {
        if (value is Map<String, dynamic>) {
          doc.chapters[key] = _chapterFromJson(value);
        }
      });
    }
    final dynamic skills = raw['skills'];
    if (skills is Map<String, dynamic>) {
      skills.forEach((String key, dynamic value) {
        if (value is Map<String, dynamic>) {
          doc.skills[key] = ProgressSkill(
            correct: value['correct'] is int ? value['correct'] as int : 0,
            total: value['total'] is int ? value['total'] as int : 0,
          );
        }
      });
    }
    final dynamic settings = raw['settings'];
    if (settings is Map<String, dynamic>) {
      doc.settings = ProgressSettings(
        uiLocale:
            settings['uiLocale'] is String ? settings['uiLocale'] as String : 'en',
        glossLocale: settings['glossLocale'] is String
            ? settings['glossLocale'] as String
            : 'zh-Hans',
        reduceMotion: settings['reduceMotion'] == true,
      );
    }
    return doc;
  }

  ProgressChapter _chapterFromJson(Map<String, dynamic> raw) {
    final dynamic quiz = raw['quiz'];
    final dynamic retell = raw['retell'];
    return ProgressChapter(
      status: raw['status'] is String ? raw['status'] as String : 'unread',
      readParagraphs: raw['readParagraphs'] is List
          ? (raw['readParagraphs'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const <String>[],
      quiz: quiz is Map<String, dynamic>
          ? ProgressQuiz(
              attempts:
                  quiz['attempts'] is int ? quiz['attempts'] as int : 0,
              answered:
                  quiz['answered'] is int ? quiz['answered'] as int : 0,
              correct: quiz['correct'] is int ? quiz['correct'] as int : 0,
              wrongItemIds: quiz['wrongItemIds'] is List
                  ? (quiz['wrongItemIds'] as List)
                      .whereType<String>()
                      .toList(growable: false)
                  : const <String>[],
            )
          : ProgressQuiz(
              attempts: 0,
              answered: 0,
              correct: 0,
              wrongItemIds: const <String>[],
            ),
      retell: retell is List
          ? retell
              .whereType<Map<String, dynamic>>()
              .map(_retellEntryFromJson)
              .toList(growable: false)
          : const <ProgressRetellEntry>[],
    );
  }

  ProgressRetellEntry _retellEntryFromJson(Map<String, dynamic> raw) {
    return ProgressRetellEntry(
      sceneId: raw['sceneId'] is String ? raw['sceneId'] as String : '',
      attempts: raw['attempts'] is int ? raw['attempts'] as int : 0,
      bestScore: raw['bestScore'] is num
          ? (raw['bestScore'] as num).toDouble()
          : 0.0,
      lastConceptHits: raw['lastConceptHits'] is List
          ? (raw['lastConceptHits'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const <String>[],
      lastWordCount:
          raw['lastWordCount'] is int ? raw['lastWordCount'] as int : 0,
      lastDurationMs:
          raw['lastDurationMs'] is int ? raw['lastDurationMs'] as int : 0,
    );
  }
}

// ---------------------------------------------------------------------------
// ChapterState <-> progress chapter entry mapping
// ---------------------------------------------------------------------------

/// Maps a [ChapterState] onto a progress document chapter entry.
///
/// Fidelity notes:
/// - `status`, `readParagraphs` and `bestRetellScore` map losslessly.
/// - The state machine keeps only the latest quiz answers, so quiz counters
///   are taken from [quiz] when provided (T5 passes QuizResult-derived
///   stats); otherwise a minimal approximation is written.
/// - `RetellAttempt` carries no `sceneId`, so all attempts aggregate into a
///   single retell entry under [retellSceneId] (per-scene aggregation is a
///   T7 concern).
ProgressChapter progressChapterOf(
  ChapterState state, {
  ProgressQuiz? quiz,
  String retellSceneId = '',
}) {
  final List<String> read = state.readParagraphIds.toList()..sort();
  final ProgressQuiz quizStats = quiz ??
      ProgressQuiz(
        attempts: state.quizAnswers.isNotEmpty ? 1 : 0,
        answered: state.quizAnswers.length,
        correct: 0,
        wrongItemIds: const <String>[],
      );
  final List<ProgressRetellEntry> retell;
  if (state.retellAttempts.isEmpty) {
    retell = const <ProgressRetellEntry>[];
  } else {
    final RetellAttempt last = state.retellAttempts.last;
    retell = <ProgressRetellEntry>[
      ProgressRetellEntry(
        sceneId: retellSceneId,
        attempts: state.retellAttempts.length,
        bestScore: state.bestRetellScore,
        // RetellAttempt records only missing ids; hits are not recoverable.
        lastConceptHits: const <String>[],
        lastWordCount: last.wordCount,
        lastDurationMs: last.durationMs,
      ),
    ];
  }
  return ProgressChapter(
    status: state.stage.name,
    readParagraphs: read,
    quiz: quizStats,
    retell: retell,
  );
}

/// Rebuilds a [ChapterState] from a progress chapter entry (lossy inverse
/// of [progressChapterOf]: each retell entry contributes one synthesized
/// attempt; concept/fluency/completeness factors are not persisted and are
/// set to the stored best score).
ChapterState chapterStateOf({
  required String chapterId,
  required ProgressChapter entry,
}) {
  final Set<String> read = <String>{...entry.readParagraphs};
  final List<RetellAttempt> attempts = <RetellAttempt>[
    for (final ProgressRetellEntry e in entry.retell)
      RetellAttempt(
        durationMs: e.lastDurationMs,
        wordCount: e.lastWordCount,
        concept: e.bestScore,
        fluency: e.bestScore,
        completeness: e.bestScore,
        total: e.bestScore,
        missingConceptIds: const <String>[],
      ),
  ];
  double best = 0.0;
  for (final ProgressRetellEntry e in entry.retell) {
    if (e.bestScore > best) best = e.bestScore;
  }
  return ChapterState(
    chapterId: chapterId,
    stage: _stageOf(entry.status),
    readParagraphIds: read,
    quizAnswers: const <String, int>{},
    retellAttempts: attempts,
    bestRetellScore: best,
  );
}

ChapterStage _stageOf(String status) {
  for (final ChapterStage stage in ChapterStage.values) {
    if (stage.name == status) return stage;
  }
  return ChapterStage.unread;
}
