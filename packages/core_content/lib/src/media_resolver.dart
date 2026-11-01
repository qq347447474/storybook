/// Media resolution with bundled -> cache -> network fallback
/// (`docs/07-modules.md` §2.3). Never throws at the caller: `null` means
/// "temporarily unavailable" (C6) — the UI shows a placeholder and a retry.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'offline_media_map.dart';

/// Where a resolved media file lives.
enum MediaOrigin {
  /// Verified file shipped inside the offline media map / content directory.
  bundled,

  /// Previously downloaded copy in the app cache directory.
  cached,

  /// Live remote `https://` location (also saved to cache for next time).
  remote,
}

/// A successfully resolved media location.
class ResolvedMedia {
  const ResolvedMedia({
    required this.origin,
    required this.location,
    this.assetKey,
    this.sha256,
  });

  final MediaOrigin origin;

  /// File path for [MediaOrigin.bundled]/[MediaOrigin.cached], URL for
  /// [MediaOrigin.remote]. For bundled entries this is the content-relative
  /// path from the offline map (kept for compatibility); consumers that
  /// actually load the media should use [assetKey].
  final String location;

  /// Full bundle asset key for [MediaOrigin.bundled] (e.g.
  /// `assets/content/<book>/media/cover.png`) — the exact key [BundledReader]
  /// loaded. Consumable by `Image.asset` / `AudioSource.asset`. Null for
  /// cached/remote origins.
  final String? assetKey;

  /// Hex sha256 when known (bundled entries).
  final String? sha256;
}

/// Resolves a media URL to something the player/renderer can load.
abstract class MediaResolver {
  /// Returns `null` when the media is temporarily unavailable; the caller
  /// must show a placeholder and allow a retry (never crash, C6).
  Future<ResolvedMedia?> resolve(String url);
}

/// Byte reader for bundled content files. `assetKey` is the FULL bundle
/// key (prefix + content-relative path) — the resolver joins
/// [DefaultMediaResolver.bundledAssetPrefix] with the map path in one place
/// and passes the same key to the reader and to [ResolvedMedia.assetKey].
/// Injected so the resolver stays free of Flutter dependencies;
/// `apps/mobile` wires `rootBundle`.
typedef BundledReader = Future<Uint8List?> Function(String assetKey);

/// Remote byte fetcher; returns `null` (or throws) when the network is
/// unavailable. Injected for testability and platform independence (C8).
typedef RemoteFetcher = Future<Uint8List?> Function(String url);

/// Default [MediaResolver]: bundled map (sha256-verified) -> cache dir ->
/// remote fetch. All three stages are injected, so platform specifics stay
/// in the `apps/mobile` registration code (C8).
class DefaultMediaResolver implements MediaResolver {
  DefaultMediaResolver({
    required this.offlineEntries,
    required this.readBundled,
    required this.cacheDir,
    required this.fetchRemote,
    this.bundledAssetPrefix = '',
    this.onLog,
  });

  /// `offline-media-map.json` entries indexed by URL.
  final Map<String, OfflineMediaEntry> offlineEntries;

  /// Reads a bundled content file as bytes (full asset key).
  final BundledReader readBundled;

  /// Absolute path of the app cache directory.
  final String cacheDir;

  /// Downloads remote bytes for a URL.
  final RemoteFetcher fetchRemote;

  /// Bundle prefix prepended to the map's content-relative `path` to form
  /// the full asset key (e.g. `assets/content/the-paper-boat/`). Empty in
  /// pure-Dart tests. Joined in exactly one place — see [BundledReader].
  final String bundledAssetPrefix;

  /// Called once per integrity failure (e.g. sha256 mismatch).
  final void Function(String message)? onLog;

  @override
  Future<ResolvedMedia?> resolve(String url) async {
    // 1. Bundled entry from the offline media map, verified by sha256.
    final OfflineMediaEntry? entry = offlineEntries[url];
    if (entry != null && entry.path != null && entry.sha256 != null) {
      final String assetKey = bundledAssetPrefix + entry.path!;
      Uint8List? bytes;
      try {
        bytes = await readBundled(assetKey);
      } on Exception catch (e) {
        onLog?.call('bundled read failed for $assetKey: $e');
        bytes = null;
      }
      if (bytes != null) {
        final String digest = sha256.convert(bytes).toString();
        if (digest == entry.sha256) {
          return ResolvedMedia(
            origin: MediaOrigin.bundled,
            location: entry.path!,
            assetKey: assetKey,
            sha256: entry.sha256,
          );
        }
        // Integrity failure counts as a miss, logged once (docs/07 §2.3).
        onLog?.call('sha256 mismatch for $url: expected ${entry.sha256}, got $digest');
      }
    }

    // 2. Previously cached copy.
    final File cached = File(_cachePath(url));
    if (cached.existsSync()) {
      return ResolvedMedia(origin: MediaOrigin.cached, location: cached.path);
    }

    // 3. Network fallback; cache the result for the next offline run.
    Uint8List? remoteBytes;
    try {
      remoteBytes = await fetchRemote(url);
    } on Exception catch (e) {
      onLog?.call('remote fetch failed for $url: $e');
      remoteBytes = null;
    }
    if (remoteBytes == null) return null;
    try {
      final File target = File(_cachePath(url));
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(remoteBytes, flush: true);
    } on Exception catch (e) {
      // Caching is best effort; the caller can still play the remote URL.
      onLog?.call('cache write failed for $url: $e');
    }
    return ResolvedMedia(origin: MediaOrigin.remote, location: url);
  }

  /// Deterministic flat cache file name for any URL.
  String _cachePath(String url) =>
      '$cacheDir${Platform.pathSeparator}${mediaCacheFileName(url)}';
}

/// Flat file name a URL is cached under, inside the resolver's cache directory.
///
/// Exported so an ahead-of-time downloader can write media where [resolve]
/// will look for it; a second copy of this rule would silently drift and turn
/// "downloaded for offline" into "re-fetched on first view".
String mediaCacheFileName(String url) =>
    url.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
