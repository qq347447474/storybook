/// Pure derivations behind the S1 rows: which badge a stage wears, how many of
/// the four steps are behind it, how long a chapter's audio runs.
///
/// Kept out of the widgets so the screen files stay layout-only and the
/// stage -> badge table lives in exactly one place (design-spec §4.2 states,
/// `visual/app.css` `.badge--reading` / `.badge--complete` / `.badge--locked`).
///
/// The plan contract (docs/02) has no "duration" or "sentence count" field:
/// both are summed from the paragraph audio timelines, so S1 never invents a
/// number and an un-audited chapter simply reports what it has.
library;

import 'package:core_content/core_content.dart';

import '../i18n/app_localizations.dart';
import '../ui/components/app_chip.dart';

/// The three pieces of one chapter badge: glyph, catalog key and tone.
///
/// Tones are limited to the three of design-spec §4.2 (brand = in progress,
/// neutral = locked, success = complete); the four in-progress stages differ
/// only in *which* step they name, so the colour never has to carry that.
class ChapterBadgeSpec {
  const ChapterBadgeSpec({
    required this.icon,
    required this.labelKey,
    required this.tone,
  });

  /// Icon name for the `AppIcon` renderer — always paired with [labelKey]
  /// (§7.2: never colour- or glyph-only).
  final String icon;

  /// Catalog key resolved by the caller.
  final String labelKey;

  /// Palette recipe of the badge.
  final AppBadgeTone tone;
}

const ChapterBadgeSpec _lockedSpec = ChapterBadgeSpec(
  icon: 'lock',
  labelKey: 'book.locked',
  tone: AppBadgeTone.neutral,
);

const ChapterBadgeSpec _completeSpec = ChapterBadgeSpec(
  icon: 'check-circle',
  // The badge never carries the long "Chapter complete" line of S6 — that is
  // the celebration heading; a 26 dp pill says "Done" (§4.2 已完成).
  labelKey: 'chapter.done',
  tone: AppBadgeTone.success,
);

const ChapterBadgeSpec _readingSpec = ChapterBadgeSpec(
  icon: 'book',
  labelKey: 'chapter.reading',
  tone: AppBadgeTone.brand,
);

/// Badge of [stage]. Unread chapters read as "Read" (the next action is to
/// start), which is also what the S0 -> S1 regression test pins.
ChapterBadgeSpec badgeOf(ChapterStage stage) {
  switch (stage) {
    case ChapterStage.locked:
      return _lockedSpec;
    case ChapterStage.complete:
      return _completeSpec;
    case ChapterStage.unread:
    case ChapterStage.reading:
      return _readingSpec;
    case ChapterStage.vocabulary:
      return const ChapterBadgeSpec(
        icon: 'cards',
        labelKey: 'chapter.vocabulary',
        tone: AppBadgeTone.brand,
      );
    case ChapterStage.quiz:
      return const ChapterBadgeSpec(
        icon: 'quiz',
        labelKey: 'chapter.quiz',
        tone: AppBadgeTone.brand,
      );
    case ChapterStage.retell:
      return const ChapterBadgeSpec(
        icon: 'mic',
        labelKey: 'chapter.retell',
        tone: AppBadgeTone.brand,
      );
  }
}

/// Steps of the four-stage loop already behind [stage], `0..4`.
///
/// `retell` and `complete` both fill all four: the retell step is *reached*
/// once the quiz is done, and the hand-off draws the finished chapter with a
/// full bar (design-spec §4.2 "已完成").
int stepsOf(ChapterStage stage) {
  switch (stage) {
    case ChapterStage.locked:
    case ChapterStage.unread:
      return 0;
    case ChapterStage.reading:
      return 1;
    case ChapterStage.vocabulary:
      return 2;
    case ChapterStage.quiz:
      return 3;
    case ChapterStage.retell:
    case ChapterStage.complete:
      return 4;
  }
}

/// Number of spoken sentences in [chapter] — the fallback datum when a pack
/// ships no audio timeline.
int sentencesOf(Chapter chapter) {
  int total = 0;
  for (final Paragraph paragraph in chapter.reading) {
    total += paragraph.audio.sentences.length;
  }
  return total;
}

/// Summed audio length of [chapter] in milliseconds (`0` when not generated).
int durationMsOf(Chapter chapter) {
  int total = 0;
  for (final Paragraph paragraph in chapter.reading) {
    final int ms = paragraph.audio.durationMs;
    if (ms > 0) total += ms;
  }
  return total;
}

/// `m:ss` — the hand-off never pads the minute (`0:38`, `2:05`), the same
/// shape S2's player clock uses. Local on purpose: S1 must not depend on S2.
String clock(int milliseconds) {
  final int seconds = milliseconds <= 0 ? 0 : milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Meta items of one chapter card, already localised: sentences, audio length,
/// or — for a chapter with no content yet — the reason it cannot be opened.
///
/// Returns an empty list when there is nothing truthful to show, so the card
/// omits the row instead of rendering a stray separator.
List<String> chapterMetaParts(
  AppLocalizations l10n,
  Chapter chapter, {
  required bool locked,
}) {
  final List<String> parts = <String>[];
  final int sentences = sentencesOf(chapter);
  if (sentences > 0) {
    parts.add(l10n.t('chapter.sentences', args: <String, Object>{
      'count': sentences,
    }));
  }
  final int ms = durationMsOf(chapter);
  if (ms > 0) {
    parts.add(l10n.t('chapter.audio', args: <String, Object>{
      'duration': clock(ms),
    }));
  }
  if (parts.isEmpty && locked) {
    parts.add(l10n.t('chapter.comingSoon'));
  }
  return parts;
}

/// Length legend of the "Chapters" heading.
///
/// Source order, best first — a learner reads this as "how long is this book":
/// 1. `chapter.estimatedMinutes` summed over the chapters. It is a required
///    field of the pack contract (`content-pack.v1` §chapters) and the only
///    number that covers the **whole four-step loop** (listen + words + quiz +
///    retell), which is what a session actually costs. The hand-off's "约 6 分钟"
///    is one chapter's scale; a two-chapter book must read "about 13 min".
/// 2. When every chapter reports `0` (hand-built models, tests) the summed audio
///    length, rounded **up** so the estimate never undercuts the real clip.
/// 3. Then the book's sentence count, when the pack carries no audio timeline.
/// 4. `null` when there is nothing truthful to say — the heading stands alone.
String? bookLengthLabel(AppLocalizations l10n, Book book) {
  int estimated = 0;
  int ms = 0;
  int sentences = 0;
  for (final Chapter chapter in book.chapters) {
    if (chapter.estimatedMinutes > 0) estimated += chapter.estimatedMinutes;
    ms += durationMsOf(chapter);
    sentences += sentencesOf(chapter);
  }
  if (estimated > 0) {
    return l10n.t('book.approxMinutes', args: <String, Object>{
      'minutes': estimated,
    });
  }
  if (ms > 0) {
    final int minutes =
        (ms / Duration.millisecondsPerMinute).ceil().clamp(1, 999);
    return l10n.t('book.approxMinutes', args: <String, Object>{
      'minutes': minutes,
    });
  }
  if (sentences > 0) {
    return l10n.t('chapter.sentences', args: <String, Object>{
      'count': sentences,
    });
  }
  return null;
}

/// Chain lock (S1 rule): a chapter opens only after the chapter before it
/// reached `complete`; the first chapter needs only `available`. Pure
/// derivation over the raw progress map — the UI never invents the rule.
///
/// The lock guards *early* entry only; it never revokes access already
/// earned. A chapter that has itself reached `complete` therefore stays
/// open whatever the chapter before it is doing — re-reading an earlier
/// chapter ("read it again" moves it back to `reading`) must not hide the
/// chapters already finished behind it.
///
/// [orderedIds] is the book's chapter ids sorted by `order` and [index] the
/// position under test; `stages[前一章 id] == complete` is the unlock guard.
/// A missing entry for the previous chapter is simply "not complete".
bool isChapterUnlocked(
  int index,
  Map<String, ChapterStage> stages, {
  required bool available,
  required List<String> orderedIds,
}) {
  if (!available) return false;
  if (index <= 0) return true;
  // Finished chapters keep their access: the predecessor guard below only
  // gates chapters that have not reached `complete` yet.
  if (stages[orderedIds[index]] == ChapterStage.complete) return true;
  return stages[orderedIds[index - 1]] == ChapterStage.complete;
}

/// Index of the chapter the continue journey lands on: the first one that is
/// neither complete nor locked (chain locks included — see
/// [isChapterUnlocked]), or -1 when every chapter is finished or locked.
///
/// "First unfinished and unlocked", deliberately NOT "the furthest-along
/// chapter": a deeper chapter must never steal the resume point from the one
/// the learner actually has open.
int continueChapterIndex(List<ChapterStage> stages) {
  for (int i = 0; i < stages.length; i++) {
    if (stages[i] != ChapterStage.complete &&
        stages[i] != ChapterStage.locked) {
      return i;
    }
  }
  return -1;
}
