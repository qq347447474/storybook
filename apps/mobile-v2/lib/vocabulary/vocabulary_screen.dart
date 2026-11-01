/// Vocabulary screen S3 (design-spec §4.4, `visual/app.css` L1907-2290).
///
/// One card in focus, not a list: the learner flips the current card, walks the
/// rail with previous / next, and the dock unlocks once every **target** word
/// has been looked at (the guard the quiz depends on).
///
/// Language rules (`docs/03`), unchanged from the list version:
/// - the meaning on the back is the gloss of the **gloss locale**, falling back
///   to `locales.defaultGloss` (decision ③) — the hand-off's `back-def` is the
///   learner-language meaning, not the English `definition` field;
/// - the example sentence is story text: never translated, target word picked
///   out in brand bold;
/// - the UI copy around the card is looked up in the catalog, never written
///   here.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../audio/audio_player_service.dart';
import '../audio/clip_window.dart';
import '../i18n/app_localizations.dart';
import '../i18n/gloss_lookup.dart';
import '../reading/reading_controller.dart';
import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../ui/components/dock_cta.dart';
import '../ui/components/stage_app_bar.dart';
import '../ui/components/word_card.dart';
import 'vocab_parts.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({
    super.key,
    required this.controller,
    this.l10n,
    this.appSettings,
    required this.defaultGloss,
    this.mediaResolver,
    this.audioPlayer,
    this.onContinueToQuiz,
    this.onPreviousStep,
    this.onNextStep,
  });

  final ReadingController controller;

  /// Media lookup for the two speakers. `null` keeps both speakers inert
  /// (tests and any screen built without a media stack).
  final MediaResolver? mediaResolver;

  /// Shared audio output; reused so tapping a speaker stops reading first.
  final AudioPlayerService? audioPlayer;

  /// Explicit catalog override (tests); production resolves via [L10nScope]
  /// so language switches rebuild without a restart.
  final AppLocalizations? l10n;

  /// Shared settings; when present gloss switches rebuild this screen live.
  final AppSettings? appSettings;

  /// `locales.defaultGloss` of the pack (decision ③ fallback).
  final String defaultGloss;

  /// Step navigation (practice mode).
  final VoidCallback? onPreviousStep;
  final VoidCallback? onNextStep;

  /// Navigation hook for the dock CTA; when null the dock CTA stays inert.
  final VoidCallback? onContinueToQuiz;

  /// Step index of this screen inside the four-stage loop.
  static const int step = 2;

  /// `--gutter: 20px` (app.css L78).
  static const double gutter = 20;

  /// `.screen--vocab .scroll { padding-top: 4px }` + 24 dp bottom.
  static const EdgeInsets scrollPadding =
      EdgeInsets.fromLTRB(gutter, 4, gutter, 24);

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  /// Cards whose back has been revealed at least once (the "browsed" signal).
  final Set<String> _browsed = <String>{};

  /// Index of the card on screen.
  int _index = 0;

  /// Whether the card on screen currently shows its back.
  bool _revealed = false;

  /// Owns the seek-and-stop for whichever clip is playing.
  final ClipWindow _window = ClipWindow();

  @override
  void initState() {
    super.initState();
    // Restore browsed targets from the state machine (re-entry within the
    // vocabulary stage) so the CTA does not re-lock after a restart.
    _browsed.addAll(widget.controller.state.viewedVocabIds);
    widget.appSettings?.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _window.dispose();
    widget.appSettings?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  /// Resolves the active catalog: explicit override first, then the
  /// [L10nScope] (registers a dependency so language switches rebuild).
  AppLocalizations _l10nOf(BuildContext context) =>
      widget.l10n ?? L10nScope.of(context);

  /// Target words first, pack order otherwise (a learner should meet the words
  /// the quiz will ask about before the supporting ones).
  List<VocabItem> get _items {
    final List<VocabItem> items =
        List<VocabItem>.of(widget.controller.chapter.vocabulary);
    items.sort((VocabItem a, VocabItem b) {
      if (a.isTarget != b.isTarget) return a.isTarget ? -1 : 1;
      return 0;
    });
    return items;
  }

  bool get _allTargetsBrowsed {
    final Set<String> targets = widget.controller.targetVocabIds;
    return targets.every(_browsed.contains);
  }

  /// Indices of the cards already browsed — the filled dots.
  Set<int> _seenIndices(List<VocabItem> items) {
    return <int>{
      for (int i = 0; i < items.length; i++)
        if (_browsed.contains(items[i].id)) i,
    };
  }

  void _toggle() {
    final VocabItem item = _items[_index.clamp(0, _items.length - 1)];
    final bool revealing = !_revealed;
    setState(() => _revealed = revealing);
    if (!revealing) return;
    // Only uncovering the back counts as browsing (design-spec §4.4).
    if (_browsed.add(item.id)) {
      widget.controller.markVocabViewed(item.id);
    }
  }

  void _go(int delta) {
    final int next = _index + delta;
    if (next < 0 || next >= _items.length) return;
    setState(() {
      _index = next;
      // A new card always starts on its front.
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10nOf(context);
    final List<VocabItem> items = _items;
    final bool ready = _allTargetsBrowsed;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            StageAppBar(
              step: VocabularyScreen.step,
              onClose: () => Navigator.of(context).maybePop(),
              closeLabel: l10n.t('nav.close'),
              progressLabel: l10n.t('vocab.stage', args: <String, Object>{
                'step': VocabularyScreen.step,
                'total': 4,
              }),
              onPreviousStep: widget.onPreviousStep,
              onNextStep: widget.onNextStep,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: VocabularyScreen.scrollPadding,
                child: Column(
                  children: <Widget>[
                    VocabHead(
                      eyebrow: l10n.t('vocab.stage', args: <String, Object>{
                        'step': VocabularyScreen.step,
                        'total': 4,
                      }),
                      title: l10n.t('vocab.heading'),
                      count: l10n.t('vocab.cardCount', args: <String, Object>{
                        'current': items.isEmpty ? 0 : _index + 1,
                        'total': items.length,
                      }),
                    ),
                    if (items.isNotEmpty) _card(l10n, items) else const SizedBox.shrink(),
                    WordNav(
                      previous: WordNavButton(
                        key: const Key('vocab-prev'),
                        icon: 'chevron-left',
                        label: l10n.t('vocab.prev'),
                        onPressed: _index > 0 ? () => _go(-1) : null,
                      ),
                      next: WordNavButton(
                        key: const Key('vocab-next'),
                        icon: 'chevron-right',
                        label: l10n.t('vocab.next'),
                        onPressed: _index < items.length - 1
                            ? () => _go(1)
                            : null,
                      ),
                      dots: WordDots(
                        count: items.length,
                        current: _index,
                        seen: _seenIndices(items),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppDock(
              key: const Key('vocab-continue'),
              primaryLabel: l10n.t('nav.next'),
              helper: l10n.t(ready ? 'vocab.helperReady' : 'vocab.helper'),
              helperIsReady: ready,
              onPrimaryPressed: ready ? widget.onContinueToQuiz : null,
            ),
          ],
        ),
      ),
    );
  }

  /// The one card in focus. `vocab-card-<id>` stays on it, so a test (or a
  /// future deep link) can name the word being shown.
  Widget _card(AppLocalizations l10n, List<VocabItem> items) {
    final VocabItem item = items[_index.clamp(0, items.length - 1)];
    final _ExampleRange? example = _exampleRangeOf(item);
    return WordCard(
      key: Key('vocab-card-${item.id}'),
      word: item.surfaceForm,
      // The pack carries no IPA transcription (`content-pack.v1` has none), so
      // the phonetic line stays empty instead of inventing one.
      phonetic: '',
      partOfSpeech: item.partOfSpeech,
      revealed: _revealed,
      // §4.4: the back shows the meaning in the *gloss locale* (decision ③),
      // falling back to the pack's default gloss.
      definition: glossOf(
        item.gloss,
        widget.controller.glossLocale,
        widget.defaultGloss,
      ),
      frontHint: l10n.t('vocab.flip'),
      backHint: l10n.t('vocab.flipBack'),
      example: item.sourceSentence,
      // `.example-label` above the quote — the story origin, in UI copy.
      exampleLabel: l10n.t('vocab.inSentence'),
      exampleTarget: item.surfaceForm,
      // Front speaker: the headword. Disabled (dimmed) when the pack predates
      // word clips — a null callback, never a broken button.
      onSpeakWord:
          item.audio != null && _canPlay ? () => _speakWord(item) : null,
      speakWordLabel: l10n.t('vocab.listenWord'),
      // Back speaker: the example sentence. A pack with `exampleAudio` plays
      // that standalone clip — the exact sourceSentence, so it always matches
      // the text on the card. Older packs fall back to the sentence window
      // inside the paragraph clip.
      onSpeakExample:
          _canPlay && (item.exampleAudio != null || example != null)
              ? () => _speakExample(item, example)
              : null,
      speakExampleLabel: l10n.t('vocab.listenExample'),
      onToggle: _toggle,
    );
  }

  bool get _canPlay =>
      widget.mediaResolver != null && widget.audioPlayer != null;

  /// Where the example sentence sits inside the chapter's audio.
  ///
  /// The example is story text: it matches one entry of some paragraph's
  /// `audio.sentences` timeline exactly, so the clip to play is that paragraph's
  /// file between `startMs` and `endMs`. Deriving it here means the card works
  /// for packs generated before any vocabulary audio existed — only the
  /// headword needs its own clip.
  _ExampleRange? _exampleRangeOf(VocabItem item) {
    final String wanted = item.sourceSentence.trim();
    if (wanted.isEmpty) return null;
    for (final Paragraph para in widget.controller.chapter.reading) {
      final AudioTimeline audio = para.audio;
      for (final SpokenSentence sentence in audio.sentences) {
        if (sentence.text.trim() == wanted) {
          return _ExampleRange(
            url: audio.url,
            startMs: sentence.startMs,
            endMs: sentence.endMs,
          );
        }
      }
    }
    return null;
  }

  /// The headword, played whole. The clip is one utterance, so the window is
  /// its own measured length — the same stop rules as a sentence window.
  Future<void> _speakWord(VocabItem item) async {
    final ClipRef? clip = item.audio;
    if (clip == null || widget.mediaResolver == null || widget.audioPlayer == null) {
      return;
    }
    await _window.play(
      resolver: widget.mediaResolver!,
      player: widget.audioPlayer!,
      url: clip.url,
      startMs: 0,
      endMs: clip.durationMs,
    );
  }

  /// The example sentence.
  ///
  /// With `exampleAudio` the pack carries a standalone recording of exactly
  /// [VocabItem.sourceSentence] — play it whole and the file itself is the
  /// stop. Without it (packs generated before the clip existed), fall back to
  /// the sentence window inside the paragraph clip.
  Future<void> _speakExample(VocabItem item, _ExampleRange? range) async {
    if (!_canPlay) return;
    final ClipRef? clip = item.exampleAudio;
    if (clip != null) {
      await _window.play(
        resolver: widget.mediaResolver!,
        player: widget.audioPlayer!,
        url: clip.url,
        startMs: 0,
        endMs: clip.durationMs,
      );
      return;
    }
    if (range == null) return;
    await _window.play(
      resolver: widget.mediaResolver!,
      player: widget.audioPlayer!,
      url: range.url,
      startMs: range.startMs,
      endMs: range.endMs,
    );
  }
}

/// The example sentence's window inside the paragraph clip.
class _ExampleRange {
  const _ExampleRange({
    required this.url,
    required this.startMs,
    required this.endMs,
  });

  final String url;
  final int startMs;
  final int endMs;
}
