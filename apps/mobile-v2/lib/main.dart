/// App entry: wires the pure-Dart core packages to platform services at the
/// registration point (C8), then boots the library (S0). Screens navigate
/// S0 -> S1 -> (S2 -> S3 -> S4) with stage-based re-entry, and S7 settings
/// take effect immediately through [L10nScope] (no restart).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_content/core_content.dart';
import 'package:core_speech/core_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'audio/audio_player_service.dart';
import 'audio/mic_permission.dart';
import 'audio/production_bindings.dart';
import 'audio/retell_audio_source.dart';
import 'completion/completion_screen.dart';
import 'contents/contents_meta.dart';
import 'contents/contents_screen.dart';
import 'i18n/app_localizations.dart';
import 'library/cached_pack_normalizer.dart';
import 'library/library_screen.dart';
import 'library/local_book_delete.dart';
import 'quiz/quiz_screen.dart';
import 'reading/reading_controller.dart';
import 'reading/reading_screen.dart';
import 'retell/retell_screen.dart';
import 'settings/app_settings.dart';
import 'settings/settings_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'ui/welcome_screen.dart';
import 'vocabulary/vocabulary_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Preload the en catalog so the error screen has real copy even when the
  // content pack fails to load (T7d: an empty fallback echoed raw keys).
  AppLocalizations.load('en');
  runApp(const StoryApp());
}

/// Bootstrap scaffolding ground. Kept as an alias (used by the loading and
/// error scaffolds below) so those call sites stay on the design token.
const Color _appBackground = AppColors.paper;

/// The app ships **no built-in book**: the shelf starts empty and every title
/// comes from "设置 -> 更新书本" (the download cache under `storyapp_cache/`).
/// The empty shelf guides the learner there.
///
/// Offline-map paths like `media/cover.png` are content-relative and become
/// full asset keys as `_bundleAssetPrefix + path` — joined in exactly one
/// place, inside DefaultMediaResolver (T7d-2). Historically misnamed
/// `_devBundledPrefix`; renamed for clarity.
const String _bundleAssetPrefix = 'assets/content/the-paper-boat/';

/// Route name of S1. The only named route in the app: S6 needs one stable
/// anchor to return to ("back to contents" must unwind S5..S2, not step back
/// into the retell screen), and a name is what `popUntil` can match — matching
/// on a widget type would couple the bootstrap to S1's constructor.
const String _contentsRoute = '/contents';

/// Pops back to S1. The `isFirst` arm is load-bearing: `Navigator.popUntil`
/// keeps popping while its predicate is false, so a stack that somehow lacks
/// `/contents` (deep link, a future entry point) would unwind past S1 and empty
/// the navigator instead of stopping at the root route.
bool _isContentsOrRoot(Route<dynamic> route) =>
    route.settings.name == _contentsRoute || route.isFirst;

/// The active UI catalog, published by the bootstrap and consumed by
/// [StoryApp] to wrap [MaterialApp] in [L10nScope]. The scope MUST sit
/// above the Navigator (T7d-3): pushed routes (S1..S7) resolve it through
/// their Overlay context, which cannot see inside the home subtree.
/// Swapping the value rebuilds the whole tree — including pushed routes —
/// preserving the T6 "switch language without restart" semantics.
final ValueNotifier<AppLocalizations> activeL10n =
    ValueNotifier<AppLocalizations>(AppLocalizations.cached('en') ??
        AppLocalizations('en', const <String, String>{}));

/// The global "reduce motion" flag (S7 preference), published by the
/// bootstrap and consumed by [StoryApp] to fold the preference into
/// [MediaQueryData.disableAnimations] **above** [MaterialApp]. Every route
/// then inherits it — including the S2–S5 top rail and the pushed overlays —
/// instead of only the S7 subtree (design-spec §2.6: the in-app switch and
/// the system `prefers-reduced-motion` both switch off confetti, flips,
/// pulses and transitions).
final ValueNotifier<bool> activeReduceMotion = ValueNotifier<bool>(false);

/// Publishes the S7 preference to the hoisted [activeReduceMotion] notifier
/// (post-frame for the same reason as [_publishL10n]: never mutate a
/// listenable while the tree is building).
void _publishReduceMotion(bool value) {
  if (activeReduceMotion.value == value) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (activeReduceMotion.value != value) {
      activeReduceMotion.value = value;
    }
  });
}

/// Publishes the active catalog to the hoisted [activeL10n] notifier
/// (post-frame: never mutate a listenable during build).
void _publishL10n(AppLocalizations? l10n) {
  final AppLocalizations next = l10n ??
      AppLocalizations.cached('en') ??
      AppLocalizations('en', const <String, String>{});
  if (identical(next, activeL10n.value)) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!identical(next, activeL10n.value)) {
      activeL10n.value = next;
    }
  });
}

class StoryApp extends StatelessWidget {
  const StoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLocalizations>(
      valueListenable: activeL10n,
      builder: (BuildContext context, AppLocalizations l10n, Widget? _) {
        return ValueListenableBuilder<bool>(
          valueListenable: activeReduceMotion,
          builder: (BuildContext context, bool reduceMotion, Widget? _) {
            // The root `View` is the only MediaQuery source above
            // [MaterialApp] (WidgetsApp never introduces one), so the S7
            // preference is folded in here and inherited by every route.
            // The flag only ever *adds* to the platform setting: switching
            // the app switch off must not re-enable motion the system asked
            // to suppress (design-spec §4.8).
            final MediaQueryData media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                disableAnimations: media.disableAnimations || reduceMotion,
              ),
              child: L10nScope(
                l10n: l10n,
                child: MaterialApp(
                  theme: buildAppTheme(),
                  localizationsDelegates:
                      const <LocalizationsDelegate<dynamic>>[
                    DefaultMaterialLocalizations.delegate,
                  ],
                  home: const AppBootstrap(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Everything the screens need, assembled from platform services.
class _AppGraph {
  const _AppGraph({
    required this.pack,
    required this.settings,
    required this.mediaResolver,
    required this.audioPlayer,
    required this.engine,
    required this.audioSource,
    required this.micPermission,
    required this.progressStore,
    required this.bookStarted,
    required this.chapterStages,
    required this.bookId,
    required this.defaultGloss,
    required this.contentVersion,
    required this.cachedBookIds,
  });

  final ContentPack pack;
  final AppSettings settings;
  final MediaResolver mediaResolver;
  final AudioPlayerService audioPlayer;
  final SpeechEngine engine;
  final RetellAudioSource audioSource;
  final MicPermissionService micPermission;
  final ProgressStore progressStore;
  final Map<String, bool> bookStarted;
  final Map<String, Map<String, ChapterStage>> chapterStages;
  final String bookId;
  final String defaultGloss;
  final String contentVersion;

  /// Books that came from `storyapp_cache/` — the only deletable ones.
  final Set<String> cachedBookIds;

  ReadingController controllerFor(Book book, Chapter chapter) {
    return ReadingController(
      bookId: book.id,
      chapter: chapter,
      packId: bookId,
      contentVersion: contentVersion,
      progressStore: progressStore,
      appSettings: settings,
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<_AppGraph> _graph = _assemble();
  bool _splashDone = false;

  Future<_AppGraph> _assemble() async {
    Future<Uint8List> readAsset(String key) async {
      final ByteData data = await rootBundle.load(key);
      return data.buffer.asUint8List();
    }

    // Real app version (package_info_plus); used for minAppVersion checks
    // and the S7 version row.
    String appVersion = '0.0.0';
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      appVersion = info.version;
    } on Exception catch (_) {
      // Platform channel unavailable (tests) — version display falls back.
    }

    final JsonContentRepository repo = JsonContentRepository(
      appVersion: appVersion,
      readAsset: readAsset,
    );
    // No bundled sample: the shelf starts empty and is filled only by the
    // download cache below ("设置 -> 更新书本").
    ContentPack pack = ContentPack(
      schemaVersion: 1,
      contentVersion: '1.0.0',
      minAppVersion: '0.0.0',
      locales: const Locales(
        content: <String>['en'],
        gloss: <String>['zh-Hans', 'en'],
        defaultGloss: 'zh-Hans',
      ),
      books: const <Book>[],
    );

    // Merge books from download cache (settings > update books)
    final Set<String> cachedBookIds = <String>{};
    try {
      final cacheBase = await getApplicationSupportDirectory();
      final cacheDir = Directory('${cacheBase.path}/storyapp_cache');
      if (cacheDir.existsSync()) {
        for (final entity in cacheDir.listSync()) {
          if (entity is! Directory) continue;
          final packFile = File('${entity.path}/pack.json');
          if (!packFile.existsSync()) continue;
          try {
            final raw = jsonDecode(packFile.readAsStringSync())
                as Map<String, dynamic>;
            final repaired = normalizeCachedPack(raw);
            // Write back only when the repair actually changed something, so
            // a healthy pack is never rewritten on every launch.
            if (jsonEncode(repaired) != jsonEncode(raw)) {
              packFile.writeAsStringSync(jsonEncode(repaired));
            }

            // Parse the bytes we already hold: a second async file read here
            // would stall the bootstrap under a test's fake clock, and the
            // text is identical to what is on disk at this point.
            final cachedResult = repo.loadFromJsonText(jsonEncode(repaired));
            if (cachedResult is! PackOk) {
              // The cache cannot be rendered. Drop it so "更新书本" offers the
              // download again instead of leaving a permanently dead row.
              entity.deleteSync(recursive: true);
              continue;
            }
            final existingIds = pack.books.map((b) => b.id).toSet();
            final newBooks = cachedResult.pack.books
                .where((b) => !existingIds.contains(b.id))
                .toList();
            if (newBooks.isNotEmpty) {
              for (final Book b in newBooks) {
                cachedBookIds.add(b.id);
              }
              pack = ContentPack(
                schemaVersion: pack.schemaVersion,
                contentVersion: pack.contentVersion,
                minAppVersion: pack.minAppVersion,
                locales: pack.locales,
                books: [...pack.books, ...newBooks],
              );
            }
          } catch (_) {
            // Unreadable cache: same treatment as an invalid pack.
            entity.deleteSync(recursive: true);
          }
        }
      }
    } catch (_) {}

    // Zero-book safe: the shelf may legitimately be empty on first launch.
    // Progress and settings hang off the first book's id when there is one;
    // with none they share an empty-key document that nothing writes to.
    final Book? book = pack.books.isEmpty ? null : pack.books.first;

    OfflineMediaMap map = OfflineMediaMap.empty();

    final Directory support = await getApplicationSupportDirectory();
    final MediaResolver resolver = DefaultMediaResolver(
      offlineEntries: map.entries,
      bundledAssetPrefix: _bundleAssetPrefix,
      // Receives the FULL asset key (prefix already joined by the resolver).
      readBundled: (String assetKey) async {
        try {
          final ByteData data = await rootBundle.load(assetKey);
          return data.buffer.asUint8List();
        } on Exception catch (_) {
          return null;
        }
      },
      cacheDir: support.path,
      fetchRemote: httpFetch,
    );

    final ProgressStore progressStore =
        FileProgressStore(directory: support.path);
    // The progress document is shared per pack; with no book there is nothing
    // to name it after, and the empty key is simply never written.
    final String packKey = book?.id ?? '';
    final AppSettings settings = AppSettings(
      store: progressStore,
      packId: packKey,
      appVersion: appVersion,
    );
    await settings.load();

    // Progress-aware book/chapter states for S0/S1.
    final ProgressDoc doc = await progressStore.load(packKey);
    final Map<String, bool> bookStarted = <String, bool>{};
    final Map<String, Map<String, ChapterStage>> chapterStages =
        <String, Map<String, ChapterStage>>{};
    for (final Book b in pack.books) {
      bookStarted[b.id] = false;
      final Map<String, ChapterStage> stages = <String, ChapterStage>{};
      for (final Chapter ch in b.chapters) {
        final ProgressChapter? entry =
            doc.chapters[progressChapterKey(b.id, ch.id)];
        if (entry != null) {
          bookStarted[b.id] = true;
          stages[ch.id] = _stageOf(entry.status);
        } else {
          stages[ch.id] =
              ch.available ? ChapterStage.unread : ChapterStage.locked;
        }
      }
      chapterStages[b.id] = stages;
    }

    return _AppGraph(
      pack: pack,
      settings: settings,
      mediaResolver: resolver,
      audioPlayer: JustAudioPlayerService(),
      engine: SherpaSpeechEngine(supportDir: support.path),
      audioSource: RecordRetellAudioSource(fileDirectory: support.path),
      micPermission: PermissionHandlerMicPermission(),
      progressStore: progressStore,
      bookStarted: bookStarted,
      chapterStages: chapterStages,
      bookId: packKey,
      defaultGloss: pack.locales.defaultGloss,
      contentVersion: pack.contentVersion,
      cachedBookIds: cachedBookIds,
    );
  }

  ChapterStage _stageOf(String status) {
    for (final ChapterStage s in ChapterStage.values) {
      if (s.name == status) return s;
    }
    return ChapterStage.unread;
  }

  void _openBook(BuildContext context, _AppGraph graph, Book book) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      // Named so S6 can unwind straight back here (see [_contentsRoute]).
      settings: const RouteSettings(name: _contentsRoute),
      builder: (_) => ContentsScreen(
        book: book,
        chapterStages: graph.chapterStages[book.id] ?? const <String, ChapterStage>{},
        l10n: null,
        // S1 chrome: the mini book strip needs the resolver for its cover
        // thumbnail, and the app bar carries the global S7 bypass (§4.2).
        mediaResolver: graph.mediaResolver,
        onOpenSettings: () => _openSettings(context, graph),
        onOpenChapter: (Chapter chapter) =>
            _openChapter(context, graph, book, chapter),
      ),
    ));
  }

  void _openChapter(
      BuildContext context, _AppGraph graph, Book book, Chapter chapter) {
    // Chain lock (S1 rule): never open a chapter whose predecessor is not
    // `complete` — the contents screen already renders it disabled, this is
    // the second line of defence ("锁定点击：不跳转，不弹错误").
    final List<Chapter> chapters = List<Chapter>.of(book.chapters)
      ..sort((Chapter a, Chapter b) => a.order.compareTo(b.order));
    final List<String> orderedIds = <String>[
      for (final Chapter c in chapters) c.id,
    ];
    final int index = orderedIds.indexOf(chapter.id);
    final bool unlocked = index >= 0 &&
        isChapterUnlocked(
          index,
          graph.chapterStages[book.id] ?? const <String, ChapterStage>{},
          available: chapter.available,
          orderedIds: orderedIds,
        );
    if (!unlocked) return;

    final ReadingController controller = graph.controllerFor(book, chapter);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ChapterHost(graph: graph, controller: controller),
    ));
  }

  void _openSettings(BuildContext context, _AppGraph graph) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(
        settings: graph.settings,
        glossLocales: graph.pack.locales.gloss,
        // Optional: with an empty shelf there is no active pack to credit.
        attribution: graph.pack.books.isEmpty
            ? null
            : graph.pack.books.first.attribution,
        l10n: null,
        onBookDownloaded: () {
          // Trigger pack reload after downloading books
          setState(() {
            _graph = _assemble();
          });
        },
      ),
    ));
  }

  /// Library list long-press → confirmed delete: remove the cached pack, its
  /// media files and the book's progress entries, then rebuild the graph so
  /// the shelf drops the row (same reload the download path uses).
  Future<void> _deleteBook(_AppGraph graph, Book book) async {
    final Directory support = await getApplicationSupportDirectory();
    await deleteLocalBook(
      bookId: book.id,
      supportDir: support,
      progressStore: graph.progressStore,
      // The shared progress document is named after the pack's first book.
      progressPackId: graph.bookId,
    );
    if (!mounted) return;
    setState(() {
      _graph = _assemble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppGraph>(
      future: _graph,
      builder: (BuildContext context, AsyncSnapshot<_AppGraph> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: _appBackground,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: _appBackground,
            body: Center(child: _ErrorText()),
          );
        }
        final _AppGraph graph = snapshot.data!;
        // Show welcome splash on first launch while ASR model loads.
        if (!_splashDone) {
          return ListenableBuilder(
            listenable: graph.settings,
            builder: (BuildContext context, Widget? _) {
              _publishL10n(graph.settings.l10n);
              _publishReduceMotion(graph.settings.reduceMotion);
              return WelcomeScreen(
                appName: '纸舟',
                onDone: () {
                  // Kick off ASR model loading during the splash.
                  graph.engine.ensureModelReady();
                  if (mounted) setState(() => _splashDone = true);
                },
              );
            },
          );
        }
        return ListenableBuilder(
          listenable: graph.settings,
          builder: (BuildContext context, Widget? _) {
            _publishL10n(graph.settings.l10n);
            _publishReduceMotion(graph.settings.reduceMotion);
            // L10nScope is hoisted above MaterialApp (T7d-3) - the home
            // content resolves it through the Navigator's overlay.
            return Builder(
              builder: (BuildContext context) => LibraryScreen(
                pack: graph.pack,
                bookStarted: graph.bookStarted,
                chapterStages: graph.chapterStages,
                mediaResolver: graph.mediaResolver,
                l10n: null,
                downloadedBookIds: graph.cachedBookIds,
                onDeleteBook: (Book book) => _deleteBook(graph, book),
                onOpenBook: (Book book) => _openBook(context, graph, book),
                onOpenSettings: () => _openSettings(context, graph),
              ),
            );
          },
        );
      },
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? scoped =
        context.dependOnInheritedWidgetOfExactType<L10nScope>()?.l10n;
    // Fallback chain: L10nScope (normal) -> preloaded en catalog (error
    // screen, when no scope exists) -> empty catalog as the last resort.
    // The empty catalog would echo raw key names - kept only as a final
    // guard; main() preloads en so this should never be reached.
    final AppLocalizations l10n = scoped ??
        AppLocalizations.cached('en') ??
        AppLocalizations('en', const <String, String>{});
    return Text(l10n.t('err.content'));
  }
}

/// Loads chapter progress, then shows the S2->S3->S4 chain with re-entry
/// based on the persisted stage.
class _ChapterHost extends StatelessWidget {
  const _ChapterHost({required this.graph, required this.controller});

  final _AppGraph graph;
  final ReadingController controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: controller.openChapter(),
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: _appBackground,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return ListenableBuilder(
          listenable: graph.settings,
          builder: (BuildContext context, Widget? _) {
            _publishL10n(graph.settings.l10n);
            // Scope hoisted above the Navigator (T7d-3); chain screens
            // resolve it through their route context.
            return Builder(
              builder: (BuildContext context) =>
                  _chainFor(context, graph, controller),
            );
          },
        );
      },
    );
  }


  Widget _chainFor(
      BuildContext context, _AppGraph graph, ReadingController controller) {
    // Capture the navigator once: the context may be deactivated by the time
    // a step-arrow callback fires after pushReplacement.
    final NavigatorState nav = Navigator.of(context);

    /// Unwinds S5..S2 back to the contents list (design-spec §4.7: the primary
    /// action of S6 is "back to contents", not "one screen back").
    void backToContents() => nav.popUntil(_isContentsOrRoot);

    Widget buildCompletion() => CompletionScreen(
          reduceMotion: graph.settings.reduceMotion,
          l10n: null,
          chapter: controller.chapter,
          bookTitle: graph.pack.books.first.title,
          onDone: backToContents,
          onReplay: () async {
            await controller.reopenForReading();
            if (!context.mounted) return;
            nav.pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => _ChapterHost(graph: graph, controller: controller),
              ),
              _isContentsOrRoot,
            );
          },
        );

    // Navigation: build screen for a given step (1-4) with step arrows.
    // Each screen gets callbacks that call goToStep for navigation.
    Widget buildStepScreen(int step) {
      final Widget screen;
      switch (step) {
        case 1:
          screen = ReadingScreen(
            controller: controller,
            mediaResolver: graph.mediaResolver,
            audioPlayer: graph.audioPlayer,
            l10n: null,
            bookTitle: graph.pack.books.first.title,
            coverUrl: graph.pack.books.first.cover.url,
            onContinueToVocabulary: () {
              debugPrint('[NAV] onContinueToVocabulary tapped');
              nav.push(
                MaterialPageRoute<void>(builder: (_) => buildStepScreen(2)),
              );
            },
            onPreviousStep: null,
            onNextStep: () {
              debugPrint('[NAV] onNextStep (1->2) tapped');
              try {
                nav.push(
                  MaterialPageRoute<void>(builder: (_) => buildStepScreen(2)),
                );
                debugPrint('[NAV] push succeeded');
              } catch (e) {
                debugPrint('[NAV] push FAILED: $e');
              }
            },
          );
        case 2:
          screen = VocabularyScreen(
            controller: controller,
            l10n: null,
            appSettings: graph.settings,
            defaultGloss: graph.defaultGloss,
            mediaResolver: graph.mediaResolver,
            audioPlayer: graph.audioPlayer,
            onContinueToQuiz: () => nav.push(
              MaterialPageRoute<void>(builder: (_) => buildStepScreen(3)),
            ),
            onPreviousStep: () => nav.pushReplacement(
              MaterialPageRoute<void>(builder: (_) => buildStepScreen(1)),
            ),
            onNextStep: () => nav.pushReplacement(
              MaterialPageRoute<void>(builder: (_) => buildStepScreen(3)),
            ),
          );
        case 3:
          screen = QuizScreen(
            controller: controller,
            l10n: null,
            appSettings: graph.settings,
            defaultGloss: graph.defaultGloss,
            onContinueToRetell: () => nav.push(
              MaterialPageRoute<void>(builder: (_) => buildStepScreen(4)),
            ),
            onPreviousStep: () => nav.pushReplacement(
              MaterialPageRoute<void>(builder: (_) => buildStepScreen(2)),
            ),
            onNextStep: () => nav.pushReplacement(
              MaterialPageRoute<void>(builder: (_) => buildStepScreen(4)),
            ),
          );
        case 4:
          screen = RetellScreen(
            controller: controller,
            engine: graph.engine,
            audio: graph.audioSource,
            permission: graph.micPermission,
            player: graph.audioPlayer,
            mediaResolver: graph.mediaResolver,
            defaultGloss: graph.defaultGloss,
            l10n: null,
            appSettings: graph.settings,
            onDone: () => nav.push(
              MaterialPageRoute<void>(builder: (_) => buildCompletion()),
            ),
            onPreviousStep: () => nav.pushReplacement(
              MaterialPageRoute<void>(builder: (_) => buildStepScreen(3)),
            ),
            onNextStep: null,
          );
        default:
          screen = buildCompletion();
      }
      return screen;
    }

    final ChapterStage stage = controller.state.stage;
    if (stage == ChapterStage.complete) return buildCompletion();
    if (stage == ChapterStage.retell) return buildStepScreen(4);
    if (stage == ChapterStage.quiz) return buildStepScreen(3);
    if (stage == ChapterStage.vocabulary) return buildStepScreen(2);
    return buildStepScreen(1);
  }
}

/// Plain `dart:io` HTTP fetch used as the network stage of media resolution.
Future<Uint8List?> httpFetch(String url) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.getUrl(Uri.parse(url));
    final HttpClientResponse response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final List<int> chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } on Exception catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
