/// Parsed `offline-media-map.json` (`contentctl pack` output).
///
/// The map lists, per media URL, the bundled relative path and the sha256
/// of the file so offline resolution can verify integrity
/// (`docs/07-modules.md` §2.3).
library;

/// One media entry of the offline map.
class OfflineMediaEntry {
  const OfflineMediaEntry({
    required this.url,
    this.path,
    required this.kind,
    this.bytes,
    this.sha256,
    this.remote = false,
  });

  final String url;

  /// Relative path inside the content directory (absent for remote entries).
  final String? path;

  /// `audio` or `image`.
  final String kind;
  final int? bytes;

  /// Hex sha256 of the bundled file (absent for remote entries).
  final String? sha256;

  /// True when the media is a remote `https://` asset without a local copy.
  final bool remote;
}

/// The whole offline media map, indexed by URL.
class OfflineMediaMap {
  OfflineMediaMap({
    required this.schemaVersion,
    required this.contentVersion,
    required this.entries,
    required this.missing,
  });

  /// Parses the `contentctl pack` format. Unknown shapes degrade to an empty
  /// map (missing media simply resolves through cache/network instead).
  factory OfflineMediaMap.fromJson(Map<String, dynamic> json) {
    final entries = <String, OfflineMediaEntry>{};
    final dynamic raw = json['entries'];
    if (raw is List) {
      for (final dynamic item in raw) {
        if (item is! Map<String, dynamic>) continue;
        final dynamic url = item['url'];
        if (url is! String || url.isEmpty) continue;
        entries[url] = OfflineMediaEntry(
          url: url,
          path: item['path'] is String ? item['path'] as String : null,
          kind: item['kind'] is String ? item['kind'] as String : 'audio',
          bytes: item['bytes'] is int ? item['bytes'] as int : null,
          sha256: item['sha256'] is String ? item['sha256'] as String : null,
          remote: item['remote'] == true,
        );
      }
    }
    final missing = <String>[];
    final dynamic rawMissing = json['missing'];
    if (rawMissing is List) {
      for (final dynamic m in rawMissing) {
        if (m is String) missing.add(m);
      }
    }
    return OfflineMediaMap(
      schemaVersion: json['schemaVersion'] is int ? json['schemaVersion'] as int : 0,
      contentVersion:
          json['contentVersion'] is String ? json['contentVersion'] as String : '',
      entries: entries,
      missing: missing,
    );
  }

  /// An empty map used when no map file exists.
  factory OfflineMediaMap.empty() => OfflineMediaMap(
        schemaVersion: 1,
        contentVersion: '',
        entries: const <String, OfflineMediaEntry>{},
        missing: const <String>[],
      );

  final int schemaVersion;
  final String contentVersion;
  final Map<String, OfflineMediaEntry> entries;
  final List<String> missing;
}
