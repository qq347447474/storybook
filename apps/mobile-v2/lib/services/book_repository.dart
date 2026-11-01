/// Book repository — fetches books from backend API and caches locally.
///
/// Supports:
/// - Fetching book list from server
/// - Downloading book packages (pack.json + media)
/// - Local caching for offline use
/// - Checking for updates
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class BookSummary {
  final String id;
  final String title;
  final String level;
  final int chapters;
  final double sizeMb;
  final String uploadedAt;
  final String version;

  BookSummary({
    required this.id,
    required this.title,
    required this.level,
    required this.chapters,
    required this.sizeMb,
    required this.uploadedAt,
    required this.version,
  });

  factory BookSummary.fromJson(Map<String, dynamic> json) => BookSummary(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        level: json['level'] ?? 'A2',
        chapters: json['chapters'] ?? 0,
        sizeMb: (json['size_mb'] ?? 0).toDouble(),
        uploadedAt: json['uploaded_at'] ?? '',
        version: json['version'] ?? '1.0.0',
      );
}

class BookRepository {
  final String baseUrl;
  late final Directory _cacheDir;

  BookRepository({required this.baseUrl});

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/book_cache');
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
  }

  Directory get cacheDir => _cacheDir;

  /// Fetch book list from server
  Future<List<BookSummary>> fetchBookList() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/books'));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load books: ${resp.statusCode}');
    }
    final List<dynamic> data = jsonDecode(resp.body);
    return data.map((e) => BookSummary.fromJson(e)).toList();
  }

  /// Check for updates
  Future<List<BookSummary>> checkUpdates() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/updates'));
    if (resp.statusCode != 200) {
      throw Exception('Failed to check updates: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body);
    final List<dynamic> books = data['books'] ?? [];
    return books.map((e) => BookSummary.fromJson(e)).toList();
  }

  /// Download a book package (pack.json + media)
  Future<String> downloadBook(String bookId, {void Function(double)? onProgress}) async {
    final bookDir = Directory('${_cacheDir.path}/$bookId');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }

    // Download pack.json
    final packResp = await http.get(Uri.parse('$baseUrl/api/books/$bookId/file/pack.json'));
    if (packResp.statusCode == 200) {
      await File('${bookDir.path}/pack.json').writeAsBytes(packResp.bodyBytes);
    }

    // Get file list from book detail
    final detailResp = await http.get(Uri.parse('$baseUrl/api/books/$bookId'));
    if (detailResp.statusCode == 200) {
      final detail = jsonDecode(detailResp.body);
      final List<dynamic> files = detail['files'] ?? [];

      for (int i = 0; i < files.length; i++) {
        final fname = files[i] as String;
        if (fname == 'pack.json') continue;

        final fileResp = await http.get(
          Uri.parse('$baseUrl/api/books/$bookId/file/${Uri.encodeComponent(fname)}'),
        );
        if (fileResp.statusCode == 200) {
          final parts = fname.split('/');
          String filePath;
          if (parts.length > 1) {
            // Has subdirectory (e.g., media/xxx.mp3)
            final subDir = Directory('${bookDir.path}/${parts[0]}');
            if (!await subDir.exists()) await subDir.create(recursive: true);
            filePath = '${bookDir.path}/$fname';
          } else {
            filePath = '${bookDir.path}/$fname';
          }
          await File(filePath).writeAsBytes(fileResp.bodyBytes);
        }

        onProgress?.call((i + 1) / files.length);
      }
    }

    return bookDir.path;
  }

  /// Get cached book pack.json path
  String? getCachedPackPath(String bookId) {
    final packFile = File('${_cacheDir.path}/$bookId/pack.json');
    return packFile.existsSync() ? packFile.path : null;
  }

  /// Get cached book media path
  String getCachedMediaDir(String bookId) {
    return '${_cacheDir.path}/$bookId/media';
  }

  /// Check if a book is cached
  bool isBookCached(String bookId) {
    return File('${_cacheDir.path}/$bookId/pack.json').existsSync();
  }

  /// Delete cached book
  Future<void> deleteCachedBook(String bookId) async {
    final bookDir = Directory('${_cacheDir.path}/$bookId');
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  }

  /// Get all cached book IDs
  List<String> getCachedBookIds() {
    if (!_cacheDir.existsSync()) return [];
    return _cacheDir
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .toList();
  }
}
