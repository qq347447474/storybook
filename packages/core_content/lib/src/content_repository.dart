/// [ContentRepository] and its file/asset backed implementation
/// (`docs/07-modules.md` §2.2).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'pack_error.dart';
import 'pack_parser.dart';

/// Reads a bundled asset as bytes. Injected at construction so that
/// core_content stays pure Dart; `apps/mobile` wires `rootBundle.load` at
/// registration time. Unit tests pass a fake.
typedef AssetReader = Future<Uint8List> Function(String key);

/// Loads and validates a content pack.
///
/// Implementations must never throw parse or validation failures at the
/// caller (C5); they return [PackInvalid] instead.
abstract class ContentRepository {
  /// Loads a pack from a file system path.
  Future<PackLoadResult> loadFromFile(String path);

  /// Loads a pack from a bundled asset identified by [assetKey].
  Future<PackLoadResult> loadFromAsset(String assetKey);
}

/// Default [ContentRepository]: reads bytes from file/asset, then runs the
/// pure-Dart parse + validation pipeline.
class JsonContentRepository implements ContentRepository {
  JsonContentRepository({
    required this.appVersion,
    required this.readAsset,
  });

  /// Semver of the running app; compared against `pack.minAppVersion` to set
  /// [PackOk.upgradeRecommended].
  final String appVersion;

  /// Asset byte reader used by [loadFromAsset].
  final AssetReader readAsset;

  @override
  Future<PackLoadResult> loadFromFile(String path) async {
    Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } on Exception catch (e) {
      return PackInvalid(<PackError>[
        PackError(
          code: 'SCHEMA-NOT-FOUND',
          pointer: path,
          message: 'Pack file cannot be read: $e',
        ),
      ]);
    }
    return _loadBytes(bytes);
  }

  @override
  Future<PackLoadResult> loadFromAsset(String assetKey) async {
    Uint8List bytes;
    try {
      bytes = await readAsset(assetKey);
    } on Exception catch (e) {
      return PackInvalid(<PackError>[
        PackError(
          code: 'SCHEMA-NOT-FOUND',
          pointer: assetKey,
          message: 'Asset cannot be read: $e',
        ),
      ]);
    }
    return _loadBytes(bytes);
  }

  /// Parse pack JSON that the caller has already read.
  ///
  /// The cache-refresh path reads `pack.json` synchronously (to normalise and
  /// write it back); re-opening the file through [loadFromFile] would be a
  /// second I/O whose future never completes under a test's fake clock. This
  /// entry point keeps that path fully synchronous.
  PackLoadResult loadFromJsonText(String text) => parsePack(text, appVersion: appVersion);

  PackLoadResult _loadBytes(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } on Exception catch (e) {
      return PackInvalid(<PackError>[
        PackError(
          code: 'SCHEMA-BROKEN',
          pointer: '<root>',
          message: 'Pack bytes are not valid UTF-8 text: $e',
        ),
      ]);
    }
    return parsePack(text, appVersion: appVersion);
  }
}
