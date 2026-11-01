/// Learner progress document model, mirroring
/// `schema/progress.v1.schema.json` (the single source of truth).
library;

/// One progress document for a content pack.
class ProgressDoc {
  ProgressDoc({
    required this.packId,
    required this.contentVersion,
    required this.updatedAt,
    required this.chapters,
    required this.skills,
    required this.settings,
    this.schemaVersion = 1,
  });

  /// A fresh, empty document used when nothing has been saved yet or when
  /// the stored document is missing/corrupt (degraded fresh start).
  factory ProgressDoc.empty(String packId) => ProgressDoc(
        packId: packId,
        contentVersion: '',
        updatedAt: '',
        chapters: <String, ProgressChapter>{},
        skills: <String, ProgressSkill>{},
        settings: ProgressSettings(
          uiLocale: 'en',
          glossLocale: 'zh-Hans',
          reduceMotion: false,
        ),
      );

  int schemaVersion;
  String packId;
  String contentVersion;
  String updatedAt;

  /// Keyed by `<bookId>/<chapterId>` (decision ①).
  final Map<String, ProgressChapter> chapters;
  final Map<String, ProgressSkill> skills;
  ProgressSettings settings;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'packId': packId,
        'contentVersion': contentVersion,
        'updatedAt': updatedAt,
        'chapters': <String, dynamic>{
          for (final MapEntry<String, ProgressChapter> e in chapters.entries)
            e.key: e.value.toJson(),
        },
        'skills': <String, dynamic>{
          for (final MapEntry<String, ProgressSkill> e in skills.entries)
            e.key: e.value.toJson(),
        },
        'settings': settings.toJson(),
      };
}

/// Progress of one chapter; matches one `chapters` entry of the schema.
class ProgressChapter {
  ProgressChapter({
    required this.status,
    required this.readParagraphs,
    required this.quiz,
    required this.retell,
  });

  /// ChapterStage name: locked/unread/reading/vocabulary/quiz/retell/complete.
  String status;
  List<String> readParagraphs;
  ProgressQuiz quiz;
  List<ProgressRetellEntry> retell;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status,
        'readParagraphs': readParagraphs,
        'quiz': quiz.toJson(),
        'retell': retell.map((ProgressRetellEntry e) => e.toJson()).toList(),
      };
}

/// Quiz attempt counters of one chapter.
class ProgressQuiz {
  ProgressQuiz({
    required this.attempts,
    required this.answered,
    required this.correct,
    required this.wrongItemIds,
  });

  int attempts;
  int answered;
  int correct;
  List<String> wrongItemIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'attempts': attempts,
        'answered': answered,
        'correct': correct,
        'wrongItemIds': wrongItemIds,
      };
}

/// Aggregated retell record per scene.
class ProgressRetellEntry {
  ProgressRetellEntry({
    required this.sceneId,
    required this.attempts,
    required this.bestScore,
    required this.lastConceptHits,
    required this.lastWordCount,
    required this.lastDurationMs,
  });

  String sceneId;
  int attempts;
  double bestScore;
  List<String> lastConceptHits;
  int lastWordCount;
  int lastDurationMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sceneId': sceneId,
        'attempts': attempts,
        'bestScore': bestScore,
        'lastConceptHits': lastConceptHits,
        'lastWordCount': lastWordCount,
        'lastDurationMs': lastDurationMs,
      };
}

/// Aggregated skill counters (skill -> correct/total).
class ProgressSkill {
  ProgressSkill({required this.correct, required this.total});

  int correct;
  int total;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'correct': correct,
        'total': total,
      };
}

/// UI preferences stored with the progress document.
class ProgressSettings {
  ProgressSettings({
    required this.uiLocale,
    required this.glossLocale,
    required this.reduceMotion,
  });

  String uiLocale;
  String glossLocale;
  bool reduceMotion;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uiLocale': uiLocale,
        'glossLocale': glossLocale,
        'reduceMotion': reduceMotion,
      };
}

/// Canonical `chapters` key format: `<bookId>/<chapterId>` (decision ①).
String progressChapterKey(String bookId, String chapterId) =>
    '$bookId/$chapterId';
