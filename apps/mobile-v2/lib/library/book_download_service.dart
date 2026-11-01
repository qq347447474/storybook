/// Fetches one book package into the app's private cache.
///
/// The book server splits a title into a `pack.json` plus ~50 media files, so
/// a naive loop issues 50 sequential HTTPS requests and the learner stares at
/// a frozen button. This service streams each file (so a percentage is
/// meaningful), runs a small worker pool, and reuses one client for keep-alive.
///
/// Progress is reported as completed work units over total work units, where a
/// unit is one file: the pack counts as one, each media file as one. That keeps
/// the bar honest even though file sizes differ by two orders of magnitude.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:http/http.dart' as http;

/// Outcome of one book download.
enum BookDownloadStatus {
  /// Every file landed and the pack was normalised.
  ok,

  /// The server answered, but one or more media files could not be fetched.
  partial,

  /// `pack.json` itself failed — nothing usable was written.
  failed,
}

class BookDownloadResult {
  const BookDownloadResult(this.status, {this.failedFiles = 0});

  final BookDownloadStatus status;
  final int failedFiles;

  bool get isUsable => status != BookDownloadStatus.failed;
}

/// Download [bookId] from [baseUrl] into [targetDir].
///
/// [onProgress] receives 0.0 … 1.0. [concurrency] caps parallel requests so a
/// phone radio is not asked to open fifty sockets at once.
Future<BookDownloadResult> downloadBookPackage({
  required String bookId,
  required Directory targetDir,
  required Directory mediaCacheDir,
  required String baseUrl,
  void Function(double progress)? onProgress,
  int concurrency = 4,
}) async {
  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
  }
  // Media land where [DefaultMediaResolver] looks them up — a flat file per
  // URL. Writing them into a per-book folder instead would leave the resolver
  // blind to them and the "offline" copy would be re-fetched on first view.
  if (!mediaCacheDir.existsSync()) {
    mediaCacheDir.createSync(recursive: true);
  }

  final http.Client client = http.Client();
  try {
    // ---- Unit 1: the pack itself -------------------------------------
    final Uri packUri = Uri.parse('$baseUrl/file/pack.json');
    final String? packBody = await _getString(client, packUri);
    if (packBody == null) {
      return const BookDownloadResult(BookDownloadStatus.failed);
    }
    File('${targetDir.path}/pack.json').writeAsStringSync(packBody);

    // ---- Units 2..N: the media manifest ------------------------------
    final List<_FileRef> files = await _manifest(client, baseUrl);
    final int totalUnits = 1 + files.length;
    int completedUnits = 1;
    final List<double> partial = List<double>.filled(files.length, 0);

    void report() {
      if (onProgress == null) return;
      double done = completedUnits.toDouble();
      for (final double value in partial) {
        done += value;
      }
      onProgress((done / totalUnits).clamp(0.0, 1.0));
    }

    report();

    int cursor = 0;
    int failed = 0;
    Future<void> worker() async {
      while (true) {
        final int index;
        // Claim the next free slot; the counter is shared by all workers.
        if (cursor >= files.length) return;
        index = cursor;
        cursor++;

        final _FileRef ref = files[index];
        final bool ok = await _streamToFile(
          client,
          ref.url,
          File('${mediaCacheDir.path}/${mediaCacheFileName(ref.url)}'),
          (double fraction) {
            partial[index] = fraction;
            report();
          },
        );
        if (!ok) failed++;
        partial[index] = 1;
        completedUnits++;
        report();
      }
    }

    final int workers = files.isEmpty
        ? 1
        : (concurrency < files.length ? concurrency : files.length);
    await Future.wait(List<Future<void>>.generate(workers, (_) => worker()));

    onProgress?.call(1);
    if (failed > 0) {
      return BookDownloadResult(BookDownloadStatus.partial, failedFiles: failed);
    }
    return const BookDownloadResult(BookDownloadStatus.ok);
  } finally {
    client.close();
  }
}

class _FileRef {
  const _FileRef(this.name, this.url);

  final String name;
  final String url;
}

/// Read `/files`, mapping every entry to an absolute URL.
Future<List<_FileRef>> _manifest(http.Client client, String baseUrl) async {
  final String? body = await _getString(client, Uri.parse('$baseUrl/files'));
  if (body == null) return const <_FileRef>[];
  try {
    final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
    final List<dynamic> raw = (data['files'] as List?) ?? const <dynamic>[];
    final List<_FileRef> out = <_FileRef>[];
    for (final dynamic entry in raw) {
      if (entry is! Map) continue;
      final Object? name = entry['name'];
      if (name is! String || name.isEmpty || name == 'pack.json') continue;
      final Object? url = entry['url'];
      // Relative entries are rooted at the API origin, e.g.
      // `/api/books/<id>/file/<name>` → `https://host/api/...`.
      final String origin = baseUrl.split('/api/').first;
      final String resolved = url is String && url.isNotEmpty
          ? (url.startsWith('http') ? url : origin + url)
          : '$baseUrl/file/$name';
      out.add(_FileRef(name, resolved));
    }
    return out;
  } catch (_) {
    return const <_FileRef>[];
  }
}

Future<String?> _getString(http.Client client, Uri uri) async {
  try {
    final http.Response response =
        await client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    // The pack is UTF-8; `body` would decode as latin-1 for a missing charset.
    return utf8.decode(response.bodyBytes);
  } catch (_) {
    return null;
  }
}

/// Stream [uri] into [file], reporting `0..1` as bytes arrive.
Future<bool> _streamToFile(
  http.Client client,
  String uri,
  File file,
  void Function(double fraction) onFraction,
) async {
  try {
    final http.Request request = http.Request('GET', Uri.parse(uri));
    final http.StreamedResponse response =
        await client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) return false;

    final int total = response.contentLength ?? 0;
    int received = 0;
    final IOSink sink = file.openWrite();
    try {
      await for (final List<int> chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onFraction((received / total).clamp(0.0, 1.0));
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    // An unknown length still needs a completion signal.
    if (total <= 0) onFraction(1);
    return true;
  } catch (_) {
    // A half-written file must not look like a finished one.
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
    return false;
  }
}
