/// Settings screen S7 (design-spec §4.8, `visual/app.css` L3289-3484).
///
/// Four blocks over the paper page: the offline card, the language group, the
/// learning group and the about group, closed by the brand footer. UI language
/// and gloss language stay independent (decision ③) and every control applies
/// immediately — there is no save step (docs/08 S7).
///
/// All colours come from [AppColors], all type from [AppTypography] and every
/// icon from the project icon set; the copy is looked up in the catalog, never
/// written here.
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../i18n/app_localizations.dart';
import '../library/book_download_service.dart';
import '../library/cached_pack_normalizer.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_settings.dart';
import 'book_update_action.dart';
import 'settings_chrome.dart';
import 'settings_info_sheet.dart';
import 'settings_locale_sheet.dart';
import 'settings_offline_card.dart';
import 'settings_rows.dart';
import 'settings_switch_row.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.glossLocales,
    this.attribution,
    this.l10n,
    this.onBookDownloaded,
  });

  final AppSettings settings;

  /// `locales.gloss` of the pack — the selectable gloss languages.
  final List<String> glossLocales;

  /// Content attribution of the active pack (shown as plain content data).
  final Attribution? attribution;

  /// Explicit catalog override (tests); production resolves via [L10nScope].
  final AppLocalizations? l10n;

  /// Called after a book is downloaded to trigger library refresh.
  final VoidCallback? onBookDownloaded;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = this.l10n ?? L10nScope.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? _) {
        // The preference only ever *adds* to the platform flag: switching it
        // off must not re-enable motion the system asked to suppress
        // (design-spec §4.8 — "开关同步顶部 rail 和系统偏好").
        final MediaQueryData media = MediaQuery.of(context);
        final bool reduce = settings.reduceMotion || media.disableAnimations;

        return MediaQuery(
          data: media.copyWith(disableAnimations: reduce),
          child: Scaffold(
            backgroundColor: AppColors.paper,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  SettingsAppBar(
                    title: l10n.t('settings.title'),
                    backLabel: l10n.t('nav.back'),
                  ),
                  Expanded(child: _body(context, l10n)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SettingsLayout.gutter,
        2,
        SettingsLayout.gutter,
        24,
      ),
      children: <Widget>[
        SettingsOfflineCard(
          key: const Key('settings-offline-card'),
          title: l10n.t('settings.offlineTitle'),
          body: l10n.t('settings.offlineBody'),
          badgeLabel: l10n.t('settings.offlineTag'),
        ),
        SettingsGroup(
          label: l10n.t('settings.groupBooks'),
          children: <Widget>[
            SettingsRow(
              key: const Key('settings-row-update-books'),
              label: l10n.t('settings.updateBooks'),
              sub: l10n.t('settings.updateBooksSub'),
              trailingIcon: 'chevron-right',
              onTap: () {
                _openBookUpdateSheet(context, l10n);
              },
            ),
          ],
        ),
        SettingsGroup(
          label: l10n.t('settings.groupLanguage'),
          children: <Widget>[
            SettingsRow(
              key: const Key('settings-row-ui-locale'),
              label: l10n.t('settings.uiLocale'),
              sub: l10n.t('settings.uiLocaleSub'),
              value: localeName(l10n, settings.uiLocale),
              trailingIcon: 'chevron-down',
              onTap: () {
                _openLocaleSheet(context, l10n, gloss: false);
              },
            ),
            SettingsRow(
              key: const Key('settings-row-gloss-locale'),
              label: l10n.t('settings.glossLocale'),
              sub: l10n.t('settings.glossLocaleSub'),
              value: localeName(l10n, settings.glossLocale),
              trailingIcon: 'chevron-down',
              onTap: () {
                _openLocaleSheet(context, l10n, gloss: true);
              },
            ),
          ],
        ),
        SettingsGroup(
          label: l10n.t('settings.groupLearning'),
          children: <Widget>[
            SettingsSwitchRow(
              label: l10n.t('settings.reduceMotion'),
              sub: l10n.t('settings.reduceMotionSub'),
              value: settings.reduceMotion,
              switchKey: const Key('settings-reduce-motion'),
              onChanged: (bool value) {
                settings.setReduceMotion(value);
              },
            ),
          ],
        ),
        SettingsGroup(
          label: l10n.t('settings.about'),
          children: <Widget>[
            SettingsRow(
              key: const Key('settings-row-version'),
              label: l10n.t('app.name'),
              sub: l10n.t(
                'settings.version',
                args: <String, Object>{'version': settings.appVersion},
              ),
              value: l10n.t('settings.offlineEdition'),
            ),
            SettingsRow(
              key: const Key('settings-row-license'),
              label: l10n.t('settings.license'),
              sub: l10n.t('settings.licenseSub'),
              trailingIcon: 'chevron-right',
              trailingIconSize: SettingsLayout.detailChevron,
              onTap: () {
                _openInfoSheet(context, l10n, privacy: false);
              },
            ),
            SettingsRow(
              key: const Key('settings-row-privacy'),
              label: l10n.t('settings.privacy'),
              sub: l10n.t('settings.privacySub'),
              trailingIcon: 'chevron-right',
              trailingIconSize: SettingsLayout.detailChevron,
              onTap: () {
                _openInfoSheet(context, l10n, privacy: true);
              },
            ),
          ],
        ),
        SettingsFooter(
          tagline: l10n.t('settings.tagline'),
          copyright: l10n.t(
            'settings.copyright',
            args: <String, Object>{'edition': l10n.t('settings.offlineEdition')},
          ),
        ),
      ],
    );
  }

  /// Book update: fetch book list from server, download selected books
  /// Resolve domain to IP via public DNS (fallback for phones with broken DNS)
  Future<String?> _resolveDomain(String domain) async {
    // Try system DNS first
    try {
      final result = await InternetAddress.lookup(domain);
      return result.isNotEmpty ? result.first.address : null;
    } catch (_) {}
    // Fallback: query AliDNS DoH (uses IP, no DNS needed)
    try {
      final resp = await http.get(
        Uri.parse('https://223.5.5.5/resolve?name=$domain&type=A'),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final answers = data['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          return answers.first['data'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openBookUpdateSheet(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, dynamic>> books = [];
    String? error;

    try {
      // 自定义 DNS 解析：手机 DNS 解析失败时手动解析到 IP，再走 HTTPS
      final client = http.Client();
      final uri = Uri.parse('https://story.ymie.fun/api/updates');
      final resp = await client.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        books = (data['books'] as List).cast<Map<String, dynamic>>();
      } else {
        error = 'HTTP ${resp.statusCode}';
      }
    } on SocketException catch (e) {
      // DNS 解析失败 → 手动解析 IP 后用 Host 头走 HTTPS
      if (e.message.contains('lookup') || e.osError?.errorCode == 7 || e.message.contains('address')) {
        try {
          final ip = await _resolveDomain('story.ymie.fun');
          if (ip != null) {
            final resp = await http.get(
              Uri.parse('https://story.ymie.fun/api/updates'),
              headers: {'Host': 'story.ymie.fun'},
            ).timeout(const Duration(seconds: 15));
            if (resp.statusCode == 200) {
              final data = jsonDecode(resp.body) as Map<String, dynamic>;
              books = (data['books'] as List).cast<Map<String, dynamic>>();
            } else {
              error = 'HTTP ${resp.statusCode}';
            }
          } else {
            error = 'DNS 解析失败，无法连接服务器';
          }
        } catch (e2) {
          error = 'DNS 解析失败: $e2';
        }
      } else {
        error = e.toString();
      }
    } catch (e) {
      error = e.toString();
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: $error')),
      );
      return;
    }

    // Pre-compute cached status
    final Map<String, bool> cachedMap = {};
    for (final b in books) {
      cachedMap[b['id']] = await _isBookCached(b['id']);
    }
    // bookId -> 0..1 while a download runs; absent otherwise.
    final Map<String, double> progressMap = {};
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (sheetContext, scrollCtrl) => Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.lineStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.t('settings.updateBooks'),
                      style: AppTypography.title,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('settings.booksAvailable', args: <String, Object>{
                        'count': books.length,
                      }),
                      style: AppTypography.meta,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Book list
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: books.length,
                  itemBuilder: (_, i) {
                    final b = books[i];
                    final bool cached = cachedMap[b['id']] ?? false;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          // Book info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b['title'] ?? b['id'],
                                  style: AppTypography.body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        b['level'] ?? 'A2',
                                        style: AppTypography.meta.copyWith(color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${b['size_mb'] ?? 0} MB',
                                      style: AppTypography.meta,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // One button for three states: idle, downloading
                          // (percentage), and cached (re-download).
                          BookUpdateAction(
                            cached: cached,
                            progress: progressMap[b['id']],
                            downloadLabel: l10n.t('settings.download'),
                            redownloadLabel: l10n.t('settings.redownload'),
                            progressLabel: (int percent) => l10n.t(
                              'settings.downloading',
                              args: <String, Object>{'percent': percent},
                            ),
                            onTap: () async {
                              final String id = b['id'] as String;
                              setState(() => progressMap[id] = 0);
                              // `_downloadBook` reports progress as bytes land,
                              // so the pill ticks instead of freezing.
                              final bool ok = await _downloadBook(
                                id,
                                onProgress: (double value) {
                                  if (!sheetContext.mounted) return;
                                  setState(() => progressMap[id] = value);
                                },
                              );
                              if (!sheetContext.mounted) return;
                              setState(() => progressMap.remove(id));
                              if (ok) {
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.t(
                                      'settings.downloaded',
                                      args: <String, Object>{
                                        'title': b['title'] ?? id,
                                      },
                                    )),
                                  ),
                                );
                                onBookDownloaded?.call();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.t('settings.downloadFailed')),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check whether a usable copy of the book is already cached.
  ///
  /// A cache written by an older build may hold a pack the parser rejects
  /// (missing envelope fields, scalar `locales`, no `level` statistics).
  /// Those are treated as absent so the row offers "下载" again instead of
  /// locking the learner out of a broken copy.
  Future<bool> _isBookCached(String bookId) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/storyapp_cache/$bookId');
    final pack = File('${dir.path}/pack.json');
    if (!dir.existsSync() || !pack.existsSync()) return false;
    try {
      final data = jsonDecode(pack.readAsStringSync()) as Map<String, dynamic>;
      if (!isPackShaped(normalizeCachedPack(data))) return false;
      // A cache written before the media URLs were repaired points at files
      // that do not exist, so the cover would render as a placeholder. Treat
      // that as "not cached" and let the learner re-fetch a correct copy.
      final books = data['books'] as List;
      final first = books.first as Map;
      final cover = first['cover'] as Map?;
      final url = cover?['url'] as String?;
      if (url == null || url.isEmpty) return false;
      // Media sit in the resolver's flat cache, named after their URL.
      final cached = File(
        '${support.path}${Platform.pathSeparator}${mediaCacheFileName(url)}',
      );
      return cached.existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Download a book package, reporting progress as bytes arrive.
  ///
  /// Thin wrapper over [downloadBookPackage] that keeps the cache location and
  /// the post-download repair in one place: the served pack is normalised so a
  /// legacy-shaped body still satisfies the parser.
  Future<bool> _downloadBook(
    String bookId, {
    void Function(double progress)? onProgress,
  }) async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory cacheDir =
        Directory('${support.path}/storyapp_cache/$bookId');

    final BookDownloadResult result = await downloadBookPackage(
      bookId: bookId,
      targetDir: cacheDir,
      // Same directory the media resolver reads from.
      mediaCacheDir: support,
      baseUrl: 'https://story.ymie.fun/api/books/$bookId',
      onProgress: onProgress,
    );
    if (!result.isUsable) return false;

    final File packFile = File('${cacheDir.path}/pack.json');
    if (!packFile.existsSync()) return false;
    try {
      final Map<String, dynamic> raw =
          jsonDecode(packFile.readAsStringSync()) as Map<String, dynamic>;
      final Map<String, dynamic> repaired = normalizeCachedPack(raw);
      if (jsonEncode(repaired) != jsonEncode(raw)) {
        packFile.writeAsStringSync(jsonEncode(repaired));
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Language picker: the pack's gloss list for the definitions row, the
  /// catalog list for the interface row. Selection applies on tap.
  Future<void> _openLocaleSheet(
    BuildContext context,
    AppLocalizations l10n, {
    required bool gloss,
  }) async {
    final List<String> declared = gloss ? glossLocales : uiLocaleOptions;
    // A pack that declares no gloss language still needs a usable picker.
    final List<String> tags = declared.isEmpty ? uiLocaleOptions : declared;
    final String selected = gloss ? settings.glossLocale : settings.uiLocale;

    final String? picked = await showLocaleSheet(
      context,
      title: l10n.t(gloss ? 'settings.glossLocale' : 'settings.uiLocale'),
      body: l10n.t(
        gloss ? 'settings.glossLocaleSheetBody' : 'settings.uiLocaleSheetBody',
      ),
      caption: l10n.t(
        gloss
            ? 'settings.glossLocaleSheetCaption'
            : 'settings.uiLocaleSheetCaption',
      ),
      selectedTag: selected,
      options: <LocaleChoice>[
        for (final String tag in tags)
          LocaleChoice(
            tag: tag,
            label: localeName(l10n, tag),
            sub: localeSubLine(l10n, tag, gloss: gloss),
          ),
      ],
    );

    if (picked == null || picked == selected) return;
    if (gloss) {
      await settings.setGlossLocale(picked);
    } else {
      await settings.setUiLocale(picked);
    }
  }

  /// Licence / privacy sheet. Attribution travels with the licence sheet as
  /// content data (never translated, docs/03 §1).
  Future<void> _openInfoSheet(
    BuildContext context,
    AppLocalizations l10n, {
    required bool privacy,
  }) async {
    final Attribution? a = attribution;
    await showInfoSheet(
      context,
      title: l10n.t(privacy ? 'settings.privacy' : 'settings.license'),
      body: l10n.t(
        privacy ? 'settings.privacySheetBody' : 'settings.licenseSheetBody',
      ),
      caption: l10n.t(
        privacy
            ? 'settings.privacySheetCaption'
            : 'settings.licenseSheetCaption',
      ),
      attributionLabel:
          privacy || a == null ? null : l10n.t('settings.attribution'),
      attributionLine: privacy || a == null
          ? null
          : '${a.author} · ${a.generator} · ${a.license}',
      closeLabel: l10n.t('settings.close'),
    );
  }
}
