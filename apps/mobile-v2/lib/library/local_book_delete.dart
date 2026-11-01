/// Removes a downloaded book's local footprint.
///
/// A cached book owns three things on the device:
///
///  * `storyapp_cache/<bookId>/` — the cached `pack.json` and its siblings;
///  * the flat media-cache files the resolver keeps for its URLs
///    (`<supportDir>/<mediaCacheFileName(url)>` — the same deterministic names
///    [DefaultMediaResolver] and the downloader share, see `media_resolver.dart`);
///  * the learner's progress entries for that book inside the shared progress
///    document (keys `<bookId>/<chapterId>`, decision ①).
///
/// All three are enumerated from the raw cached `pack.json` before the pack
/// directory goes away, so a delete never relies on the parsed model keeping
/// every URL. Files that are already gone simply do not count.
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';

/// What one delete pass removed — surfaced for tests and diagnostics.
class LocalBookDeleteResult {
  const LocalBookDeleteResult({
    this.mediaFiles = 0,
    this.cacheRemoved = false,
    this.progressEntries = 0,
  });

  /// Flat media-cache files deleted (named by the pack's URLs).
  final int mediaFiles;

  /// True when `storyapp_cache/<bookId>/` existed and was removed.
  final bool cacheRemoved;

  /// Progress entries (`<bookId>/…`) dropped from the shared progress document.
  final int progressEntries;

  /// True when anything at all was deleted.
  bool get removedAnything =>
      mediaFiles > 0 || cacheRemoved || progressEntries > 0;
}

/// Deletes the cached copy of [bookId] from under [supportDir].
///
/// [progressStore] / [progressPackId] are optional: when given, the book's
/// chapter and skill entries are dropped from that progress document (the
/// app keeps one document per pack, named after its first book — so the file
/// itself must survive, only this book's rows go).
Future<LocalBookDeleteResult> deleteLocalBook({
  required String bookId,
  required Directory supportDir,
  ProgressStore? progressStore,
  String? progressPackId,
}) async {
  final Directory bookDir =
      Directory('${supportDir.path}${Platform.pathSeparator}storyapp_cache'
          '${Platform.pathSeparator}$bookId');

  // Collect every media URL BEFORE the pack directory goes away.
  final Set<String> urls = <String>{};
  final File packFile = File('${bookDir.path}${Platform.pathSeparator}pack.json');
  if (packFile.existsSync()) {
    try {
      final dynamic raw = jsonDecode(packFile.readAsStringSync());
      _collectUrls(raw, urls);
    } on Exception {
      // Unreadable pack: the cache directory is still deleted below; only the
      // indirection through its URLs is lost (they cannot be enumerated).
    }
  }

  int mediaFiles = 0;
  for (final String url in urls) {
    final File file = File(
      '${supportDir.path}${Platform.pathSeparator}${mediaCacheFileName(url)}',
    );
    if (file.existsSync()) {
      try {
        file.deleteSync();
        mediaFiles++;
      } on Exception {
        // A locked file must not abort the rest of the delete.
      }
    }
  }

  bool cacheRemoved = false;
  if (bookDir.existsSync()) {
    try {
      bookDir.deleteSync(recursive: true);
      cacheRemoved = true;
    } on Exception {
      // Leave whatever could not be removed; the result reports the miss.
    }
  }

  int progressEntries = 0;
  if (progressStore != null && progressPackId != null) {
    progressEntries = await _dropProgressEntries(
      progressStore,
      progressPackId,
      bookId,
    );
  }

  return LocalBookDeleteResult(
    mediaFiles: mediaFiles,
    cacheRemoved: cacheRemoved,
    progressEntries: progressEntries,
  );
}

/// Every string held by an `url` / `src` key anywhere in the decoded pack.
void _collectUrls(dynamic node, Set<String> out) {
  if (node is Map) {
    node.forEach((dynamic key, dynamic value) {
      if ((key == 'url' || key == 'src') && value is String && value.isNotEmpty) {
        out.add(value);
      } else {
        _collectUrls(value, out);
      }
    });
  } else if (node is List) {
    for (final dynamic item in node) {
      _collectUrls(item, out);
    }
  }
}

/// Removes every `<bookId>/…` row from the shared progress document.
///
/// The document is loaded and re-saved through the store, so its own file
/// naming and encoding stay the store's business. Returns how many rows went.
Future<int> _dropProgressEntries(
  ProgressStore store,
  String packId,
  String bookId,
) async {
  final ProgressDoc doc = await store.load(packId);
  final String prefix = '$bookId/';
  int dropped = 0;

  final List<String> chapterKeys = doc.chapters.keys
      .where((String k) => k.startsWith(prefix))
      .toList();
  for (final String key in chapterKeys) {
    doc.chapters.remove(key);
    dropped++;
  }

  final List<String> skillKeys =
      doc.skills.keys.where((String k) => k.startsWith(prefix)).toList();
  for (final String key in skillKeys) {
    doc.skills.remove(key);
    dropped++;
  }

  if (dropped > 0) {
    await store.save(doc);
  }
  return dropped;
}
