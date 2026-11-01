/// Domain models of a content pack, mirroring
/// `schema/content-pack.v1.schema.json` and `docs/07-modules.md` §2.1.
///
/// All models are immutable. Content-language fields (text, prompt, options,
/// terms, suggestedAnswer, definition) are never translated; support-language
/// fields use [LocalizedText] and must follow the UI language.
library;

/// A support-language string bundle keyed by locale tag
/// (e.g. `zh-Hans`, `en`).
class LocalizedText {
  LocalizedText(Map<String, String> byLocale)
      : byLocale = Map<String, String>.unmodifiable(byLocale);

  /// Translation per locale tag.
  final Map<String, String> byLocale;
}

/// Root object of `pack.json`.
class ContentPack {
  const ContentPack({
    required this.schemaVersion,
    required this.contentVersion,
    required this.minAppVersion,
    required this.locales,
    required this.books,
  });

  /// Contract version; must be 1.
  final int schemaVersion;

  /// Semver of the content itself.
  final String contentVersion;

  /// Semver of the oldest app that can render this pack.
  final String minAppVersion;

  /// Supported content and gloss languages.
  final Locales locales;

  /// Books contained in this pack (>= 1).
  final List<Book> books;
}

/// Language declarations of a pack.
class Locales {
  const Locales({
    required this.content,
    required this.gloss,
    required this.defaultGloss,
  });

  /// Content-language tags, e.g. `['en-US']`.
  final List<String> content;

  /// Gloss-language tags, e.g. `['zh-Hans', 'en']`.
  final List<String> gloss;

  /// Gloss locale used when the UI locale has no match.
  final String defaultGloss;
}

/// One story book.
class Book {
  const Book({
    required this.id,
    required this.title,
    this.blurb,
    required this.series,
    required this.level,
    required this.attribution,
    required this.cover,
    required this.chapters,
  });

  final String id;
  final String title;

  /// Optional one-line summary of the book (schema `book.blurb`), localized
  /// like `cover.alt` / vocabulary `gloss`. `null` when the pack ships none.
  final LocalizedText? blurb;

  final Series series;
  final Level level;
  final Attribution attribution;
  final Cover cover;
  final List<Chapter> chapters;
}

/// Series membership of a book.
class Series {
  const Series({
    required this.id,
    required this.name,
    required this.order,
  });

  final String id;
  final String name;

  /// 1-based position of the book inside the series.
  final int order;
}

/// Declared difficulty metrics of a book (computed by `contentctl stats`).
class Level {
  const Level({
    required this.cefr,
    required this.wordCount,
    required this.avgSentenceLen,
    required this.ttr,
    required this.newWordDensity,
    required this.targetWpm,
  });

  /// CEFR band: A1/A2/B1/B2/C1.
  final String cefr;
  final int wordCount;
  final double avgSentenceLen;
  final double ttr;
  final double newWordDensity;
  final int targetWpm;
}

/// Authorship and license metadata.
class Attribution {
  const Attribution({
    required this.author,
    this.illustrator,
    required this.license,
    required this.generator,
    required this.sourceNote,
  });

  final String author;
  final String? illustrator;

  /// License of the material; must be declared for AI-assisted content.
  final String license;

  /// One of: human, ai-assisted, ai-generated.
  final String generator;
  final String sourceNote;
}

/// Book cover metadata.
class Cover {
  const Cover({
    required this.url,
    required this.aspect,
    this.blurhash,
    required this.alt,
  });

  /// `media/...` relative path or `https://` URL.
  final String url;

  /// Width / height ratio (> 0).
  final double aspect;
  final String? blurhash;
  final LocalizedText alt;
}

/// One chapter of a book; the unit of progress tracking.
class Chapter {
  const Chapter({
    required this.id,
    required this.order,
    required this.title,
    required this.available,
    required this.estimatedMinutes,
    required this.reading,
    required this.vocabulary,
    required this.quiz,
    required this.retell,
  });

  final String id;

  /// 1-based position of the chapter inside the book.
  final int order;
  final String title;

  /// False when the chapter is not yet released to learners.
  final bool available;
  final int estimatedMinutes;
  final List<Paragraph> reading;
  final List<VocabItem> vocabulary;
  final List<QuizItem> quiz;
  final Retell retell;
}

/// One reading paragraph with word-alignment audio.
class Paragraph {
  const Paragraph({
    required this.id,
    required this.text,
    required this.audio,
  });

  final String id;

  /// Content language (English); never translated.
  final String text;
  final AudioTimeline audio;
}

/// Audio of one paragraph plus sentence-level timeline for highlighting.
class AudioTimeline {
  const AudioTimeline({
    required this.url,
    required this.durationMs,
    required this.sentences,
  });

  /// `media/...` relative path or `https://` URL.
  final String url;
  final int durationMs;
  final List<SpokenSentence> sentences;
}

/// One sentence span inside an [AudioTimeline].
class SpokenSentence {
  const SpokenSentence({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;
}

/// One vocabulary card.
/// A short standalone pronunciation clip (schema `$defs/clip`).
///
/// Used by the word card's speaker: `url` is a `mediaUrl`, `durationMs` is the
/// measured length. Unlike [Paragraph.audio] there is no timeline — a clip is
/// one utterance and is played whole.
class ClipRef {
  const ClipRef({required this.url, required this.durationMs});

  final String url;
  final int durationMs;
}

class VocabItem {
  const VocabItem({
    required this.id,
    required this.lemma,
    required this.surfaceForm,
    required this.partOfSpeech,
    required this.senseKey,
    required this.definition,
    required this.gloss,
    required this.sourceSentence,
    required this.sourceParagraphId,
    required this.cefr,
    required this.isTarget,
    this.audio,
    this.exampleAudio,
  });

  final String id;
  final String lemma;
  final String surfaceForm;

  /// One of: noun, verb, adjective, adverb, preposition, phrase.
  final String partOfSpeech;

  /// `lemma:pos+N` sense identifier; stable across releases.
  final String senseKey;

  /// Simple English definition (content language, fixed).
  final String definition;

  /// Learner-language gloss; follows the UI language.
  final LocalizedText gloss;
  final String sourceSentence;
  final String sourceParagraphId;

  /// CEFR band: A1/A2/B1/B2/C1.
  final String cefr;

  /// True for the words the learner is explicitly taught this chapter.
  final bool isTarget;

  /// Pronunciation of the headword. `null` on packs generated before the
  /// clip existed — the card's speaker stays disabled for those.
  final ClipRef? audio;

  /// Recording of [sourceSentence], played whole by the example speaker.
  /// `null` on packs generated before the clip existed — the card falls back
  /// to the paragraph window carved out of the chapter audio.
  final ClipRef? exampleAudio;
}

/// One 4-option multiple-choice comprehension question.
class QuizItem {
  const QuizItem({
    required this.id,
    required this.skill,
    required this.prompt,
    this.promptGloss,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.evidence,
  });

  final String id;

  /// One of: detail, inference, vocabulary, vocabInContext, sequence, mainIdea.
  final String skill;

  /// Content language (English); never translated.
  final String prompt;

  /// Optional learner-language gloss of the prompt.
  final LocalizedText? promptGloss;
  final List<String> options;

  /// Index of the correct option in [options] (0..3).
  final int answer;
  final LocalizedText explanation;

  /// Paragraph id that proves the answer.
  final String evidence;
}

/// Oral retell task of a chapter.
class Retell {
  const Retell({
    required this.scenes,
    required this.rubric,
  });

  final List<Scene> scenes;
  final Rubric rubric;
}

/// One scene of the retell task.
class Scene {
  const Scene({
    required this.id,
    required this.order,
    required this.image,
    required this.prompt,
    required this.concepts,
    required this.hint1,
    required this.hint2,
    required this.suggestedAnswer,
    required this.targetWordCount,
  });

  final String id;

  /// 1-based position of the scene inside the retell task.
  final int order;
  final Media image;

  /// Content language (English); never translated.
  final String prompt;
  final List<Concept> concepts;
  final LocalizedText hint1;
  final LocalizedText hint2;

  /// Content language (English); never translated.
  final String suggestedAnswer;
  final int targetWordCount;
}

/// One scoring concept the learner should express during retell.
class Concept {
  const Concept({
    required this.id,
    required this.label,
    required this.terms,
    required this.required,
  });

  final String id;
  final LocalizedText label;

  /// Closed-set word forms; any one appearing at a word boundary counts as a
  /// hit (no fuzzy matching).
  final List<String> terms;

  /// True when the concept is mandatory for a complete retell.
  final bool required;
}

/// An image reference with localized alt text.
class Media {
  const Media({
    required this.url,
    required this.alt,
  });

  /// `media/...` relative path or `https://` URL.
  final String url;
  final LocalizedText alt;
}

/// Weights and targets used by `scoreRetell`.
class Rubric {
  const Rubric({
    required this.minWords,
    required this.maxSeconds,
    required this.conceptWeight,
    required this.fluencyWeight,
    required this.completenessWeight,
    required this.wpmTargetRange,
  });

  final int minWords;
  final int maxSeconds;
  final double conceptWeight;
  final double fluencyWeight;
  final double completenessWeight;

  /// `[lower, upper]` words-per-minute target band.
  final List<int> wpmTargetRange;
}
