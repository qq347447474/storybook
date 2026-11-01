/// Action pill of one "更新书本" row.
///
/// Three states share one tap handler:
///
///  * not on the device — a filled "download" call to action;
///  * downloading — a progress pill reading "45%", so a fifty-file fetch does
///    not look frozen;
///  * already cached — an outlined "download again". Keeping that state tappable
///    matters: a copy the parser rejects can otherwise strand the learner with
///    a row that claims the book is present but never opens.
///
/// Every string arrives already localised — this widget owns geometry, not copy.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class BookUpdateAction extends StatelessWidget {
  const BookUpdateAction({
    super.key,
    required this.cached,
    required this.onTap,
    required this.downloadLabel,
    required this.redownloadLabel,
    required this.progressLabel,
    this.progress,
  });

  /// True when a usable copy already lives on the device.
  final bool cached;

  /// Non-null while a download runs; `0.0 … 1.0`.
  final double? progress;

  final VoidCallback onTap;

  /// Idle label when nothing is cached.
  final String downloadLabel;

  /// Idle label when a copy is already cached.
  final String redownloadLabel;

  /// Builds the in-flight label from a whole percentage.
  final String Function(int percent) progressLabel;

  static const EdgeInsets _padding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 10);
  static const double _minWidth = 84;

  @override
  Widget build(BuildContext context) {
    final double? fraction = progress;
    final bool busy = fraction != null;
    final bool filled = !cached;

    final Color background = busy
        ? AppColors.primarySoft
        : (filled ? AppColors.primary : AppColors.primarySoft);
    final Color foreground = busy
        ? AppColors.primaryStrong
        : (filled ? AppColors.onPrimary : AppColors.primary);

    final int percent = ((fraction ?? 0) * 100).round().clamp(0, 100);
    final String label = busy
        ? progressLabel(percent)
        : (filled ? downloadLabel : redownloadLabel);

    return Semantics(
      button: !busy,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Taps are ignored mid-download: a second run would race the first.
          onTap: busy ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: _minWidth),
            padding: _padding,
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.meta.copyWith(
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
