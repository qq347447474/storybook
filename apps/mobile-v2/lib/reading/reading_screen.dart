/// Reading screen S2 (design-spec §4.3, `visual/app.css` L1650-1960).
///
/// Layout and the "read" signal only: the virtual timeline and every media call
/// live in [ReadingPlayback] (docs/13 D3). The screen renders
/// head -> scene -> player -> reading card -> hint, marks a paragraph read when
/// it has been on screen, and enables the dock once the state machine reached
/// `vocabulary`.
///
/// A paragraph whose audio is missing never blocks the page: the player dims, a
/// retry row appears, and the body text stays readable (C6). No score and no
/// progress percentage - the only counter is the sentence the playhead is in.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../audio/audio_player_service.dart';
import '../i18n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../ui/app_icon.dart';
import '../ui/components/dock_cta.dart';
import '../ui/components/reading_player.dart';
import '../ui/components/stage_app_bar.dart';
import 'reading_controller.dart';
import 'reading_parts.dart';
import 'reading_playback.dart';
import 'reading_scene.dart';
import 'sentence_highlight.dart';

/// One paragraph block is at least this visible before it counts as read.
const double _visibleThresholdPx = 24;

/// The illustration of each chapter, by `order`, until the pack carries a scene
/// field of its own (design-spec §4.3 names exactly these two plates).
const Map<int, String> _sceneByOrder = <int, String>{
  1: 'scene-rain-window',
  2: 'scene-puddle-boat',
};

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.controller,
    required this.mediaResolver,
    required this.audioPlayer,
    required this.l10n,
    required this.bookTitle,
    this.coverUrl,
    this.onContinueToVocabulary,
    this.onPreviousStep,
    this.onNextStep,
  });

  final ReadingController controller;
  final MediaResolver mediaResolver;
  final AudioPlayerService audioPlayer;

  /// Explicit catalog override (tests); production resolves via [L10nScope].
  final AppLocalizations? l10n;
  final String bookTitle;

  /// The book's cover art (`book.cover.url`). Shown on the story plate when
  /// the chapter carries no scene illustration of its own.
  final String? coverUrl;

  /// Navigation hook of the dock CTA, enabled once every paragraph is read.
  final VoidCallback? onContinueToVocabulary;

  /// Step navigation (practice mode).
  final VoidCallback? onPreviousStep;
  final VoidCallback? onNextStep;

  /// Step index of this screen inside the four-stage loop.
  static const int step = 1;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _paragraphKeys = <GlobalKey>[];
  late final ReadingPlayback _playback = ReadingPlayback(
    paragraphs: widget.controller.chapter.reading,
    resolver: widget.mediaResolver,
    player: widget.audioPlayer,
  );

  List<Paragraph> get _paragraphs => widget.controller.chapter.reading;

  AppLocalizations _l10nOf(BuildContext context) =>
      widget.l10n ?? L10nScope.of(context);

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _paragraphs.length; i++) {
      _paragraphKeys.add(GlobalKey());
    }
    _playback.addListener(_onChanged);
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
      _playback.start();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _playback.removeListener(_onChanged);
    _playback.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Marks every paragraph block currently on screen as read (the guard of the
  /// `reading -> vocabulary` transition).
  void _checkVisibility() {
    if (!mounted) return;
    final double height = MediaQuery.sizeOf(context).height;
    for (int i = 0; i < _paragraphs.length && i < _paragraphKeys.length; i++) {
      final RenderObject? box =
          _paragraphKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final Offset pos = box.localToGlobal(Offset.zero);
      final bool visible = pos.dy < height - _visibleThresholdPx &&
          pos.dy + box.size.height > _visibleThresholdPx;
      if (visible) {
        widget.controller.markParagraphRead(_paragraphs[i].id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10nOf(context);
    final bool canContinue =
        widget.controller.state.stage.index >= ChapterStage.vocabulary.index;
    // Greyed CTA owes an explanation (AppDock §5.1), route or no route.
    final VoidCallback? continueAction =
        canContinue ? widget.onContinueToVocabulary : null;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            StageAppBar(
              step: ReadingScreen.step,
              onClose: () => Navigator.of(context).maybePop(),
              closeLabel: l10n.t('nav.close'),
              progressLabel: l10n.t('s2.stage', args: <String, Object>{
                'step': ReadingScreen.step,
                'total': 4,
              }),
              onPreviousStep: widget.onPreviousStep,
              onNextStep: widget.onNextStep,
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  _checkVisibility();
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ChapterHead(
                        eyebrow: l10n.t('s2.eyebrow', args: <String, Object>{
                          'title': widget.bookTitle.toUpperCase(),
                          'n': widget.controller.chapter.order,
                        }),
                        title: widget.controller.chapter.title,
                      ),
                      SceneFigure(
                        illustration:
                            _sceneByOrder[widget.controller.chapter.order] ??
                                'scene-rain-window',
                        caption: l10n.t('s2.audioBadge'),
                        alt: sceneAltOf(
                          widget.controller.chapter.retell.scenes,
                          widget.controller.glossLocale,
                        ),
                        mediaResolver: widget.mediaResolver,
                        // Pack art first: the chapter's own story plate, then
                        // the book cover. The bundled default is only for
                        // packs that shipped without images.
                        artCandidates: <String>[
                          if (widget.controller.chapter.retell.scenes.isNotEmpty)
                            widget
                                .controller.chapter.retell.scenes.first.image.url,
                          if (widget.coverUrl != null) widget.coverUrl!,
                        ],
                      ),
                      const SizedBox(height: 16),
                      ReadingPlayer(
                        key: const Key('reading-player'),
                        position: _playback.globalPosition,
                        duration: _playback.totalDuration,
                        isPlaying: _playback.isPlaying,
                        speed: _playback.speed,
                        enabled: _playback.playable,
                        onPlayPause: _playback.togglePlayPause,
                        onSeek: _playback.seekFraction,
                        onSpeedCycle: _playback.cycleSpeed,
                        playLabel: l10n.t('reading.play'),
                        pauseLabel: l10n.t('reading.pause'),
                        speedLabel: l10n.t('reading.speed'),
                        seekLabel: l10n.t('a11y.progress'),
                      ),
                      _audioStatus(l10n),
                      const SizedBox(height: 16),
                      ReadingCard(
                        followLabel: l10n.t('s2.follow'),
                        counter: _sentenceCounter(),
                        sentences: _storySentences(),
                        sentenceKeyPrefix: 'sentence',
                        paragraphKeys: _paragraphKeys,
                      ),
                      TapHint(text: l10n.t('s2.tapHint')),
                    ],
                  ),
                ),
              ),
            ),
            AppDock(
              key: const Key('reading-continue'),
              primaryLabel: l10n.t('nav.next'),
              helper: continueAction != null ? null : l10n.t('s2.helper'),
              onPrimaryPressed: continueAction,
            ),
          ],
        ),
      ),
    );
  }

  /// `2 / 6` - the sentence the playhead sits in, counted across the chapter.
  String _sentenceCounter() {
    int total = 0;
    int current = 0;
    for (int i = 0; i < _paragraphs.length; i++) {
      final int count = _paragraphs[i].audio.sentences.length;
      if (i < _playback.active) current += count;
      total += count;
    }
    if (_playback.started) {
      current +=
          sentenceIndexAt(
                _playback.positionInParagraph.inMilliseconds,
                _paragraphs[_playback.active].audio.sentences,
              ) +
              1;
    }
    return '${current.clamp(0, total)} / $total';
  }

  /// Sentences grouped per paragraph, tagged with their highlight state.
  List<List<StorySentence>> _storySentences() {
    final int activeSentence = _playback.started
        ? sentenceIndexAt(
            _playback.positionInParagraph.inMilliseconds,
            _paragraphs[_playback.active].audio.sentences,
          )
        : -1;
    final List<String> vocabulary = <String>[
      for (final VocabItem item in widget.controller.chapter.vocabulary)
        item.surfaceForm,
    ];

    return <List<StorySentence>>[
      for (int p = 0; p < _paragraphs.length; p++)
        <StorySentence>[
          for (int s = 0; s < _paragraphs[p].audio.sentences.length; s++)
            StorySentence(
              text: _paragraphs[p].audio.sentences[s].text,
              current: p == _playback.active && s == activeSentence,
              onTap: () => _playback.playSentence(p, s),
              words: vocabulary,
            ),
        ],
    ];
  }

  /// Degraded audio notice for the active paragraph: no resolvable clip
  /// (`audio-placeholder-`) or one that failed to load (`audio-error-`, C6).
  Widget _audioStatus(AppLocalizations l10n) {
    if (_paragraphs.isEmpty) return const SizedBox.shrink();
    final String id = _paragraphs[_playback.active].id;
    final bool loadFailed = _playback.failed(id);
    if (!loadFailed && _playback.mediaOf(id) != null) {
      return const SizedBox.shrink();
    }
    final TextStyle? body = Theme.of(context).textTheme.bodySmall;
    return Padding(
      key: Key(loadFailed ? 'audio-error-$id' : 'audio-placeholder-$id'),
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: <Widget>[
          const AppIcon('alert', size: 16, color: AppColors.ink3),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.t('err.audio'), style: body)),
          TextButton(
            key: Key('audio-retry-$id'),
            onPressed: () => _playback.retry(id),
            child: Text(l10n.t('err.retry')),
          ),
        ],
      ),
    );
  }
}
